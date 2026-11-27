-- Ejecutar con psql -v ON_ERROR_STOP=1 en el simulador, después de nube_limpia.sh.
BEGIN;
INSERT INTO auth.users (id, email) VALUES
  ('52000000-0000-4000-8000-000000000093', 'premium-ent93@example.test');
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub = '52000000-0000-4000-8000-000000000093';
INSERT INTO public.usuario (id_usuario, correo, nombre)
  VALUES (auth.uid(), 'premium-ent93@example.test', 'Inicial');
DO $$
BEGIN
  ASSERT (SELECT id_plan = 1 FROM public.usuario WHERE id_usuario = auth.uid());
  ASSERT NOT has_column_privilege(current_user, 'public.usuario', 'id_plan', 'INSERT');
  ASSERT NOT has_column_privilege(current_user, 'public.usuario', 'id_plan', 'UPDATE');
  ASSERT NOT has_table_privilege(current_user, 'public.suscripcion', 'INSERT');
  ASSERT NOT has_table_privilege(current_user, 'public.evento_pago', 'INSERT');
  ASSERT NOT has_function_privilege(current_user, 'public.activar_premium_prueba(uuid)', 'EXECUTE');
END;
$$;
SET LOCAL ROLE service_role;
DO $$
DECLARE
  cuenta CONSTANT uuid := '52000000-0000-4000-8000-000000000093';
  primera jsonb := public.activar_premium_prueba(cuenta);
BEGIN
  ASSERT primera = public.activar_premium_prueba(cuenta);
  ASSERT (primera->>'id_plan')::integer = 2;
  ASSERT (SELECT count(*) = 1 FROM public.suscripcion WHERE id_usuario = cuenta);
  ASSERT (SELECT tienda = 'google_play' AND estado = 'activa' AND NOT renovacion_automatica
                 AND fecha_expiracion - fecha_inicio = interval '720 hours'
                 AND (substring(id_transaccion_original from 8))::uuid IS NOT NULL
          FROM public.suscripcion WHERE id_usuario = cuenta AND id_transaccion_original LIKE 'PRUEBA-%');
  ASSERT (SELECT count(*) = 1 FROM public.evento_pago
          WHERE id_suscripcion = (primera->>'id_suscripcion')::uuid AND tipo = 'compra' AND procesado);
END;
$$;
-- El celular con el plan anterior sincroniza después de la compra desde otro equipo.
SET LOCAL ROLE authenticated;
INSERT INTO public.usuario (id_usuario, correo, nombre, actualizado_en)
  VALUES (auth.uid(), 'premium-ent93@example.test', 'Editado sin red', now() - interval '1 day')
  ON CONFLICT (id_usuario) DO UPDATE SET nombre = excluded.nombre, actualizado_en = excluded.actualizado_en;
DO $$
BEGIN
  ASSERT (SELECT nombre = 'Editado sin red' AND id_plan = 2 FROM public.usuario WHERE id_usuario = auth.uid());
END;
$$;
ROLLBACK;
