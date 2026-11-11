-- =====================================================================
-- Entren-Ando: seguridad por usuario (Row Level Security) · ENT-27
--
-- Cada usuario solo ve y modifica SUS filas. auth.uid() es el id del
-- usuario que inició sesión (el mismo que usuario.id_usuario).
--
-- Reglas generales:
--   * RLS activado en las 20 tablas. Nunca se desactiva para que algo funcione.
--   * Nadie borra con DELETE desde la app: se marca eliminado = true.
--     Borrar la cuenta completa (ENT-42) lo hace una función del servidor
--     borrando el usuario de Authentication; la cascada borra todo lo demás.
--   * anon (sin sesión) no puede leer ni escribir nada.
--   * Catálogos (plan, equipo, ejercicio): solo lectura para usuarios con sesión.
--   * solicitud_ia y evento_pago los escriben solo las funciones del servidor
--     (Edge Functions). Así nadie puede borrar o cambiar sus escaneos para
--     saltarse el límite de 3 al día (RN-02).
--   * feedback_ia lo crea el servidor; la app solo lo actualiza (leido = true).
--   * Se usa (select auth.uid()) en lugar de auth.uid() porque Supabase lo
--     calcula una sola vez por consulta y es más rápido.
--
-- Cómo correrlo: después de esquema.sql y del catálogo semilla,
-- panel de Supabase > SQL Editor > pegar todo > Run.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Activar RLS en las 20 tablas y quitar permisos que nadie debe tener
-- ---------------------------------------------------------------------
DO $$
DECLARE
  tabla text;
BEGIN
  FOREACH tabla IN ARRAY ARRAY[
    'plan', 'equipo', 'ejercicio',
    'usuario', 'perfil_entrenamiento', 'medicion_biometrica', 'usuario_equipo',
    'usuario_ejercicio', 'solicitud_ia', 'ciclo_rutina', 'dia_rutina',
    'ejercicio_programado', 'alternativa_ejercicio', 'sesion_entrenamiento',
    'registro_ejercicio', 'serie', 'registro_comida', 'feedback_ia',
    'suscripcion', 'evento_pago'
  ] LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', tabla);
    -- Sin sesión no se toca nada
    EXECUTE format('REVOKE ALL ON public.%I FROM anon', tabla);
    -- Con sesión tampoco se borra: se marca eliminado = true
    EXECUTE format('REVOKE DELETE, TRUNCATE ON public.%I FROM authenticated', tabla);
  END LOOP;
END;
$$;

-- Catálogos y tablas que escribe solo el servidor: sin INSERT ni UPDATE
REVOKE INSERT, UPDATE ON plan, equipo, ejercicio FROM authenticated;
REVOKE INSERT, UPDATE ON solicitud_ia, evento_pago FROM authenticated;
REVOKE INSERT ON feedback_ia FROM authenticated;


-- ---------------------------------------------------------------------
-- 2. Catálogos: cualquier usuario con sesión los lee
-- ---------------------------------------------------------------------

-- Cualquier usuario con sesión puede ver los planes y sus límites.
CREATE POLICY plan_leer ON plan
  FOR SELECT TO authenticated USING (true);

-- Cualquier usuario con sesión puede ver el catálogo de equipo.
CREATE POLICY equipo_leer ON equipo
  FOR SELECT TO authenticated USING (true);

-- Cualquier usuario con sesión puede ver el catálogo de ejercicios.
CREATE POLICY ejercicio_leer ON ejercicio
  FOR SELECT TO authenticated USING (true);


-- ---------------------------------------------------------------------
-- 3. Tablas con id_usuario: la fila es mía si id_usuario = auth.uid()
-- ---------------------------------------------------------------------

-- usuario: solo veo, creo y cambio mi propia cuenta.
CREATE POLICY usuario_leer ON usuario
  FOR SELECT TO authenticated USING (id_usuario = (select auth.uid()));
CREATE POLICY usuario_crear ON usuario
  FOR INSERT TO authenticated WITH CHECK (id_usuario = (select auth.uid()));
CREATE POLICY usuario_cambiar ON usuario
  FOR UPDATE TO authenticated
  USING (id_usuario = (select auth.uid())) WITH CHECK (id_usuario = (select auth.uid()));

-- perfil_entrenamiento: solo mi perfil.
CREATE POLICY perfil_entrenamiento_leer ON perfil_entrenamiento
  FOR SELECT TO authenticated USING (id_usuario = (select auth.uid()));
CREATE POLICY perfil_entrenamiento_crear ON perfil_entrenamiento
  FOR INSERT TO authenticated WITH CHECK (id_usuario = (select auth.uid()));
CREATE POLICY perfil_entrenamiento_cambiar ON perfil_entrenamiento
  FOR UPDATE TO authenticated
  USING (id_usuario = (select auth.uid())) WITH CHECK (id_usuario = (select auth.uid()));

-- medicion_biometrica: solo mis medidas.
CREATE POLICY medicion_biometrica_leer ON medicion_biometrica
  FOR SELECT TO authenticated USING (id_usuario = (select auth.uid()));
CREATE POLICY medicion_biometrica_crear ON medicion_biometrica
  FOR INSERT TO authenticated WITH CHECK (id_usuario = (select auth.uid()));
CREATE POLICY medicion_biometrica_cambiar ON medicion_biometrica
  FOR UPDATE TO authenticated
  USING (id_usuario = (select auth.uid())) WITH CHECK (id_usuario = (select auth.uid()));

-- usuario_equipo: solo el equipo que yo tengo.
CREATE POLICY usuario_equipo_leer ON usuario_equipo
  FOR SELECT TO authenticated USING (id_usuario = (select auth.uid()));
CREATE POLICY usuario_equipo_crear ON usuario_equipo
  FOR INSERT TO authenticated WITH CHECK (id_usuario = (select auth.uid()));
CREATE POLICY usuario_equipo_cambiar ON usuario_equipo
  FOR UPDATE TO authenticated
  USING (id_usuario = (select auth.uid())) WITH CHECK (id_usuario = (select auth.uid()));

-- usuario_ejercicio: solo mis alias de ejercicios.
CREATE POLICY usuario_ejercicio_leer ON usuario_ejercicio
  FOR SELECT TO authenticated USING (id_usuario = (select auth.uid()));
CREATE POLICY usuario_ejercicio_crear ON usuario_ejercicio
  FOR INSERT TO authenticated WITH CHECK (id_usuario = (select auth.uid()));
CREATE POLICY usuario_ejercicio_cambiar ON usuario_ejercicio
  FOR UPDATE TO authenticated
  USING (id_usuario = (select auth.uid())) WITH CHECK (id_usuario = (select auth.uid()));

-- solicitud_ia: solo leo mis solicitudes; las escribe el servidor (RN-02).
CREATE POLICY solicitud_ia_leer ON solicitud_ia
  FOR SELECT TO authenticated USING (id_usuario = (select auth.uid()));

-- ciclo_rutina: solo mis ciclos.
CREATE POLICY ciclo_rutina_leer ON ciclo_rutina
  FOR SELECT TO authenticated USING (id_usuario = (select auth.uid()));
CREATE POLICY ciclo_rutina_crear ON ciclo_rutina
  FOR INSERT TO authenticated WITH CHECK (id_usuario = (select auth.uid()));
CREATE POLICY ciclo_rutina_cambiar ON ciclo_rutina
  FOR UPDATE TO authenticated
  USING (id_usuario = (select auth.uid())) WITH CHECK (id_usuario = (select auth.uid()));

-- sesion_entrenamiento: solo mis sesiones.
CREATE POLICY sesion_entrenamiento_leer ON sesion_entrenamiento
  FOR SELECT TO authenticated USING (id_usuario = (select auth.uid()));
CREATE POLICY sesion_entrenamiento_crear ON sesion_entrenamiento
  FOR INSERT TO authenticated WITH CHECK (id_usuario = (select auth.uid()));
CREATE POLICY sesion_entrenamiento_cambiar ON sesion_entrenamiento
  FOR UPDATE TO authenticated
  USING (id_usuario = (select auth.uid())) WITH CHECK (id_usuario = (select auth.uid()));

-- registro_comida: solo mis comidas.
CREATE POLICY registro_comida_leer ON registro_comida
  FOR SELECT TO authenticated USING (id_usuario = (select auth.uid()));
CREATE POLICY registro_comida_crear ON registro_comida
  FOR INSERT TO authenticated WITH CHECK (id_usuario = (select auth.uid()));
CREATE POLICY registro_comida_cambiar ON registro_comida
  FOR UPDATE TO authenticated
  USING (id_usuario = (select auth.uid())) WITH CHECK (id_usuario = (select auth.uid()));

-- feedback_ia: leo mi feedback y solo lo marco como leído; lo crea el servidor.
CREATE POLICY feedback_ia_leer ON feedback_ia
  FOR SELECT TO authenticated USING (id_usuario = (select auth.uid()));
CREATE POLICY feedback_ia_cambiar ON feedback_ia
  FOR UPDATE TO authenticated
  USING (id_usuario = (select auth.uid())) WITH CHECK (id_usuario = (select auth.uid()));

-- suscripcion: solo mis compras (Premium simulado: la app las crea).
CREATE POLICY suscripcion_leer ON suscripcion
  FOR SELECT TO authenticated USING (id_usuario = (select auth.uid()));
CREATE POLICY suscripcion_crear ON suscripcion
  FOR INSERT TO authenticated WITH CHECK (id_usuario = (select auth.uid()));
CREATE POLICY suscripcion_cambiar ON suscripcion
  FOR UPDATE TO authenticated
  USING (id_usuario = (select auth.uid())) WITH CHECK (id_usuario = (select auth.uid()));


-- ---------------------------------------------------------------------
-- 4. Tablas hijas sin id_usuario: la fila es mía si su "padre" es mío
--    (EXISTS busca hacia arriba hasta la tabla que tiene id_usuario)
-- ---------------------------------------------------------------------

-- dia_rutina: es mío si su ciclo es mío.
CREATE POLICY dia_rutina_leer ON dia_rutina
  FOR SELECT TO authenticated USING (EXISTS (
    SELECT 1 FROM ciclo_rutina c
    WHERE c.id_ciclo = dia_rutina.id_ciclo AND c.id_usuario = (select auth.uid())));
CREATE POLICY dia_rutina_crear ON dia_rutina
  FOR INSERT TO authenticated WITH CHECK (EXISTS (
    SELECT 1 FROM ciclo_rutina c
    WHERE c.id_ciclo = dia_rutina.id_ciclo AND c.id_usuario = (select auth.uid())));
CREATE POLICY dia_rutina_cambiar ON dia_rutina
  FOR UPDATE TO authenticated
  USING (EXISTS (
    SELECT 1 FROM ciclo_rutina c
    WHERE c.id_ciclo = dia_rutina.id_ciclo AND c.id_usuario = (select auth.uid())))
  WITH CHECK (EXISTS (
    SELECT 1 FROM ciclo_rutina c
    WHERE c.id_ciclo = dia_rutina.id_ciclo AND c.id_usuario = (select auth.uid())));

-- ejercicio_programado: es mío si su día pertenece a un ciclo mío.
CREATE POLICY ejercicio_programado_leer ON ejercicio_programado
  FOR SELECT TO authenticated USING (EXISTS (
    SELECT 1 FROM dia_rutina d JOIN ciclo_rutina c ON c.id_ciclo = d.id_ciclo
    WHERE d.id_dia = ejercicio_programado.id_dia AND c.id_usuario = (select auth.uid())));
CREATE POLICY ejercicio_programado_crear ON ejercicio_programado
  FOR INSERT TO authenticated WITH CHECK (EXISTS (
    SELECT 1 FROM dia_rutina d JOIN ciclo_rutina c ON c.id_ciclo = d.id_ciclo
    WHERE d.id_dia = ejercicio_programado.id_dia AND c.id_usuario = (select auth.uid())));
CREATE POLICY ejercicio_programado_cambiar ON ejercicio_programado
  FOR UPDATE TO authenticated
  USING (EXISTS (
    SELECT 1 FROM dia_rutina d JOIN ciclo_rutina c ON c.id_ciclo = d.id_ciclo
    WHERE d.id_dia = ejercicio_programado.id_dia AND c.id_usuario = (select auth.uid())))
  WITH CHECK (EXISTS (
    SELECT 1 FROM dia_rutina d JOIN ciclo_rutina c ON c.id_ciclo = d.id_ciclo
    WHERE d.id_dia = ejercicio_programado.id_dia AND c.id_usuario = (select auth.uid())));

-- alternativa_ejercicio: es mía si su ejercicio programado está en un ciclo mío.
CREATE POLICY alternativa_ejercicio_leer ON alternativa_ejercicio
  FOR SELECT TO authenticated USING (EXISTS (
    SELECT 1 FROM ejercicio_programado p
      JOIN dia_rutina d ON d.id_dia = p.id_dia
      JOIN ciclo_rutina c ON c.id_ciclo = d.id_ciclo
    WHERE p.id_programado = alternativa_ejercicio.id_programado AND c.id_usuario = (select auth.uid())));
CREATE POLICY alternativa_ejercicio_crear ON alternativa_ejercicio
  FOR INSERT TO authenticated WITH CHECK (EXISTS (
    SELECT 1 FROM ejercicio_programado p
      JOIN dia_rutina d ON d.id_dia = p.id_dia
      JOIN ciclo_rutina c ON c.id_ciclo = d.id_ciclo
    WHERE p.id_programado = alternativa_ejercicio.id_programado AND c.id_usuario = (select auth.uid())));
CREATE POLICY alternativa_ejercicio_cambiar ON alternativa_ejercicio
  FOR UPDATE TO authenticated
  USING (EXISTS (
    SELECT 1 FROM ejercicio_programado p
      JOIN dia_rutina d ON d.id_dia = p.id_dia
      JOIN ciclo_rutina c ON c.id_ciclo = d.id_ciclo
    WHERE p.id_programado = alternativa_ejercicio.id_programado AND c.id_usuario = (select auth.uid())))
  WITH CHECK (EXISTS (
    SELECT 1 FROM ejercicio_programado p
      JOIN dia_rutina d ON d.id_dia = p.id_dia
      JOIN ciclo_rutina c ON c.id_ciclo = d.id_ciclo
    WHERE p.id_programado = alternativa_ejercicio.id_programado AND c.id_usuario = (select auth.uid())));

-- registro_ejercicio: es mío si su sesión es mía.
CREATE POLICY registro_ejercicio_leer ON registro_ejercicio
  FOR SELECT TO authenticated USING (EXISTS (
    SELECT 1 FROM sesion_entrenamiento s
    WHERE s.id_sesion = registro_ejercicio.id_sesion AND s.id_usuario = (select auth.uid())));
CREATE POLICY registro_ejercicio_crear ON registro_ejercicio
  FOR INSERT TO authenticated WITH CHECK (EXISTS (
    SELECT 1 FROM sesion_entrenamiento s
    WHERE s.id_sesion = registro_ejercicio.id_sesion AND s.id_usuario = (select auth.uid())));
CREATE POLICY registro_ejercicio_cambiar ON registro_ejercicio
  FOR UPDATE TO authenticated
  USING (EXISTS (
    SELECT 1 FROM sesion_entrenamiento s
    WHERE s.id_sesion = registro_ejercicio.id_sesion AND s.id_usuario = (select auth.uid())))
  WITH CHECK (EXISTS (
    SELECT 1 FROM sesion_entrenamiento s
    WHERE s.id_sesion = registro_ejercicio.id_sesion AND s.id_usuario = (select auth.uid())));

-- serie: es mía si su registro pertenece a una sesión mía.
CREATE POLICY serie_leer ON serie
  FOR SELECT TO authenticated USING (EXISTS (
    SELECT 1 FROM registro_ejercicio r JOIN sesion_entrenamiento s ON s.id_sesion = r.id_sesion
    WHERE r.id_registro = serie.id_registro AND s.id_usuario = (select auth.uid())));
CREATE POLICY serie_crear ON serie
  FOR INSERT TO authenticated WITH CHECK (EXISTS (
    SELECT 1 FROM registro_ejercicio r JOIN sesion_entrenamiento s ON s.id_sesion = r.id_sesion
    WHERE r.id_registro = serie.id_registro AND s.id_usuario = (select auth.uid())));
CREATE POLICY serie_cambiar ON serie
  FOR UPDATE TO authenticated
  USING (EXISTS (
    SELECT 1 FROM registro_ejercicio r JOIN sesion_entrenamiento s ON s.id_sesion = r.id_sesion
    WHERE r.id_registro = serie.id_registro AND s.id_usuario = (select auth.uid())))
  WITH CHECK (EXISTS (
    SELECT 1 FROM registro_ejercicio r JOIN sesion_entrenamiento s ON s.id_sesion = r.id_sesion
    WHERE r.id_registro = serie.id_registro AND s.id_usuario = (select auth.uid())));

-- evento_pago: solo leo los avisos de mis suscripciones; los escribe el servidor.
CREATE POLICY evento_pago_leer ON evento_pago
  FOR SELECT TO authenticated USING (EXISTS (
    SELECT 1 FROM suscripcion s
    WHERE s.id_suscripcion = evento_pago.id_suscripcion AND s.id_usuario = (select auth.uid())));
