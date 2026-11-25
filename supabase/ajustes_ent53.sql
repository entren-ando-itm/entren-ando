-- =====================================================================
-- Entren-Ando: regla de los 30 días en la nube · ENT-98 (historia ENT-53)
--
-- RF-10 de la ERS: "El sistema bloqueará la edición o el override manual de
-- cualquier día en el calendario que tenga una antigüedad mayor a 30 días
-- naturales". La app ya lo bloquea en pantalla (ENT-70); este trigger lo hace
-- también en Supabase, para que ningún celular lo pueda saltar al sincronizar.
--
-- Qué se rechaza: CAMBIAR o BORRAR (eliminado = true) una sesión, un registro
-- de ejercicio o una serie cuyo día tiene más de 30 días (hora de CDMX).
-- Qué NO se rechaza:
--   * Subir por primera vez (INSERT) un entrenamiento viejo: es un dato que se
--     guardó en su día sin internet, no una edición. También permite subir los
--     datos de prueba y bajar el respaldo a un celular nuevo.
--   * Volver a subir la misma fila sin cambios (la sincronización hace upsert).
--
-- El error sale con el código EA010; la app lo reconoce, descarta su cambio y
-- se queda con la versión de la nube (criterio 4 de ENT-53).
--
-- Se corre UNA vez, después de esquema.sql, del catálogo, de politicas.sql y de
-- ajustes_ent44.sql: SQL Editor > pegar todo > Run. Se puede volver a correr.
-- =====================================================================

CREATE OR REPLACE FUNCTION public.bloquear_cambios_viejos()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  limite date := (now() AT TIME ZONE 'America/Mexico_City')::date - 30;
  dia    date;
BEGIN
  -- Volver a subir lo mismo no es un cambio (actualizado_en y pendiente_sync
  -- no cuentan: los pone la sincronización).
  IF (to_jsonb(NEW) - 'actualizado_en' - 'pendiente_sync')
     = (to_jsonb(OLD) - 'actualizado_en' - 'pendiente_sync') THEN
    RETURN NEW;
  END IF;

  -- El día más viejo entre el de antes y el de después (por si el cambio mueve
  -- la fila a otra sesión o a otra fecha).
  IF TG_TABLE_NAME = 'sesion_entrenamiento' THEN
    dia := LEAST(OLD.fecha, NEW.fecha);
  ELSIF TG_TABLE_NAME = 'registro_ejercicio' THEN
    SELECT min(s.fecha) INTO dia
    FROM public.sesion_entrenamiento s
    WHERE s.id_sesion IN (OLD.id_sesion, NEW.id_sesion);
  ELSE -- serie
    SELECT min(s.fecha) INTO dia
    FROM public.registro_ejercicio r
    JOIN public.sesion_entrenamiento s ON s.id_sesion = r.id_sesion
    WHERE r.id_registro IN (OLD.id_registro, NEW.id_registro);
  END IF;

  IF dia < limite THEN
    RAISE EXCEPTION 'RF-10: no se puede cambiar el % porque tiene más de 30 días', dia
      USING ERRCODE = 'EA010',
            HINT = 'El celular se queda con la versión de la nube (ENT-53).';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sesion_entrenamiento_30_dias ON public.sesion_entrenamiento;
CREATE TRIGGER trg_sesion_entrenamiento_30_dias
  BEFORE UPDATE ON public.sesion_entrenamiento
  FOR EACH ROW EXECUTE FUNCTION public.bloquear_cambios_viejos();

DROP TRIGGER IF EXISTS trg_registro_ejercicio_30_dias ON public.registro_ejercicio;
CREATE TRIGGER trg_registro_ejercicio_30_dias
  BEFORE UPDATE ON public.registro_ejercicio
  FOR EACH ROW EXECUTE FUNCTION public.bloquear_cambios_viejos();

DROP TRIGGER IF EXISTS trg_serie_30_dias ON public.serie;
CREATE TRIGGER trg_serie_30_dias
  BEFORE UPDATE ON public.serie
  FOR EACH ROW EXECUTE FUNCTION public.bloquear_cambios_viejos();

-- Comprobación: deben salir los 3 triggers.
SELECT event_object_table AS tabla, trigger_name
FROM information_schema.triggers
WHERE trigger_name LIKE 'trg_%_30_dias'
ORDER BY 1;
