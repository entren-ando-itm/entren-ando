// ENT-51: eliminar la cuenta y todos los datos (derecho de cancelación, LFPDPPP).
// El usuario sale de la sesión validada por Supabase Auth; la llave de servicio
// vive solo aquí, en los secretos de la función, nunca en la app.
// Al borrar el usuario de auth.users, las llaves foráneas ON DELETE CASCADE
// borran su fila en `usuario` y todo lo que cuelga de ella.
import { createClient } from 'npm:@supabase/supabase-js@2';

const responder = (estado: number, cuerpo: unknown) => Response.json(cuerpo, { status: estado });

Deno.serve(async (req) => {
  if (req.method !== 'POST') return responder(405, { error: 'Usa POST.' });
  const token = /^Bearer (\S+)$/i.exec(req.headers.get('Authorization') ?? '')?.[1];
  if (!token) return responder(401, { error: 'Inicia sesión para eliminar tu cuenta.' });
  try {
    const url = Deno.env.get('SUPABASE_URL')!;
    const auth = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!);
    const { data, error: errorSesion } = await auth.auth.getUser(token);
    if (errorSesion || !data.user) {
      return responder(401, { error: 'No se pudo validar tu sesión.' });
    }
    const servidor = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { error } = await servidor.auth.admin.deleteUser(data.user.id);
    if (error) throw error;
    return responder(200, { eliminada: true });
  } catch {
    return responder(503, { error: 'No se pudo eliminar la cuenta. Intenta de nuevo.' });
  }
});
