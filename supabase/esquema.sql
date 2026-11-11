-- =====================================================================
-- Entren-Ando: esquema de la nube (PostgreSQL de Supabase) · ENT-27
--
-- Copia de entren_ando/lib/core/db/esquema.sql con los mismos nombres de
-- tablas y columnas. Solo cambian los tipos:
--   * id de texto (UUID)       -> uuid
--   * fecha y hora (TEXT ISO)  -> timestamptz
--   * fecha (TEXT 'AAAA-MM-DD')-> date
--   * hora (TEXT 'HH:MM:SS')   -> time
--   * enteros 0 o 1            -> boolean
--   * REAL                     -> numeric (igual que DECIMAL en MySQL)
--   * ENUM                     -> text con CHECK (igual que en el celular)
--
-- Reglas:
--   * usuario.id_usuario es el mismo uuid de auth.users (el de Authentication).
--   * Catálogos plan, equipo y ejercicio: id entero fijo, igual que en el
--     celular. Se llenan con docs/12_catalogo_semilla.sql y son de solo lectura.
--   * Nunca se borra con DELETE: se marca eliminado = true. Por eso los UNIQUE
--     de las tablas del usuario solo cuentan las filas no eliminadas.
--   * pendiente_sync existe para que las columnas sean iguales al celular,
--     pero en la nube siempre vale false (lo fuerza un trigger). Así, cuando el
--     celular baja una fila, no la vuelve a marcar como pendiente.
--   * La seguridad por usuario (RLS) está en supabase/politicas.sql.
--
-- Cómo correrlo: panel de Supabase > SQL Editor > pegar todo > Run.
-- Después correr docs/12_catalogo_semilla.sql y supabase/politicas.sql.
-- =====================================================================


-- ---------------------------------------------------------------------
-- Catálogos (id entero fijo, solo lectura)
-- ---------------------------------------------------------------------

-- Catálogo de planes y sus límites freemium (RN-01 a RN-03)
CREATE TABLE plan (
  id_plan                  integer       NOT NULL,
  nombre                   text          NOT NULL,
  max_ciclos_activos       integer       NULL,            -- NULL = ilimitado (RN-01)
  max_escaneos_dia         integer       NULL,            -- NULL = ilimitado (RN-02)
  frecuencia_feedback      text          NOT NULL,        -- RN-03
  precio                   numeric(8,2)  NULL,            -- MXN al mes
  CONSTRAINT pk_plan PRIMARY KEY (id_plan),
  CONSTRAINT uk_plan_nombre UNIQUE (nombre),
  CONSTRAINT ck_plan_frecuencia_feedback CHECK (frecuencia_feedback IN ('semanal', 'mensual')),
  CONSTRAINT ck_plan_max_ciclos_activos CHECK (max_ciclos_activos IS NULL OR max_ciclos_activos >= 0),
  CONSTRAINT ck_plan_max_escaneos_dia CHECK (max_escaneos_dia IS NULL OR max_escaneos_dia >= 0)
);

-- Catálogo de equipo de gimnasio
CREATE TABLE equipo (
  id_equipo                integer       NOT NULL,
  nombre                   text          NOT NULL,
  categoria                text          NULL,
  CONSTRAINT pk_equipo PRIMARY KEY (id_equipo),
  CONSTRAINT uk_equipo_nombre UNIQUE (nombre)
);

-- Catálogo global; la IA usa siempre id_ejercicio (RF-05)
CREATE TABLE ejercicio (
  id_ejercicio             integer       NOT NULL,
  nombre_oficial           text          NOT NULL,
  grupo_muscular           text          NOT NULL,
  tipo_movimiento          text          NOT NULL,
  id_equipo                integer       NULL,            -- NULL = peso corporal
  descripcion_tecnica      text          NULL,
  CONSTRAINT pk_ejercicio PRIMARY KEY (id_ejercicio),
  CONSTRAINT uk_ejercicio_nombre_oficial UNIQUE (nombre_oficial),
  CONSTRAINT fk_ejercicio_equipo FOREIGN KEY (id_equipo) REFERENCES equipo (id_equipo) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT ck_ejercicio_tipo_movimiento CHECK (tipo_movimiento IN ('compuesto', 'aislamiento'))
);


-- ---------------------------------------------------------------------
-- Tablas del usuario (uuid + creado_en, actualizado_en, eliminado, pendiente_sync)
-- ---------------------------------------------------------------------

-- Cuenta del deportista; id_plan es el plan vigente
CREATE TABLE usuario (
  id_usuario               uuid          NOT NULL,
  correo                   text          NOT NULL,
  nombre                   text          NOT NULL,
  fecha_nacimiento         date          NULL,
  sexo                     text          NULL,
  id_plan                  integer       NOT NULL DEFAULT 1,
  fecha_registro           timestamptz   NOT NULL DEFAULT now(),
  creado_en                timestamptz   NOT NULL DEFAULT now(),
  actualizado_en           timestamptz   NOT NULL DEFAULT now(),
  eliminado                boolean       NOT NULL DEFAULT false,
  pendiente_sync           boolean       NOT NULL DEFAULT false,
  CONSTRAINT pk_usuario PRIMARY KEY (id_usuario),
  -- Al borrar la cuenta en Authentication se borran todos sus datos (LFPDPPP, derechos ARCO)
  CONSTRAINT fk_usuario_auth FOREIGN KEY (id_usuario) REFERENCES auth.users (id) ON DELETE CASCADE,
  CONSTRAINT fk_usuario_plan FOREIGN KEY (id_plan) REFERENCES plan (id_plan) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT ck_usuario_sexo CHECK (sexo IS NULL OR sexo IN ('masculino', 'femenino', 'otro'))
);
CREATE UNIQUE INDEX uk_usuario_correo ON usuario (correo) WHERE NOT eliminado;

-- Objetivos y nivel del usuario (RF-01); 1 a 1 con usuario
CREATE TABLE perfil_entrenamiento (
  id_perfil                uuid          NOT NULL,
  id_usuario               uuid          NOT NULL,
  objetivo                 text          NOT NULL,
  nivel_experiencia        text          NOT NULL,
  dias_por_semana          integer       NOT NULL,
  notas_lesiones           text          NULL,
  creado_en                timestamptz   NOT NULL DEFAULT now(),
  actualizado_en           timestamptz   NOT NULL DEFAULT now(),
  eliminado                boolean       NOT NULL DEFAULT false,
  pendiente_sync           boolean       NOT NULL DEFAULT false,
  CONSTRAINT pk_perfil_entrenamiento PRIMARY KEY (id_perfil),
  CONSTRAINT fk_perfil_entrenamiento_usuario FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT ck_perfil_entrenamiento_1 CHECK (dias_por_semana BETWEEN 1 AND 7),
  CONSTRAINT ck_perfil_entrenamiento_objetivo CHECK (objetivo IN ('fuerza', 'hipertrofia', 'perdida_grasa', 'resistencia', 'salud')),
  CONSTRAINT ck_perfil_entrenamiento_nivel CHECK (nivel_experiencia IN ('principiante', 'intermedio', 'avanzado'))
);
CREATE UNIQUE INDEX uk_perfil_entrenamiento_id_usuario ON perfil_entrenamiento (id_usuario) WHERE NOT eliminado;

-- Historial de medidas corporales (RF-01)
CREATE TABLE medicion_biometrica (
  id_medicion              uuid          NOT NULL,
  id_usuario               uuid          NOT NULL,
  fecha                    date          NOT NULL,
  peso_kg                  numeric(5,2)  NOT NULL,
  estatura_cm              numeric(5,1)  NOT NULL,
  porcentaje_grasa         numeric(4,1)  NULL,
  creado_en                timestamptz   NOT NULL DEFAULT now(),
  actualizado_en           timestamptz   NOT NULL DEFAULT now(),
  eliminado                boolean       NOT NULL DEFAULT false,
  pendiente_sync           boolean       NOT NULL DEFAULT false,
  CONSTRAINT pk_medicion_biometrica PRIMARY KEY (id_medicion),
  CONSTRAINT fk_medicion_biometrica_usuario FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT ck_medicion_biometrica_1 CHECK (peso_kg > 0),
  CONSTRAINT ck_medicion_biometrica_2 CHECK (estatura_cm > 0)
);

-- Equipo que tiene disponible cada usuario (N:M)
CREATE TABLE usuario_equipo (
  id_usuario               uuid          NOT NULL,
  id_equipo                integer       NOT NULL,
  creado_en                timestamptz   NOT NULL DEFAULT now(),
  actualizado_en           timestamptz   NOT NULL DEFAULT now(),
  eliminado                boolean       NOT NULL DEFAULT false,
  pendiente_sync           boolean       NOT NULL DEFAULT false,
  CONSTRAINT pk_usuario_equipo PRIMARY KEY (id_usuario, id_equipo),
  CONSTRAINT fk_usuario_equipo_usuario FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_usuario_equipo_equipo FOREIGN KEY (id_equipo) REFERENCES equipo (id_equipo) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- Alias personalizado de un ejercicio por usuario (RF-05)
CREATE TABLE usuario_ejercicio (
  id_usuario               uuid          NOT NULL,
  id_ejercicio             integer       NOT NULL,
  nombre_alias             text          NOT NULL,
  creado_en                timestamptz   NOT NULL DEFAULT now(),
  actualizado_en           timestamptz   NOT NULL DEFAULT now(),
  eliminado                boolean       NOT NULL DEFAULT false,
  pendiente_sync           boolean       NOT NULL DEFAULT false,
  CONSTRAINT pk_usuario_ejercicio PRIMARY KEY (id_usuario, id_ejercicio),
  CONSTRAINT fk_usuario_ejercicio_usuario FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_usuario_ejercicio_ejercicio FOREIGN KEY (id_ejercicio) REFERENCES ejercicio (id_ejercicio) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- Peticiones a la IA; sirve para contar los escaneos del día (RN-02)
CREATE TABLE solicitud_ia (
  id_solicitud             uuid          NOT NULL,
  id_usuario               uuid          NOT NULL,
  tipo                     text          NOT NULL,
  fecha_hora               timestamptz   NOT NULL DEFAULT now(),
  estado                   text          NOT NULL DEFAULT 'pendiente',
  creado_en                timestamptz   NOT NULL DEFAULT now(),
  actualizado_en           timestamptz   NOT NULL DEFAULT now(),
  eliminado                boolean       NOT NULL DEFAULT false,
  pendiente_sync           boolean       NOT NULL DEFAULT false,
  CONSTRAINT pk_solicitud_ia PRIMARY KEY (id_solicitud),
  CONSTRAINT fk_solicitud_ia_usuario FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT ck_solicitud_ia_tipo CHECK (tipo IN ('rutina', 'escaneo', 'feedback')),
  CONSTRAINT ck_solicitud_ia_estado CHECK (estado IN ('pendiente', 'completada', 'fallida'))
);
CREATE INDEX idx_solicitud_cuota ON solicitud_ia (id_usuario, tipo, fecha_hora);

-- Rutina por ciclos o semestres (RF-02); plan gratuito: 1 activo (RN-01)
CREATE TABLE ciclo_rutina (
  id_ciclo                 uuid          NOT NULL,
  id_usuario               uuid          NOT NULL,
  id_solicitud             uuid          NULL,            -- Solicitud de IA que la originó
  nombre                   text          NOT NULL,
  fecha_inicio             date          NOT NULL,
  fecha_fin                date          NULL,
  estado                   text          NOT NULL DEFAULT 'activo',
  origen                   text          NOT NULL,
  creado_en                timestamptz   NOT NULL DEFAULT now(),
  actualizado_en           timestamptz   NOT NULL DEFAULT now(),
  eliminado                boolean       NOT NULL DEFAULT false,
  pendiente_sync           boolean       NOT NULL DEFAULT false,
  CONSTRAINT pk_ciclo_rutina PRIMARY KEY (id_ciclo),
  CONSTRAINT fk_ciclo_rutina_usuario FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_ciclo_rutina_solicitud FOREIGN KEY (id_solicitud) REFERENCES solicitud_ia (id_solicitud) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT ck_ciclo_rutina_1 CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio),
  CONSTRAINT ck_ciclo_rutina_estado CHECK (estado IN ('activo', 'archivado')),
  CONSTRAINT ck_ciclo_rutina_origen CHECK (origen IN ('ia', 'manual'))
);
CREATE UNIQUE INDEX uk_ciclo_rutina_id_solicitud ON ciclo_rutina (id_solicitud) WHERE NOT eliminado;

-- Día de la plantilla tipo horario escolar
CREATE TABLE dia_rutina (
  id_dia                   uuid          NOT NULL,
  id_ciclo                 uuid          NOT NULL,
  dia_semana               integer       NOT NULL,        -- 1 = lunes ... 7 = domingo
  nombre                   text          NOT NULL,
  es_descanso              boolean       NOT NULL DEFAULT false,
  creado_en                timestamptz   NOT NULL DEFAULT now(),
  actualizado_en           timestamptz   NOT NULL DEFAULT now(),
  eliminado                boolean       NOT NULL DEFAULT false,
  pendiente_sync           boolean       NOT NULL DEFAULT false,
  CONSTRAINT pk_dia_rutina PRIMARY KEY (id_dia),
  CONSTRAINT fk_dia_rutina_ciclo FOREIGN KEY (id_ciclo) REFERENCES ciclo_rutina (id_ciclo) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT ck_dia_rutina_1 CHECK (dia_semana BETWEEN 1 AND 7)
);
CREATE UNIQUE INDEX uk_dia_rutina_id_ciclo_dia_semana ON dia_rutina (id_ciclo, dia_semana) WHERE NOT eliminado;

-- Ejercicio planeado dentro de un día de la rutina
CREATE TABLE ejercicio_programado (
  id_programado            uuid          NOT NULL,
  id_dia                   uuid          NOT NULL,
  id_ejercicio             integer       NOT NULL,
  orden                    integer       NOT NULL,
  series_objetivo          integer       NOT NULL,
  reps_objetivo            integer       NOT NULL,
  peso_objetivo_kg         numeric(6,2)  NULL,
  descanso_seg             integer       NOT NULL DEFAULT 90,
  trabajo_seg              integer       NULL,
  creado_en                timestamptz   NOT NULL DEFAULT now(),
  actualizado_en           timestamptz   NOT NULL DEFAULT now(),
  eliminado                boolean       NOT NULL DEFAULT false,
  pendiente_sync           boolean       NOT NULL DEFAULT false,
  CONSTRAINT pk_ejercicio_programado PRIMARY KEY (id_programado),
  CONSTRAINT fk_ejercicio_programado_dia FOREIGN KEY (id_dia) REFERENCES dia_rutina (id_dia) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_ejercicio_programado_ejercicio FOREIGN KEY (id_ejercicio) REFERENCES ejercicio (id_ejercicio) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT ck_ejercicio_programado_orden CHECK (orden >= 0),
  CONSTRAINT ck_ejercicio_programado_series CHECK (series_objetivo >= 0),
  CONSTRAINT ck_ejercicio_programado_reps CHECK (reps_objetivo >= 0),
  CONSTRAINT ck_ejercicio_programado_descanso CHECK (descanso_seg >= 0),
  CONSTRAINT ck_ejercicio_programado_trabajo CHECK (trabajo_seg IS NULL OR trabajo_seg >= 0)
);

-- Alternativas preconfiguradas para sustituir un ejercicio (RF-04)
CREATE TABLE alternativa_ejercicio (
  id_alternativa           uuid          NOT NULL,
  id_programado            uuid          NOT NULL,
  id_ejercicio             integer       NOT NULL,
  prioridad                integer       NOT NULL DEFAULT 1,
  creado_en                timestamptz   NOT NULL DEFAULT now(),
  actualizado_en           timestamptz   NOT NULL DEFAULT now(),
  eliminado                boolean       NOT NULL DEFAULT false,
  pendiente_sync           boolean       NOT NULL DEFAULT false,
  CONSTRAINT pk_alternativa_ejercicio PRIMARY KEY (id_alternativa),
  CONSTRAINT fk_alternativa_ejercicio_programado FOREIGN KEY (id_programado) REFERENCES ejercicio_programado (id_programado) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_alternativa_ejercicio_ejercicio FOREIGN KEY (id_ejercicio) REFERENCES ejercicio (id_ejercicio) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT ck_alternativa_ejercicio_prioridad CHECK (prioridad >= 0)
);

-- Entrenamiento de un día; su estado colorea el calendario (RF-08 a RF-10)
CREATE TABLE sesion_entrenamiento (
  id_sesion                uuid          NOT NULL,
  id_usuario               uuid          NOT NULL,
  id_dia                   uuid          NULL,
  fecha                    date          NOT NULL,
  estado                   text          NOT NULL,
  es_override              boolean       NOT NULL DEFAULT false,  -- RF-09
  comentario               text          NULL,
  hora_inicio              time          NULL,
  hora_fin                 time          NULL,
  creado_en                timestamptz   NOT NULL DEFAULT now(),
  actualizado_en           timestamptz   NOT NULL DEFAULT now(),
  eliminado                boolean       NOT NULL DEFAULT false,
  pendiente_sync           boolean       NOT NULL DEFAULT false,
  CONSTRAINT pk_sesion_entrenamiento PRIMARY KEY (id_sesion),
  CONSTRAINT fk_sesion_entrenamiento_usuario FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_sesion_entrenamiento_dia FOREIGN KEY (id_dia) REFERENCES dia_rutina (id_dia) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT ck_sesion_entrenamiento_estado CHECK (estado IN ('completa', 'parcial', 'descanso'))
);
CREATE INDEX idx_sesion_calendario ON sesion_entrenamiento (id_usuario, fecha);

-- Ejercicio realmente ejecutado en una sesión (RF-03, RF-04)
CREATE TABLE registro_ejercicio (
  id_registro              uuid          NOT NULL,
  id_sesion                uuid          NOT NULL,
  id_programado            uuid          NULL,
  id_ejercicio             integer       NOT NULL,
  es_sustitucion           boolean       NOT NULL DEFAULT false,
  orden                    integer       NOT NULL,
  completado               boolean       NOT NULL DEFAULT false,
  creado_en                timestamptz   NOT NULL DEFAULT now(),
  actualizado_en           timestamptz   NOT NULL DEFAULT now(),
  eliminado                boolean       NOT NULL DEFAULT false,
  pendiente_sync           boolean       NOT NULL DEFAULT false,
  CONSTRAINT pk_registro_ejercicio PRIMARY KEY (id_registro),
  CONSTRAINT fk_registro_ejercicio_sesion FOREIGN KEY (id_sesion) REFERENCES sesion_entrenamiento (id_sesion) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_registro_ejercicio_programado FOREIGN KEY (id_programado) REFERENCES ejercicio_programado (id_programado) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_registro_ejercicio_ejercicio FOREIGN KEY (id_ejercicio) REFERENCES ejercicio (id_ejercicio) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT ck_registro_ejercicio_orden CHECK (orden >= 0)
);

-- Cada serie marcada en la bitácora (RF-03)
CREATE TABLE serie (
  id_serie                 uuid          NOT NULL,
  id_registro              uuid          NOT NULL,
  numero_serie             integer       NOT NULL,
  peso_kg                  numeric(6,2)  NOT NULL,
  repeticiones             integer       NOT NULL,
  completada_en            timestamptz   NULL,
  creado_en                timestamptz   NOT NULL DEFAULT now(),
  actualizado_en           timestamptz   NOT NULL DEFAULT now(),
  eliminado                boolean       NOT NULL DEFAULT false,
  pendiente_sync           boolean       NOT NULL DEFAULT false,
  CONSTRAINT pk_serie PRIMARY KEY (id_serie),
  CONSTRAINT fk_serie_registro FOREIGN KEY (id_registro) REFERENCES registro_ejercicio (id_registro) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT ck_serie_1 CHECK (peso_kg >= 0),
  CONSTRAINT ck_serie_numero_serie CHECK (numero_serie >= 0),
  CONSTRAINT ck_serie_repeticiones CHECK (repeticiones >= 0)
);
CREATE UNIQUE INDEX uk_serie_id_registro_numero_serie ON serie (id_registro, numero_serie) WHERE NOT eliminado;

-- Registro nutricional manual o por foto con IA (RF-07)
CREATE TABLE registro_comida (
  id_comida                uuid          NOT NULL,
  id_usuario               uuid          NOT NULL,
  id_solicitud             uuid          NULL,            -- Escaneo de IA que la originó
  fecha_hora               timestamptz   NOT NULL DEFAULT now(),
  descripcion              text          NOT NULL,
  calorias                 integer       NOT NULL,
  proteinas_g              numeric(6,1)  NULL,
  carbohidratos_g          numeric(6,1)  NULL,
  grasas_g                 numeric(6,1)  NULL,
  origen                   text          NOT NULL DEFAULT 'manual',
  creado_en                timestamptz   NOT NULL DEFAULT now(),
  actualizado_en           timestamptz   NOT NULL DEFAULT now(),
  eliminado                boolean       NOT NULL DEFAULT false,
  pendiente_sync           boolean       NOT NULL DEFAULT false,
  CONSTRAINT pk_registro_comida PRIMARY KEY (id_comida),
  CONSTRAINT fk_registro_comida_usuario FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_registro_comida_solicitud FOREIGN KEY (id_solicitud) REFERENCES solicitud_ia (id_solicitud) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT ck_registro_comida_calorias CHECK (calorias >= 0),
  CONSTRAINT ck_registro_comida_origen CHECK (origen IN ('manual', 'ia'))
);
CREATE UNIQUE INDEX uk_registro_comida_id_solicitud ON registro_comida (id_solicitud) WHERE NOT eliminado;

-- Mensaje periódico de la IA; analiza sesiones y comidas del periodo (RF-11, RN-03)
CREATE TABLE feedback_ia (
  id_feedback              uuid          NOT NULL,
  id_usuario               uuid          NOT NULL,
  tipo_periodo             text          NOT NULL,
  periodo_inicio           date          NOT NULL,
  periodo_fin              date          NOT NULL,
  mensaje                  text          NOT NULL,
  detecto_estancamiento    boolean       NOT NULL DEFAULT false,
  generado_en              timestamptz   NOT NULL DEFAULT now(),
  leido                    boolean       NOT NULL DEFAULT false,
  creado_en                timestamptz   NOT NULL DEFAULT now(),
  actualizado_en           timestamptz   NOT NULL DEFAULT now(),
  eliminado                boolean       NOT NULL DEFAULT false,
  pendiente_sync           boolean       NOT NULL DEFAULT false,
  CONSTRAINT pk_feedback_ia PRIMARY KEY (id_feedback),
  CONSTRAINT fk_feedback_ia_usuario FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT ck_feedback_ia_1 CHECK (periodo_fin >= periodo_inicio),
  CONSTRAINT ck_feedback_ia_tipo_periodo CHECK (tipo_periodo IN ('semanal', 'mensual'))
);

-- Compras Premium hechas en App Store o Google Play (en este proyecto, simuladas)
CREATE TABLE suscripcion (
  id_suscripcion           uuid          NOT NULL,
  id_usuario               uuid          NOT NULL,
  id_plan                  integer       NOT NULL,
  tienda                   text          NOT NULL,
  id_transaccion_original  text          NOT NULL,
  estado                   text          NOT NULL DEFAULT 'activa',
  fecha_inicio             timestamptz   NOT NULL,
  fecha_expiracion         timestamptz   NOT NULL,
  renovacion_automatica    boolean       NOT NULL DEFAULT true,
  creado_en                timestamptz   NOT NULL DEFAULT now(),
  actualizado_en           timestamptz   NOT NULL DEFAULT now(),
  eliminado                boolean       NOT NULL DEFAULT false,
  pendiente_sync           boolean       NOT NULL DEFAULT false,
  CONSTRAINT pk_suscripcion PRIMARY KEY (id_suscripcion),
  CONSTRAINT fk_suscripcion_usuario FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_suscripcion_plan FOREIGN KEY (id_plan) REFERENCES plan (id_plan) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT ck_suscripcion_1 CHECK (fecha_expiracion > fecha_inicio),
  CONSTRAINT ck_suscripcion_tienda CHECK (tienda IN ('app_store', 'google_play')),
  CONSTRAINT ck_suscripcion_estado CHECK (estado IN ('activa', 'en_gracia', 'cancelada', 'expirada'))
);
CREATE UNIQUE INDEX uk_suscripcion_id_transaccion_original ON suscripcion (id_transaccion_original) WHERE NOT eliminado;

-- Avisos (webhooks) de las tiendas sobre una suscripción
CREATE TABLE evento_pago (
  id_evento                uuid          NOT NULL,
  id_suscripcion           uuid          NOT NULL,
  tipo                     text          NOT NULL,
  id_notificacion_tienda   text          NOT NULL,
  recibido_en              timestamptz   NOT NULL DEFAULT now(),
  procesado                boolean       NOT NULL DEFAULT false,
  creado_en                timestamptz   NOT NULL DEFAULT now(),
  actualizado_en           timestamptz   NOT NULL DEFAULT now(),
  eliminado                boolean       NOT NULL DEFAULT false,
  pendiente_sync           boolean       NOT NULL DEFAULT false,
  CONSTRAINT pk_evento_pago PRIMARY KEY (id_evento),
  CONSTRAINT fk_evento_pago_suscripcion FOREIGN KEY (id_suscripcion) REFERENCES suscripcion (id_suscripcion) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT ck_evento_pago_tipo CHECK (tipo IN ('compra', 'renovacion', 'cancelacion', 'reembolso'))
);
CREATE UNIQUE INDEX uk_evento_pago_id_notificacion_tienda ON evento_pago (id_notificacion_tienda) WHERE NOT eliminado;


-- ---------------------------------------------------------------------
-- Índices para las políticas de seguridad (RLS revisa estas columnas en
-- cada consulta; sin índice serían lentas)
-- ---------------------------------------------------------------------
CREATE INDEX idx_medicion_biometrica_usuario ON medicion_biometrica (id_usuario);
CREATE INDEX idx_ciclo_rutina_usuario ON ciclo_rutina (id_usuario);
CREATE INDEX idx_dia_rutina_ciclo ON dia_rutina (id_ciclo);
CREATE INDEX idx_ejercicio_programado_dia ON ejercicio_programado (id_dia);
CREATE INDEX idx_alternativa_ejercicio_programado ON alternativa_ejercicio (id_programado);
CREATE INDEX idx_registro_ejercicio_sesion ON registro_ejercicio (id_sesion);
CREATE INDEX idx_serie_registro ON serie (id_registro);
CREATE INDEX idx_registro_comida_usuario ON registro_comida (id_usuario, fecha_hora);
CREATE INDEX idx_feedback_ia_usuario ON feedback_ia (id_usuario);
CREATE INDEX idx_suscripcion_usuario ON suscripcion (id_usuario);
CREATE INDEX idx_evento_pago_suscripcion ON evento_pago (id_suscripcion);


-- ---------------------------------------------------------------------
-- En la nube pendiente_sync siempre es false
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION nube_sin_pendientes()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  NEW.pendiente_sync := false;
  RETURN NEW;
END;
$$;

DO $$
DECLARE
  tabla text;
BEGIN
  FOREACH tabla IN ARRAY ARRAY[
    'usuario', 'perfil_entrenamiento', 'medicion_biometrica', 'usuario_equipo',
    'usuario_ejercicio', 'solicitud_ia', 'ciclo_rutina', 'dia_rutina',
    'ejercicio_programado', 'alternativa_ejercicio', 'sesion_entrenamiento',
    'registro_ejercicio', 'serie', 'registro_comida', 'feedback_ia',
    'suscripcion', 'evento_pago'
  ] LOOP
    EXECUTE format(
      'CREATE TRIGGER trg_%1$s_sin_pendientes BEFORE INSERT OR UPDATE ON %1$I '
      'FOR EACH ROW EXECUTE FUNCTION public.nube_sin_pendientes()', tabla);
  END LOOP;
END;
$$;
