// Lógica de generar-rutina (ENT-57): sin red ni base de datos, para probarla
// con `deno test`. index.ts la conecta con Supabase y Gemini.

/** Lo que manda la app. Nunca trae alias, nombre ni correo del usuario. */
export interface Entrada {
  perfil: {
    objetivo: string;
    nivel_experiencia: string;
    dias_por_semana: number;
    notas_lesiones?: string | null;
  };
  medicion?: { peso_kg: number; estatura_cm: number; porcentaje_grasa?: number | null } | null;
  /** id de los equipos que tiene el usuario. */
  equipo: number[];
  /** Catálogo filtrado: solo id y nombre oficial (decisión 5 de la bitácora). */
  catalogo: { id_ejercicio: number; nombre_oficial: string }[];
}

export interface EjercicioRutina {
  id_ejercicio: number;
  series: number;
  reps: number;
  peso_kg: number | null;
  descanso_seg: number;
  /** Hasta 3 id de ejercicios, en orden de prioridad (ENT-48). */
  alternativas: number[];
}

export interface DiaRutina {
  dia_semana: number; // 1 = lunes ... 7 = domingo
  nombre: string;
  es_descanso: boolean;
  ejercicios: EjercicioRutina[];
}

export interface Rutina {
  nombre_ciclo: string;
  dias: DiaRutina[];
}

/** Error con el mensaje en español que ve el usuario y el código HTTP. */
export class ErrorRutina extends Error {
  constructor(readonly estado: number, mensaje: string) {
    super(mensaje);
  }
}

export const MENSAJES = {
  sinSesion: 'Inicia sesión para generar tu rutina.',
  entradaInvalida: 'Faltan datos de tu perfil para generar la rutina.',
  cuota: 'Se acabó la cuota gratuita de la IA por ahora. Intenta más tarde o crea tu rutina a mano.',
  sinRespuesta: 'La IA no respondió a tiempo. Intenta de nuevo o crea tu rutina a mano.',
  respuestaRara: 'La IA respondió algo que no se pudo leer. Intenta de nuevo o crea tu rutina a mano.',
  noConfigurada: 'La IA no está configurada en el servidor. Avísale al equipo.',
  sinEjercicios: 'La IA no propuso ejercicios del catálogo. Intenta de nuevo o crea tu rutina a mano.',
} as const;

const OBJETIVOS = ['fuerza', 'hipertrofia', 'perdida_grasa', 'resistencia', 'salud'];
const NIVELES = ['principiante', 'intermedio', 'avanzado'];

/** Revisa la entrada. Lanza ErrorRutina(400) si falta algo. */
export function validarEntrada(dato: unknown): Entrada {
  const e = dato as Partial<Entrada> | null;
  const p = e?.perfil;
  const valido = !!p &&
    OBJETIVOS.includes(p.objetivo as string) &&
    NIVELES.includes(p.nivel_experiencia as string) &&
    Number.isInteger(p.dias_por_semana) && p.dias_por_semana! >= 1 && p.dias_por_semana! <= 7 &&
    Array.isArray(e?.equipo) && e!.equipo!.every((x) => Number.isInteger(x)) &&
    Array.isArray(e?.catalogo) && e!.catalogo!.length > 0 &&
    e!.catalogo!.every((c) => Number.isInteger(c?.id_ejercicio) && typeof c?.nombre_oficial === 'string');
  if (!valido) throw new ErrorRutina(400, MENSAJES.entradaInvalida);
  return e as Entrada;
}

/** Esquema de salida para Gemini (responseSchema, subconjunto de OpenAPI). */
export const ESQUEMA_RESPUESTA = {
  type: 'OBJECT',
  properties: {
    nombre_ciclo: { type: 'STRING' },
    dias: {
      type: 'ARRAY',
      items: {
        type: 'OBJECT',
        properties: {
          dia_semana: { type: 'INTEGER' },
          nombre: { type: 'STRING' },
          es_descanso: { type: 'BOOLEAN' },
          ejercicios: {
            type: 'ARRAY',
            items: {
              type: 'OBJECT',
              properties: {
                id_ejercicio: { type: 'INTEGER' },
                series: { type: 'INTEGER' },
                reps: { type: 'INTEGER' },
                peso_kg: { type: 'NUMBER', nullable: true },
                descanso_seg: { type: 'INTEGER' },
                alternativas: { type: 'ARRAY', items: { type: 'INTEGER' } },
              },
              required: ['id_ejercicio', 'series', 'reps', 'peso_kg', 'descanso_seg', 'alternativas'],
            },
          },
        },
        required: ['dia_semana', 'nombre', 'es_descanso', 'ejercicios'],
      },
    },
  },
  required: ['nombre_ciclo', 'dias'],
};

/** Instrucción para Gemini. Solo datos necesarios, sin datos personales. */
export function construirPrompt(e: Entrada, idsInvalidosPrevios: number[] = []): string {
  const m = e.medicion;
  const lineas = [
    'Eres un entrenador de fuerza. Arma una rutina semanal (lunes a domingo) para esta persona.',
    `Objetivo: ${e.perfil.objetivo}. Nivel: ${e.perfil.nivel_experiencia}.`,
    `Días de entrenamiento por semana: ${e.perfil.dias_por_semana}. Los demás días son de descanso.`,
    m ? `Peso: ${m.peso_kg} kg. Estatura: ${m.estatura_cm} cm.` +
      (m.porcentaje_grasa != null ? ` Grasa: ${m.porcentaje_grasa} %.` : '') : 'Sin medición.',
    e.perfil.notas_lesiones ? `Lesiones o molestias: ${e.perfil.notas_lesiones}` : 'Sin lesiones reportadas.',
    '',
    'Reglas:',
    '- Usa SOLO ejercicios de este catálogo, por su id_ejercicio (no inventes ids):',
    ...e.catalogo.map((c) => `  ${c.id_ejercicio}: ${c.nombre_oficial}`),
    '- Regresa los 7 días (dia_semana de 1 = lunes a 7 = domingo), cada uno una sola vez.',
    '- Los días de descanso llevan es_descanso true y la lista de ejercicios vacía.',
    '- Cada día de entrenamiento lleva un nombre corto en español (por ejemplo "Pierna") y de 4 a 7 ejercicios.',
    '- series de 1 a 6, reps de 1 a 30, descanso_seg de 30 a 300, peso_kg sugerido en kg o null.',
    '- alternativas: hasta 3 id del catálogo del mismo grupo muscular, distintos al ejercicio.',
    '- nombre_ciclo: un nombre corto en español para el ciclo.',
  ];
  if (idsInvalidosPrevios.length > 0) {
    lineas.push(
      `- En tu respuesta anterior usaste ids que NO existen (${idsInvalidosPrevios.join(', ')}). Usa solo los de la lista.`,
    );
  }
  return lineas.join('\n');
}

/** Saca el objeto JSON aunque la IA agregue texto o ``` alrededor. */
export function extraerJson(texto: string): unknown {
  const limpio = texto.trim().replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, '');
  try {
    return JSON.parse(limpio);
  } catch {
    const inicio = limpio.indexOf('{');
    const fin = limpio.lastIndexOf('}');
    if (inicio < 0 || fin <= inicio) throw new ErrorRutina(502, MENSAJES.respuestaRara);
    try {
      return JSON.parse(limpio.slice(inicio, fin + 1));
    } catch {
      throw new ErrorRutina(502, MENSAJES.respuestaRara);
    }
  }
}

const entero = (v: unknown, min: number, max: number, def: number) =>
  Number.isFinite(Number(v)) ? Math.min(max, Math.max(min, Math.round(Number(v)))) : def;

/**
 * Convierte la respuesta de la IA en una rutina válida: siempre 7 días,
 * valores dentro de rango y solo ids de [idsValidos]. Devuelve también los
 * ids que la IA inventó (para reintentar una vez).
 */
export function normalizarRutina(dato: unknown, idsValidos: Set<number>): { rutina: Rutina; idsInvalidos: number[] } {
  const r = dato as { nombre_ciclo?: unknown; dias?: unknown } | null;
  if (!r || typeof r !== 'object' || !Array.isArray(r.dias)) throw new ErrorRutina(502, MENSAJES.respuestaRara);

  const invalidos = new Set<number>();
  const porDia = new Map<number, DiaRutina>();
  for (const crudo of r.dias as Record<string, unknown>[]) {
    const dia = entero(crudo?.dia_semana, 0, 8, 0);
    if (dia < 1 || dia > 7 || porDia.has(dia)) continue; // fuera de rango o repetido
    const ejercicios: EjercicioRutina[] = [];
    const usados = new Set<number>();
    for (const ej of (Array.isArray(crudo.ejercicios) ? crudo.ejercicios : []) as Record<string, unknown>[]) {
      const id = Number(ej?.id_ejercicio);
      if (!idsValidos.has(id)) {
        if (Number.isFinite(id)) invalidos.add(id);
        continue;
      }
      if (usados.has(id)) continue; // el mismo ejercicio dos veces en un día
      usados.add(id);
      const alternativas: number[] = [];
      for (const a of (Array.isArray(ej.alternativas) ? ej.alternativas : []).map(Number)) {
        if (!idsValidos.has(a)) {
          if (Number.isFinite(a)) invalidos.add(a);
          continue;
        }
        if (a !== id && !alternativas.includes(a) && alternativas.length < 3) alternativas.push(a);
      }
      const peso = ej.peso_kg == null ? null : Number(ej.peso_kg);
      ejercicios.push({
        id_ejercicio: id,
        series: entero(ej.series, 1, 20, 3),
        reps: entero(ej.reps, 1, 100, 10),
        peso_kg: peso != null && Number.isFinite(peso) && peso >= 0 ? Math.round(peso * 2) / 2 : null,
        descanso_seg: entero(ej.descanso_seg, 0, 900, 90),
        alternativas,
      });
    }
    const esDescanso = crudo.es_descanso === true || ejercicios.length === 0;
    const nombre = typeof crudo.nombre === 'string' && crudo.nombre.trim() ? crudo.nombre.trim().slice(0, 60) : '';
    porDia.set(dia, {
      dia_semana: dia,
      nombre: esDescanso ? 'Descanso' : (nombre || 'Entrenamiento'),
      es_descanso: esDescanso,
      ejercicios: esDescanso ? [] : ejercicios,
    });
  }
  const dias: DiaRutina[] = [];
  for (let d = 1; d <= 7; d++) {
    dias.push(porDia.get(d) ?? { dia_semana: d, nombre: 'Descanso', es_descanso: true, ejercicios: [] });
  }
  if (dias.every((d) => d.es_descanso)) throw new ErrorRutina(502, MENSAJES.sinEjercicios);

  const nombreCiclo = typeof r.nombre_ciclo === 'string' && r.nombre_ciclo.trim()
    ? r.nombre_ciclo.trim().slice(0, 60)
    : 'Rutina con IA';
  return { rutina: { nombre_ciclo: nombreCiclo, dias }, idsInvalidos: [...invalidos] };
}

/** Llama a la IA con un prompt y regresa el texto JSON. Se inyecta para probar. */
export type LlamarIa = (prompt: string) => Promise<string>;

/**
 * Genera la rutina. Si la IA inventa ids (o la respuesta no se puede leer),
 * reintenta UNA vez avisándole; en el segundo intento se descartan los ids
 * inválidos (criterio 2 de ENT-57).
 */
export async function generarRutina(
  entrada: Entrada,
  idsValidos: Set<number>,
  llamarIa: LlamarIa,
): Promise<{ rutina: Rutina; descartados: number[]; intentos: number }> {
  let previos: number[] = [];
  let ultimoError: unknown = null;
  for (let intento = 1; intento <= 2; intento++) {
    try {
      const texto = await llamarIa(construirPrompt(entrada, previos));
      const { rutina, idsInvalidos } = normalizarRutina(extraerJson(texto), idsValidos);
      if (idsInvalidos.length === 0 || intento === 2) {
        return { rutina, descartados: idsInvalidos, intentos: intento };
      }
      previos = idsInvalidos;
    } catch (e) {
      // Solo se reintenta si la respuesta vino mal; cuota o red no se reintentan.
      if (!(e instanceof ErrorRutina) || e.estado !== 502 || intento === 2) throw e;
      ultimoError = e;
    }
  }
  throw ultimoError ?? new ErrorRutina(502, MENSAJES.respuestaRara);
}

/** Traduce la respuesta HTTP de Gemini a un error en español. */
export function errorDeGemini(estado: number): ErrorRutina {
  if (estado === 429) return new ErrorRutina(429, MENSAJES.cuota);
  if (estado === 400 || estado === 401 || estado === 403) return new ErrorRutina(500, MENSAJES.noConfigurada);
  // 504 (y no 502) para que generarRutina no lo confunda con una respuesta mal formada.
  return new ErrorRutina(504, MENSAJES.sinRespuesta);
}
