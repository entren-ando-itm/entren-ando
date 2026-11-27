-- ENT-93. Ejecutar después de politicas.sql, también en instalaciones nuevas.
BEGIN;

-- Las demás columnas siguen sujetas a las políticas por dueño de la cuenta.
REVOKE INSERT, UPDATE ON public.usuario FROM authenticated;
GRANT INSERT (id_usuario, correo, nombre, fecha_nacimiento, sexo, fecha_registro,
              creado_en, actualizado_en, eliminado, pendiente_sync),
      UPDATE (id_usuario, correo, nombre, fecha_nacimiento, sexo, fecha_registro,
              creado_en, actualizado_en, eliminado, pendiente_sync)
ON public.usuario TO authenticated;
REVOKE INSERT, UPDATE ON public.suscripcion, public.evento_pago FROM authenticated;
DROP POLICY IF EXISTS suscripcion_crear ON public.suscripcion;
DROP POLICY IF EXISTS suscripcion_cambiar ON public.suscripcion;

CREATE OR REPLACE FUNCTION public.activar_premium_prueba(p_usuario uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path = ''
AS $$
DECLARE
  compra public.suscripcion%ROWTYPE;
  inicio timestamptz;
BEGIN
  -- Serializa dos activaciones de la misma cuenta, incluso su primera compra.
  PERFORM 1 FROM public.usuario WHERE id_usuario = p_usuario AND NOT eliminado FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Sincroniza tu cuenta antes de activar Premium.' USING ERRCODE = 'EA052';
  END IF;
  inicio := clock_timestamp();
  SELECT * INTO compra FROM public.suscripcion
    WHERE id_usuario = p_usuario AND id_plan = 2 AND NOT eliminado
      AND estado = 'activa' AND fecha_expiracion > inicio
      AND id_transaccion_original LIKE 'PRUEBA%'
    ORDER BY fecha_expiracion DESC LIMIT 1;
  IF NOT FOUND THEN
    INSERT INTO public.suscripcion
      (id_suscripcion, id_usuario, id_plan, tienda, id_transaccion_original, estado,
       fecha_inicio, fecha_expiracion, renovacion_automatica)
    VALUES (gen_random_uuid(), p_usuario, 2, 'google_play', 'PRUEBA-' || gen_random_uuid(),
            'activa', inicio, inicio + interval '720 hours', false)
    RETURNING * INTO compra;

    INSERT INTO public.evento_pago
      (id_evento, id_suscripcion, tipo, id_notificacion_tienda, procesado)
    VALUES (gen_random_uuid(), compra.id_suscripcion, 'compra', compra.id_transaccion_original, true);
  END IF;
  UPDATE public.usuario SET id_plan = 2, actualizado_en = inicio
    WHERE id_usuario = p_usuario AND id_plan <> 2;
  RETURN jsonb_build_object('id_plan', 2, 'id_suscripcion', compra.id_suscripcion,
                            'fecha_expiracion', compra.fecha_expiracion);
END;
$$;
REVOKE ALL ON FUNCTION public.activar_premium_prueba(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.activar_premium_prueba(uuid) TO service_role;
-- ENT-95. Cancelar de inmediato: la suscripción queda 'cancelada', se registra el
-- evento y la cuenta vuelve a Gratuito. El celular archiva los ciclos que sobran.
CREATE OR REPLACE FUNCTION public.cancelar_premium_prueba(p_usuario uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path = ''
AS $$
DECLARE
  compra record;
  ahora timestamptz := clock_timestamp();
BEGIN
  PERFORM 1 FROM public.usuario WHERE id_usuario = p_usuario AND NOT eliminado FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Sincroniza tu cuenta antes de cancelar Premium.' USING ERRCODE = 'EA052';
  END IF;
  FOR compra IN
    UPDATE public.suscripcion
       SET estado = 'cancelada', renovacion_automatica = false, actualizado_en = ahora
     WHERE id_usuario = p_usuario AND id_plan = 2 AND estado = 'activa' AND NOT eliminado
    RETURNING id_suscripcion, id_transaccion_original
  LOOP
    INSERT INTO public.evento_pago
      (id_evento, id_suscripcion, tipo, id_notificacion_tienda, procesado)
    VALUES (gen_random_uuid(), compra.id_suscripcion, 'cancelacion',
            compra.id_transaccion_original || '-CANCELACION', true);
  END LOOP;
  UPDATE public.usuario SET id_plan = 1, actualizado_en = ahora
    WHERE id_usuario = p_usuario AND id_plan <> 1;
  RETURN jsonb_build_object('id_plan', 1);
END;
$$;
REVOKE ALL ON FUNCTION public.cancelar_premium_prueba(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.cancelar_premium_prueba(uuid) TO service_role;

-- ENT-95. Vencimiento: las pruebas que pasaron sus 30 días quedan 'expiradas' y
-- esas cuentas vuelven a Gratuito si no tienen otra compra vigente.
CREATE OR REPLACE FUNCTION public.vencer_premium_prueba()
RETURNS integer LANGUAGE plpgsql SECURITY INVOKER SET search_path = ''
AS $$
DECLARE
  ahora timestamptz := clock_timestamp();
  cuentas integer;
BEGIN
  UPDATE public.suscripcion
     SET estado = 'expirada', actualizado_en = ahora
   WHERE estado = 'activa' AND fecha_expiracion <= ahora AND NOT eliminado;
  UPDATE public.usuario u
     SET id_plan = 1, actualizado_en = ahora
   WHERE u.id_plan = 2
     AND NOT EXISTS (SELECT 1 FROM public.suscripcion s
                      WHERE s.id_usuario = u.id_usuario AND s.id_plan = 2 AND s.estado = 'activa'
                        AND s.fecha_expiracion > ahora AND NOT s.eliminado);
  GET DIAGNOSTICS cuentas = ROW_COUNT;
  RETURN cuentas;
END;
$$;
REVOKE ALL ON FUNCTION public.vencer_premium_prueba() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.vencer_premium_prueba() TO service_role;

-- Revisión diaria con pg_cron (00:15 de Ciudad de México = 06:15 UTC). Si la
-- extensión no está (por ejemplo, en el simulador), se omite.
DO $cron$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.schedule('vencer-premium-prueba', '15 6 * * *', 'SELECT public.vencer_premium_prueba()');
  END IF;
END
$cron$;
COMMIT;
