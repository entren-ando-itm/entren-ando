// ENT-93 y ENT-95: activar o cancelar la prueba de Premium. El usuario de la compra sale de la sesión validada por Supabase Auth.
import { createClient } from 'npm:@supabase/supabase-js@2';

const responder = (estado: number, cuerpo: unknown) => Response.json(cuerpo, { status: estado });

Deno.serve(async (req) => {
  if (req.method !== 'POST') return responder(405, { error: 'Usa POST.' });
  // Encendida por defecto (versión escolar). Se apaga con el secreto
  // PREMIUM_PRUEBA_HABILITADA=false.
  if (Deno.env.get('PREMIUM_PRUEBA_HABILITADA') === 'false') {
    return responder(403, { error: 'La compra de prueba está desactivada.' });
  }
  const token = /^Bearer (\S+)$/i.exec(req.headers.get('Authorization') ?? '')?.[1];
  if (!token) return responder(401, { error: 'Inicia sesión para activar Premium.' });
  try {
    const url = Deno.env.get('SUPABASE_URL')!;
    const auth = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!);
    const { data, error: errorSesion } = await auth.auth.getUser(token);
    if (errorSesion || !data.user) {
      return responder(401, { error: 'No se pudo validar tu sesión.' });
    }
    const cuerpo = await req.json().catch(() => ({}));
    const accion = cuerpo?.accion ?? 'activar';
    if (accion !== 'activar' && accion !== 'cancelar') {
      return responder(400, { error: 'Acción no válida.' });
    }
    const servidor = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
    const compra = await servidor.rpc(
      accion === 'cancelar' ? 'cancelar_premium_prueba' : 'activar_premium_prueba',
      { p_usuario: data.user.id },
    );
    if (compra.error?.code === 'EA052') {
      return responder(409, { error: 'Sincroniza tu cuenta antes de activar Premium.' });
    }
    if (compra.error) throw compra.error;
    return responder(200, compra.data);
  } catch {
    return responder(503, { error: 'No se pudo activar Premium. Intenta de nuevo.' });
  }
});
