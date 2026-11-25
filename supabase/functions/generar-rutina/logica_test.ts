// Pruebas de generar-rutina (ENT-57) con Gemini simulado. Correr con:
//   deno test supabase/functions/generar-rutina
import { assert, assertEquals, assertRejects, assertThrows } from 'jsr:@std/assert@1';
import {
  construirPrompt,
  type Entrada,
  ErrorRutina,
  errorDeGemini,
  extraerJson,
  generarRutina,
  MENSAJES,
  normalizarRutina,
  validarEntrada,
} from './logica.ts';

const entrada: Entrada = {
  perfil: { objetivo: 'hipertrofia', nivel_experiencia: 'intermedio', dias_por_semana: 3, notas_lesiones: null },
  medicion: { peso_kg: 74.6, estatura_cm: 175, porcentaje_grasa: null },
  equipo: [2, 5],
  catalogo: [
    { id_ejercicio: 1, nombre_oficial: 'Sentadilla con barra' },
    { id_ejercicio: 2, nombre_oficial: 'Prensa de piernas' },
    { id_ejercicio: 3, nombre_oficial: 'Press de banca' },
  ],
};
const validos = new Set([1, 2, 3]);

const respuesta = (ejercicios: unknown[], extra: Record<string, unknown> = {}) =>
  JSON.stringify({
    nombre_ciclo: 'Torso y pierna',
    dias: [
      { dia_semana: 1, nombre: 'Pierna', es_descanso: false, ejercicios },
      { dia_semana: 2, nombre: 'Descanso', es_descanso: true, ejercicios: [] },
    ],
    ...extra,
  });

Deno.test('validarEntrada acepta el perfil y rechaza datos incompletos', () => {
  assertEquals(validarEntrada(entrada).perfil.dias_por_semana, 3);
  for (const malo of [null, {}, { ...entrada, catalogo: [] }, { ...entrada, perfil: { ...entrada.perfil, dias_por_semana: 9 } }]) {
    const e = assertThrows(() => validarEntrada(malo), ErrorRutina);
    assertEquals(e.estado, 400);
  }
});

Deno.test('El prompt lleva el catálogo por id y nombre oficial, sin datos personales', () => {
  const p = construirPrompt(entrada);
  assert(p.includes('1: Sentadilla con barra'));
  assert(p.includes('Objetivo: hipertrofia'));
  assert(!p.includes('@')); // nada de correos
  assert(construirPrompt(entrada, [99]).includes('NO existen (99)'));
});

Deno.test('Siempre devuelve 7 días y rellena los que faltan como descanso', () => {
  const { rutina } = normalizarRutina(JSON.parse(respuesta([{ id_ejercicio: 1, series: 4, reps: 8, peso_kg: 60, descanso_seg: 120, alternativas: [2] }])), validos);
  assertEquals(rutina.dias.map((d) => d.dia_semana), [1, 2, 3, 4, 5, 6, 7]);
  assertEquals(rutina.dias[0].nombre, 'Pierna');
  assertEquals(rutina.dias[6].es_descanso, true);
  assertEquals(rutina.dias[0].ejercicios[0], { id_ejercicio: 1, series: 4, reps: 8, peso_kg: 60, descanso_seg: 120, alternativas: [2] });
});

Deno.test('Descarta ids inventados y alternativas repetidas o iguales al ejercicio', () => {
  const { rutina, idsInvalidos } = normalizarRutina(
    JSON.parse(respuesta([
      { id_ejercicio: 1, series: 4, reps: 8, peso_kg: null, descanso_seg: 90, alternativas: [1, 2, 2, 77, 3] },
      { id_ejercicio: 99, series: 3, reps: 10, peso_kg: null, descanso_seg: 90, alternativas: [] },
      { id_ejercicio: 1, series: 3, reps: 10, peso_kg: null, descanso_seg: 90, alternativas: [] },
    ])),
    validos,
  );
  assertEquals(rutina.dias[0].ejercicios.length, 1);
  assertEquals(rutina.dias[0].ejercicios[0].alternativas, [2, 3]);
  assertEquals(idsInvalidos.sort(), [77, 99]);
});

Deno.test('Pone los valores dentro de rango', () => {
  const { rutina } = normalizarRutina(
    JSON.parse(respuesta([{ id_ejercicio: 2, series: 0, reps: 500, peso_kg: -5, descanso_seg: 5000, alternativas: [] }])),
    validos,
  );
  assertEquals(rutina.dias[0].ejercicios[0], { id_ejercicio: 2, series: 1, reps: 100, peso_kg: null, descanso_seg: 900, alternativas: [] });
});

Deno.test('Lee el JSON aunque venga con ``` o texto de más', () => {
  assertEquals((extraerJson('```json\n{"a":1}\n```') as { a: number }).a, 1);
  assertEquals((extraerJson('Claro, aquí está: {"a":2} ¡Suerte!') as { a: number }).a, 2);
  assertThrows(() => extraerJson('no hay json'), ErrorRutina);
});

Deno.test('Si la IA inventa un id, reintenta una vez y avisa cuáles eran (criterio 2)', async () => {
  const prompts: string[] = [];
  const respuestas = [
    respuesta([{ id_ejercicio: 99, series: 3, reps: 10, peso_kg: null, descanso_seg: 90, alternativas: [] }, { id_ejercicio: 1, series: 3, reps: 10, peso_kg: null, descanso_seg: 90, alternativas: [] }]),
    respuesta([{ id_ejercicio: 3, series: 3, reps: 10, peso_kg: null, descanso_seg: 90, alternativas: [] }]),
  ];
  const r = await generarRutina(entrada, validos, (p) => {
    prompts.push(p);
    return Promise.resolve(respuestas[prompts.length - 1]);
  });
  assertEquals(r.intentos, 2);
  assert(prompts[1].includes('NO existen (99)'));
  assertEquals(r.descartados, []);
  assertEquals(r.rutina.dias[0].ejercicios[0].id_ejercicio, 3);
});

Deno.test('En el segundo intento descarta los ids inválidos en vez de fallar', async () => {
  const mala = respuesta([{ id_ejercicio: 99, series: 3, reps: 10, peso_kg: null, descanso_seg: 90, alternativas: [] }, { id_ejercicio: 2, series: 3, reps: 10, peso_kg: null, descanso_seg: 90, alternativas: [] }]);
  const r = await generarRutina(entrada, validos, () => Promise.resolve(mala));
  assertEquals(r.intentos, 2);
  assertEquals(r.descartados, [99]);
  assertEquals(r.rutina.dias[0].ejercicios.map((e) => e.id_ejercicio), [2]);
});

Deno.test('Si la respuesta no se puede leer dos veces, error claro', async () => {
  const e = await assertRejects(() => generarRutina(entrada, validos, () => Promise.resolve('nada')), ErrorRutina);
  assertEquals(e.message, MENSAJES.respuestaRara);
});

Deno.test('Cuota agotada no se reintenta y da mensaje en español (criterio 4)', async () => {
  let llamadas = 0;
  const e = await assertRejects(
    () => generarRutina(entrada, validos, () => { llamadas++; return Promise.reject(errorDeGemini(429)); }),
    ErrorRutina,
  );
  assertEquals(llamadas, 1);
  assertEquals(e.estado, 429);
  assertEquals(e.message, MENSAJES.cuota);
  assertEquals(errorDeGemini(503).message, MENSAJES.sinRespuesta);
  assertEquals(errorDeGemini(403).message, MENSAJES.noConfigurada);
});

Deno.test('Si la IA no propone ningún ejercicio válido, error claro', () => {
  const e = assertThrows(
    () => normalizarRutina(JSON.parse(respuesta([{ id_ejercicio: 99, series: 3, reps: 10, peso_kg: null, descanso_seg: 90, alternativas: [] }])), validos),
    ErrorRutina,
  );
  assertEquals(e.message, MENSAJES.sinEjercicios);
});
