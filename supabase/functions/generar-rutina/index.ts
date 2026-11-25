// Edge Function generar-rutina (ENT-57, ENT-100 y ENT-101).
//
// Recibe el perfil, la medición, el equipo y el catálogo filtrado (solo id y
// nombre oficial), pide a Gemini una semana en JSON, valida que cada
// id_ejercicio exista y registra la llamada en solicitud_ia.
//
// La llave de Gemini es un secreto de Supabase: solo se lee con Deno.env.get
// (decisión 5 de la bitácora). Nunca va en la app ni en este código.
import { createClient } from 'npm:@supabase/supabase-js@2';
import {
  ErrorRutina,
  errorDeGemini,
  ESQUEMA_RESPUESTA,
  generarRutina,
  MENSAJES,
  validarEntrada,
} from './logica.ts';

/** Modelo Flash de Gemini. Se puede cambiar con el secreto GEMINI_MODELO sin tocar código. */
const MODELO = Deno.env.get('GEMINI_MODELO') ?? 'gemini-2.5-flash';

/** Dirección de la API de Gemini (se cambia solo para probar con un servidor falso). */
const URL_GEMINI = Deno.env.get('GEMINI_URL_BASE') ?? 'https://generativelanguage.googleapis.com';

/** La app espera 30 s como máximo (ENT-58); dos intentos deben caber. */
const ESPERA_GEMINI_MS = 13_000;

const CABECERAS = {
  'Content-Type': 'application/json; charset=utf-8',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const responder = (estado: number, cuerpo: unknown) =>
  new Response(JSON.stringify(cuerpo), { status: estado, headers: CABECERAS });

/** Llama a Gemini pidiendo salida JSON con el esquema. Devuelve el texto. */
async function llamarGemini(prompt: string): Promise<string> {
  const llave = Deno.env.get('GEMINI_API_KEY');
  if (!llave) throw new ErrorRutina(500, MENSAJES.noConfigurada);
  let respuesta: Response;
  try {
    respuesta = await fetch(
      `${URL_GEMINI}/v1beta/models/${MODELO}:generateContent`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'x-goog-api-key': llave },
        body: JSON.stringify({
          contents: [{ role: 'user', parts: [{ text: prompt }] }],
          generationConfig: {
            responseMimeType: 'application/json',
            responseSchema: ESQUEMA_RESPUESTA,
            temperature: 0.4,
          },
        }),
        signal: AbortSignal.timeout(ESPERA_GEMINI_MS),
      },
    );
  } catch {
    throw new ErrorRutina(504, MENSAJES.sinRespuesta); // tiempo agotado o sin red
  }
  if (!respuesta.ok) throw errorDeGemini(respuesta.status);
  const datos = await respuesta.json().catch(() => null);
  const texto = datos?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (typeof texto !== 'string') throw new ErrorRutina(502, MENSAJES.respuestaRara);
  return texto;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CABECERAS });
  if (req.method !== 'POST') return responder(405, { error: 'Usa POST.' });

  const url = Deno.env.get('SUPABASE_URL')!;
  const llaveAnonima = Deno.env.get('SUPABASE_ANON_KEY')!;
  const llaveServicio = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

  // 1. Validar el JWT del usuario (no se confía en un id que mande la app).
  const autorizacion = req.headers.get('Authorization') ?? '';
  const comoUsuario = createClient(url, llaveAnonima, { global: { headers: { Authorization: autorizacion } } });
  const { data: sesion } = await comoUsuario.auth.getUser();
  const usuario = sesion?.user;
  if (!usuario) return responder(401, { error: MENSAJES.sinSesion });

  // 2. Validar la entrada.
  let entrada;
  try {
    entrada = validarEntrada(await req.json());
  } catch (e) {
    return responder(e instanceof ErrorRutina ? e.estado : 400, { error: MENSAJES.entradaInvalida });
  }

  // solicitud_ia solo la escribe el servidor (RLS, decisión 7): cliente de servicio.
  const servidor = createClient(url, llaveServicio, { auth: { persistSession: false } });
  const idSolicitud = crypto.randomUUID();
  const { error: errorAlta } = await servidor.from('solicitud_ia').insert({
    id_solicitud: idSolicitud,
    id_usuario: usuario.id,
    tipo: 'rutina',
    estado: 'pendiente',
  });
  if (errorAlta) {
    console.error('generar-rutina: no se pudo crear solicitud_ia', errorAlta.message);
    return responder(500, { error: 'No se pudo registrar la solicitud. Intenta de nuevo.' });
  }
  const terminar = (estado: 'completada' | 'fallida') =>
    servidor.from('solicitud_ia')
      .update({ estado, actualizado_en: new Date().toISOString() })
      .eq('id_solicitud', idSolicitud);

  try {
    // 3. Solo cuentan los ids que la app mandó Y que existen en el catálogo de la nube.
    const ids = [...new Set(entrada.catalogo.map((c) => c.id_ejercicio))];
    const { data: existentes, error: errorCatalogo } = await servidor
      .from('ejercicio').select('id_ejercicio').in('id_ejercicio', ids);
    if (errorCatalogo) throw new ErrorRutina(500, 'No se pudo leer el catálogo. Intenta de nuevo.');
    const idsValidos = new Set<number>((existentes ?? []).map((f: { id_ejercicio: number }) => f.id_ejercicio));
    entrada.catalogo = entrada.catalogo.filter((c) => idsValidos.has(c.id_ejercicio));
    if (entrada.catalogo.length === 0) throw new ErrorRutina(400, MENSAJES.entradaInvalida);

    // 4. Gemini, con un reintento si inventa ids (logica.ts).
    const { rutina, descartados, intentos } = await generarRutina(entrada, idsValidos, llamarGemini);
    await terminar('completada');
    return responder(200, { id_solicitud: idSolicitud, rutina, descartados, intentos });
  } catch (e) {
    await terminar('fallida');
    if (e instanceof ErrorRutina) return responder(e.estado, { error: e.message, id_solicitud: idSolicitud });
    console.error('generar-rutina: error inesperado', e);
    return responder(500, { error: 'Algo falló al generar la rutina. Intenta de nuevo.', id_solicitud: idSolicitud });
  }
});
