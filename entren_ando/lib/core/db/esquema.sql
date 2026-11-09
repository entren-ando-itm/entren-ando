-- =====================================================================
-- Entren-Ando: esquema de la base local (SQLite cifrada con SQLCipher)
--
-- ES EL CONTRATO DE TODO EL EQUIPO. Mismos nombres de tablas y columnas
-- que el modelo entregado (docs/09_MySQL_creacion_tablas.sql).
-- Solo se cambia con acuerdo del equipo.
--
-- Reglas de conversión (ENT-1, sección 7):
--   * Tablas del usuario: id de texto con UUID generado en el celular, más
--     creado_en, actualizado_en, eliminado (0 o 1) y pendiente_sync (0 o 1).
--   * Catálogos plan, equipo y ejercicio: id entero fijo, igual en Supabase.
--     Son de solo lectura en la app.
--   * ENUM pasa a TEXT con CHECK; BOOLEAN a INTEGER (0 o 1); DECIMAL a REAL;
--     UNSIGNED a CHECK (columna >= 0).
--   * Nunca se borra con DELETE: se marca eliminado = 1. Por eso los UNIQUE
--     de las tablas del usuario son índices que solo cuentan eliminado = 0.
--     usuario_equipo y usuario_ejercicio conservan su llave compuesta: si
--     la relación ya existía, se reactiva (EscrituraLocal lo hace solo).
--   * Fechas: DATE como 'AAAA-MM-DD'; fecha y hora en ISO 8601 con la hora
--     de Ciudad de México, por ejemplo '2026-11-09T07:30:00-06:00';
--     TIME como 'HH:MM:SS'. Pesos en kilogramos.
--   * PRAGMA foreign_keys = ON lo activa base_datos.dart al abrir la base.
--
-- Este archivo se ejecuta sentencia por sentencia: no uses comentarios
-- de bloque ni punto y coma dentro de los comentarios.
-- =====================================================================


-- Catálogo de planes y sus límites freemium (RN-01 a RN-03)
CREATE TABLE plan (
  id_plan                  INTEGER NOT NULL,
  nombre                   TEXT    NOT NULL,
  max_ciclos_activos       INTEGER NULL,                -- NULL = ilimitado (RN-01)
  max_escaneos_dia         INTEGER NULL,                -- NULL = ilimitado (RN-02)
  frecuencia_feedback      TEXT    NOT NULL,            -- RN-03
  precio                   REAL    NULL,                -- MXN al mes
  CONSTRAINT pk_plan PRIMARY KEY (id_plan),
  CONSTRAINT uk_plan_nombre UNIQUE (nombre),
  CONSTRAINT ck_plan_frecuencia_feedback CHECK (frecuencia_feedback IN ('semanal', 'mensual')),
  CONSTRAINT ck_plan_max_ciclos_activos CHECK (max_ciclos_activos IS NULL OR max_ciclos_activos >= 0),
  CONSTRAINT ck_plan_max_escaneos_dia CHECK (max_escaneos_dia IS NULL OR max_escaneos_dia >= 0)
);

-- Cuenta del deportista; id_plan es el plan vigente
CREATE TABLE usuario (
  id_usuario               TEXT    NOT NULL,
  correo                   TEXT    NOT NULL,
  nombre                   TEXT    NOT NULL,
  fecha_nacimiento         TEXT    NULL,
  sexo                     TEXT    NULL,
  id_plan                  INTEGER NOT NULL DEFAULT 1,
  fecha_registro           TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now', '-6 hours') || '-06:00'),
  creado_en                TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now', '-6 hours') || '-06:00'),
  actualizado_en           TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now', '-6 hours') || '-06:00'),
  eliminado                INTEGER NOT NULL DEFAULT 0,
  pendiente_sync           INTEGER NOT NULL DEFAULT 1,
  CONSTRAINT pk_usuario PRIMARY KEY (id_usuario),
  CONSTRAINT fk_usuario_plan FOREIGN KEY (id_plan) REFERENCES plan (id_plan) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT ck_usuario_id CHECK (length(id_usuario) = 36),
  CONSTRAINT ck_usuario_sexo CHECK (sexo IS NULL OR sexo IN ('masculino', 'femenino', 'otro')),
  CONSTRAINT ck_usuario_eliminado CHECK (eliminado IN (0, 1)),
  CONSTRAINT ck_usuario_pendiente_sync CHECK (pendiente_sync IN (0, 1))
);
CREATE UNIQUE INDEX uk_usuario_correo ON usuario (correo) WHERE eliminado = 0;

-- Objetivos y nivel del usuario (RF-01); 1 a 1 con usuario
CREATE TABLE perfil_entrenamiento (
  id_perfil                TEXT    NOT NULL,
  id_usuario               TEXT    NOT NULL,
  objetivo                 TEXT    NOT NULL,
  nivel_experiencia        TEXT    NOT NULL,
  dias_por_semana          INTEGER NOT NULL,
  notas_lesiones           TEXT    NULL,
  creado_en                TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now', '-6 hours') || '-06:00'),
  actualizado_en           TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now', '-6 hours') || '-06:00'),
  eliminado                INTEGER NOT NULL DEFAULT 0,
  pendiente_sync           INTEGER NOT NULL DEFAULT 1,
  CONSTRAINT pk_perfil_entrenamiento PRIMARY KEY (id_perfil),
  CONSTRAINT fk_perfil_entrenamiento_usuario FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT ck_perfil_entrenamiento_1 CHECK (dias_por_semana BETWEEN 1 AND 7),
  CONSTRAINT ck_perfil_entrenamiento_id CHECK (length(id_perfil) = 36),
  CONSTRAINT ck_perfil_entrenamiento_objetivo CHECK (objetivo IN ('fuerza', 'hipertrofia', 'perdida_grasa', 'resistencia', 'salud')),
  CONSTRAINT ck_perfil_entrenamiento_nivel CHECK (nivel_experiencia IN ('principiante', 'intermedio', 'avanzado')),
  CONSTRAINT ck_perfil_entrenamiento_eliminado CHECK (eliminado IN (0, 1)),
  CONSTRAINT ck_perfil_entrenamiento_pendiente_sync CHECK (pendiente_sync IN (0, 1))
);
CREATE UNIQUE INDEX uk_perfil_entrenamiento_id_usuario ON perfil_entrenamiento (id_usuario) WHERE eliminado = 0;

-- Historial de medidas corporales (RF-01)
CREATE TABLE medicion_biometrica (
  id_medicion              TEXT    NOT NULL,
  id_usuario               TEXT    NOT NULL,
  fecha                    TEXT    NOT NULL,
  peso_kg                  REAL    NOT NULL,
  estatura_cm              REAL    NOT NULL,
  porcentaje_grasa         REAL    NULL,
  creado_en                TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now', '-6 hours') || '-06:00'),
  actualizado_en           TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now', '-6 hours') || '-06:00'),
  eliminado                INTEGER NOT NULL DEFAULT 0,
  pendiente_sync           INTEGER NOT NULL DEFAULT 1,
  CONSTRAINT pk_medicion_biometrica PRIMARY KEY (id_medicion),
  CONSTRAINT fk_medicion_biometrica_usuario FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT ck_medicion_biometrica_1 CHECK (peso_kg > 0),
  CONSTRAINT ck_medicion_biometrica_2 CHECK (estatura_cm > 0),
  CONSTRAINT ck_medicion_biometrica_id CHECK (length(id_medicion) = 36),
  CONSTRAINT ck_medicion_biometrica_eliminado CHECK (eliminado IN (0, 1)),
  CONSTRAINT ck_medicion_biometrica_pendiente_sync CHECK (pendiente_sync IN (0, 1))
);

-- Catálogo de equipo de gimnasio
CREATE TABLE equipo (
  id_equipo                INTEGER NOT NULL,
  nombre                   TEXT    NOT NULL,
  categoria                TEXT    NULL,
  CONSTRAINT pk_equipo PRIMARY KEY (id_equipo),
  CONSTRAINT uk_equipo_nombre UNIQUE (nombre)
);

-- Equipo que tiene disponible cada usuario (N:M)
CREATE TABLE usuario_equipo (
  id_usuario               TEXT    NOT NULL,
  id_equipo                INTEGER NOT NULL,
  creado_en                TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now', '-6 hours') || '-06:00'),
  actualizado_en           TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now', '-6 hours') || '-06:00'),
  eliminado                INTEGER NOT NULL DEFAULT 0,
  pendiente_sync           INTEGER NOT NULL DEFAULT 1,
  CONSTRAINT pk_usuario_equipo PRIMARY KEY (id_usuario, id_equipo),
  CONSTRAINT fk_usuario_equipo_usuario FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_usuario_equipo_equipo FOREIGN KEY (id_equipo) REFERENCES equipo (id_equipo) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT ck_usuario_equipo_eliminado CHECK (eliminado IN (0, 1)),
  CONSTRAINT ck_usuario_equipo_pendiente_sync CHECK (pendiente_sync IN (0, 1))
);

-- Catálogo global; la IA usa siempre id_ejercicio (RF-05)
CREATE TABLE ejercicio (
  id_ejercicio             INTEGER NOT NULL,
  nombre_oficial           TEXT    NOT NULL,
  grupo_muscular           TEXT    NOT NULL,
  tipo_movimiento          TEXT    NOT NULL,
  id_equipo                INTEGER NULL,                -- NULL = peso corporal
  descripcion_tecnica      TEXT    NULL,
  CONSTRAINT pk_ejercicio PRIMARY KEY (id_ejercicio),
  CONSTRAINT uk_ejercicio_nombre_oficial UNIQUE (nombre_oficial),
  CONSTRAINT fk_ejercicio_equipo FOREIGN KEY (id_equipo) REFERENCES equipo (id_equipo) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT ck_ejercicio_tipo_movimiento CHECK (tipo_movimiento IN ('compuesto', 'aislamiento'))
);

-- Alias personalizado de un ejercicio por usuario (RF-05)
CREATE TABLE usuario_ejercicio (
  id_usuario               TEXT    NOT NULL,
  id_ejercicio             INTEGER NOT NULL,
  nombre_alias             TEXT    NOT NULL,
  creado_en                TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now', '-6 hours') || '-06:00'),
  actualizado_en           TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now', '-6 hours') || '-06:00'),
  eliminado                INTEGER NOT NULL DEFAULT 0,
  pendiente_sync           INTEGER NOT NULL DEFAULT 1,
  CONSTRAINT pk_usuario_ejercicio PRIMARY KEY (id_usuario, id_ejercicio),
  CONSTRAINT fk_usuario_ejercicio_usuario FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_usuario_ejercicio_ejercicio FOREIGN KEY (id_ejercicio) REFERENCES ejercicio (id_ejercicio) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT ck_usuario_ejercicio_eliminado CHECK (eliminado IN (0, 1)),
  CONSTRAINT ck_usuario_ejercicio_pendiente_sync CHECK (pendiente_sync IN (0, 1))
);

-- Peticiones a la IA; sirve para contar los escaneos del día (RN-02)
CREATE TABLE solicitud_ia (
  id_solicitud             TEXT    NOT NULL,
  id_usuario               TEXT    NOT NULL,
  tipo                     TEXT    NOT NULL,
  fecha_hora               TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now', '-6 hours') || '-06:00'),
  estado                   TEXT    NOT NULL DEFAULT 'pendiente',
  creado_en                TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now', '-6 hours') || '-06:00'),
  actualizado_en           TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now', '-6 hours') || '-06:00'),
  eliminado                INTEGER NOT NULL DEFAULT 0,
  pendiente_sync           INTEGER NOT NULL DEFAULT 1,
  CONSTRAINT pk_solicitud_ia PRIMARY KEY (id_solicitud),
  CONSTRAINT fk_solicitud_ia_usuario FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT ck_solicitud_ia_id CHECK (length(id_solicitud) = 36),
  CONSTRAINT ck_solicitud_ia_tipo CHECK (tipo IN ('rutina', 'escaneo', 'feedback')),
  CONSTRAINT ck_solicitud_ia_estado CHECK (estado IN ('pendiente', 'completada', 'fallida')),
  CONSTRAINT ck_solicitud_ia_eliminado CHECK (eliminado IN (0, 1)),
  CONSTRAINT ck_solicitud_ia_pendiente_sync CHECK (pendiente_sync IN (0, 1))
);
CREATE INDEX idx_solicitud_cuota ON solicitud_ia (id_usuario, tipo, fecha_hora);

-- Rutina por ciclos o semestres (RF-02); plan gratuito: 1 activo (RN-01)
CREATE TABLE ciclo_rutina (
  id_ciclo                 TEXT    NOT NULL,
  id_usuario               TEXT    NOT NULL,
  id_solicitud             TEXT    NULL,                -- Solicitud de IA que la originó
  nombre                   TEXT    NOT NULL,
  fecha_inicio             TEXT    NOT NULL,
  fecha_fin                TEXT    NULL,
  estado                   TEXT    NOT NULL DEFAULT 'activo',
  origen                   TEXT    NOT NULL,
  creado_en                TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now', '-6 hours') || '-06:00'),
  actualizado_en           TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now', '-6 hours') || '-06:00'),
  eliminado                INTEGER NOT NULL DEFAULT 0,
  pendiente_sync           INTEGER NOT NULL DEFAULT 1,
  CONSTRAINT pk_ciclo_rutina PRIMARY KEY (id_ciclo),
  CONSTRAINT fk_ciclo_rutina_usuario FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_ciclo_rutina_solicitud FOREIGN KEY (id_solicitud) REFERENCES solicitud_ia (id_solicitud) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT ck_ciclo_rutina_1 CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio),
  CONSTRAINT ck_ciclo_rutina_id CHECK (length(id_ciclo) = 36),
  CONSTRAINT ck_ciclo_rutina_estado CHECK (estado IN ('activo', 'archivado')),
  CONSTRAINT ck_ciclo_rutina_origen CHECK (origen IN ('ia', 'manual')),
  CONSTRAINT ck_ciclo_rutina_eliminado CHECK (eliminado IN (0, 1)),
  CONSTRAINT ck_ciclo_rutina_pendiente_sync CHECK (pendiente_sync IN (0, 1))
);
CREATE UNIQUE INDEX uk_ciclo_rutina_id_solicitud ON ciclo_rutina (id_solicitud) WHERE eliminado = 0;

-- Día de la plantilla tipo horario escolar
CREATE TABLE dia_rutina (
  id_dia                   TEXT    NOT NULL,
  id_ciclo                 TEXT    NOT NULL,
  dia_semana               INTEGER NOT NULL,            -- 1 = lunes ... 7 = domingo
  nombre                   TEXT    NOT NULL,
  es_descanso              INTEGER NOT NULL DEFAULT 0,
  creado_en                TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now', '-6 hours') || '-06:00'),
  actualizado_en           TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now', '-6 hours') || '-06:00'),
  eliminado                INTEGER NOT NULL DEFAULT 0,
  pendiente_sync           INTEGER NOT NULL DEFAULT 1,
  CONSTRAINT pk_dia_rutina PRIMARY KEY (id_dia),
  CONSTRAINT fk_dia_rutina_ciclo FOREIGN KEY (id_ciclo) REFERENCES ciclo_rutina (id_ciclo) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT ck_dia_rutina_1 CHECK (dia_semana BETWEEN 1 AND 7),
  CONSTRAINT ck_dia_rutina_id CHECK (length(id_dia) = 36),
  CONSTRAINT ck_dia_rutina_es_descanso CHECK (es_descanso IN (0, 1)),
  CONSTRAINT ck_dia_rutina_eliminado CHECK (eliminado IN (0, 1)),
  CONSTRAINT ck_dia_rutina_pendiente_sync CHECK (pendiente_sync IN (0, 1))
);
CREATE UNIQUE INDEX uk_dia_rutina_id_ciclo_dia_semana ON dia_rutina (id_ciclo, dia_semana) WHERE eliminado = 0;

-- Ejercicio planeado dentro de un día de la rutina
CREATE TABLE ejercicio_programado (
  id_programado            TEXT    NOT NULL,
  id_dia                   TEXT    NOT NULL,
  id_ejercicio             INTEGER NOT NULL,
  orden                    INTEGER NOT NULL,
  series_objetivo          INTEGER NOT NULL,
  reps_objetivo            INTEGER NOT NULL,
  peso_objetivo_kg         REAL    NULL,
  descanso_seg             INTEGER NOT NULL DEFAULT 90,
  trabajo_seg              INTEGER NULL,
  creado_en                TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now', '-6 hours') || '-06:00'),
  actualizado_en           TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now', '-6 hours') || '-06:00'),
  eliminado                INTEGER NOT NULL DEFAULT 0,
  pendiente_sync           INTEGER NOT NULL DEFAULT 1,
  CONSTRAINT pk_ejercicio_programado PRIMARY KEY (id_programado),
  CONSTRAINT fk_ejercicio_programado_dia FOREIGN KEY (id_dia) REFERENCES dia_rutina (id_dia) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_ejercicio_programado_ejercicio FOREIGN KEY (id_ejercicio) REFERENCES ejercicio (id_ejercicio) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT ck_ejercicio_programado_id CHECK (length(id_programado) = 36),
  CONSTRAINT ck_ejercicio_programado_orden CHECK (orden >= 0),
  CONSTRAINT ck_ejercicio_programado_series CHECK (series_objetivo >= 0),
  CONSTRAINT ck_ejercicio_programado_reps CHECK (reps_objetivo >= 0),
  CONSTRAINT ck_ejercicio_programado_descanso CHECK (descanso_seg >= 0),
  CONSTRAINT ck_ejercicio_programado_trabajo CHECK (trabajo_seg IS NULL OR trabajo_seg >= 0),
  CONSTRAINT ck_ejercicio_programado_eliminado CHECK (eliminado IN (0, 1)),
  CONSTRAINT ck_ejercicio_programado_pendiente_sync CHECK (pendiente_sync IN (0, 1))
);

-- Alternativas preconfiguradas para sustituir un ejercicio (RF-04)
CREATE TABLE alternativa_ejercicio (
  id_alternativa           TEXT    NOT NULL,
  id_programado            TEXT    NOT NULL,
  id_ejercicio             INTEGER NOT NULL,
  prioridad                INTEGER NOT NULL DEFAULT 1,
  creado_en                TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now', '-6 hours') || '-06:00'),
  actualizado_en           TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now', '-6 hours') || '-06:00'),
  eliminado                INTEGER NOT NULL DEFAULT 0,
  pendiente_sync           INTEGER NOT NULL DEFAULT 1,
  CONSTRAINT pk_alternativa_ejercicio PRIMARY KEY (id_alternativa),
  CONSTRAINT fk_alternativa_ejercicio_programado FOREIGN KEY (id_programado) REFERENCES ejercicio_programado (id_programado) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_alternativa_ejercicio_ejercicio FOREIGN KEY (id_ejercicio) REFERENCES ejercicio (id_ejercicio) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT ck_alternativa_ejercicio_id CHECK (length(id_alternativa) = 36),
  CONSTRAINT ck_alternativa_ejercicio_prioridad CHECK (prioridad >= 0),
  CONSTRAINT ck_alternativa_ejercicio_eliminado CHECK (eliminado IN (0, 1)),
  CONSTRAINT ck_alternativa_ejercicio_pendiente_sync CHECK (pendiente_sync IN (0, 1))
);

-- Entrenamiento de un día; su estado colorea el calendario (RF-08 a RF-10)
CREATE TABLE sesion_entrenamiento (
  id_sesion                TEXT    NOT NULL,
  id_usuario               TEXT    NOT NULL,
  id_dia                   TEXT    NULL,
  fecha                    TEXT    NOT NULL,
  estado                   TEXT    NOT NULL,
  es_override              INTEGER NOT NULL DEFAULT 0,  -- RF-09
  comentario               TEXT    NULL,
  hora_inicio              TEXT    NULL,
  hora_fin                 TEXT    NULL,
  creado_en                TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now', '-6 hours') || '-06:00'),
  actualizado_en           TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now', '-6 hours') || '-06:00'),
  eliminado                INTEGER NOT NULL DEFAULT 0,
  pendiente_sync           INTEGER NOT NULL DEFAULT 1,
  CONSTRAINT pk_sesion_entrenamiento PRIMARY KEY (id_sesion),
  CONSTRAINT fk_sesion_entrenamiento_usuario FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_sesion_entrenamiento_dia FOREIGN KEY (id_dia) REFERENCES dia_rutina (id_dia) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT ck_sesion_entrenamiento_id CHECK (length(id_sesion) = 36),
  CONSTRAINT ck_sesion_entrenamiento_estado CHECK (estado IN ('completa', 'parcial', 'descanso')),
  CONSTRAINT ck_sesion_entrenamiento_es_override CHECK (es_override IN (0, 1)),
  CONSTRAINT ck_sesion_entrenamiento_eliminado CHECK (eliminado IN (0, 1)),
  CONSTRAINT ck_sesion_entrenamiento_pendiente_sync CHECK (pendiente_sync IN (0, 1))
);
CREATE INDEX idx_sesion_calendario ON sesion_entrenamiento (id_usuario, fecha);

-- Ejercicio realmente ejecutado en una sesión (RF-03, RF-04)
CREATE TABLE registro_ejercicio (
  id_registro              TEXT    NOT NULL,
  id_sesion                TEXT    NOT NULL,
  id_programado            TEXT    NULL,
  id_ejercicio             INTEGER NOT NULL,
  es_sustitucion           INTEGER NOT NULL DEFAULT 0,
  orden                    INTEGER NOT NULL,
  completado               INTEGER NOT NULL DEFAULT 0,
  creado_en                TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now', '-6 hours') || '-06:00'),
  actualizado_en           TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now', '-6 hours') || '-06:00'),
  eliminado                INTEGER NOT NULL DEFAULT 0,
  pendiente_sync           INTEGER NOT NULL DEFAULT 1,
  CONSTRAINT pk_registro_ejercicio PRIMARY KEY (id_registro),
  CONSTRAINT fk_registro_ejercicio_sesion FOREIGN KEY (id_sesion) REFERENCES sesion_entrenamiento (id_sesion) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_registro_ejercicio_programado FOREIGN KEY (id_programado) REFERENCES ejercicio_programado (id_programado) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_registro_ejercicio_ejercicio FOREIGN KEY (id_ejercicio) REFERENCES ejercicio (id_ejercicio) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT ck_registro_ejercicio_id CHECK (length(id_registro) = 36),
  CONSTRAINT ck_registro_ejercicio_es_sustitucion CHECK (es_sustitucion IN (0, 1)),
  CONSTRAINT ck_registro_ejercicio_orden CHECK (orden >= 0),
  CONSTRAINT ck_registro_ejercicio_completado CHECK (completado IN (0, 1)),
  CONSTRAINT ck_registro_ejercicio_eliminado CHECK (eliminado IN (0, 1)),
  CONSTRAINT ck_registro_ejercicio_pendiente_sync CHECK (pendiente_sync IN (0, 1))
);

-- Cada serie marcada en la bitácora (RF-03)
CREATE TABLE serie (
  id_serie                 TEXT    NOT NULL,
  id_registro              TEXT    NOT NULL,
  numero_serie             INTEGER NOT NULL,
  peso_kg                  REAL    NOT NULL,
  repeticiones             INTEGER NOT NULL,
  completada_en            TEXT    NULL,
  creado_en                TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now', '-6 hours') || '-06:00'),
  actualizado_en           TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now', '-6 hours') || '-06:00'),
  eliminado                INTEGER NOT NULL DEFAULT 0,
  pendiente_sync           INTEGER NOT NULL DEFAULT 1,
  CONSTRAINT pk_serie PRIMARY KEY (id_serie),
  CONSTRAINT fk_serie_registro FOREIGN KEY (id_registro) REFERENCES registro_ejercicio (id_registro) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT ck_serie_1 CHECK (peso_kg >= 0),
  CONSTRAINT ck_serie_id CHECK (length(id_serie) = 36),
  CONSTRAINT ck_serie_numero_serie CHECK (numero_serie >= 0),
  CONSTRAINT ck_serie_repeticiones CHECK (repeticiones >= 0),
  CONSTRAINT ck_serie_eliminado CHECK (eliminado IN (0, 1)),
  CONSTRAINT ck_serie_pendiente_sync CHECK (pendiente_sync IN (0, 1))
);
CREATE UNIQUE INDEX uk_serie_id_registro_numero_serie ON serie (id_registro, numero_serie) WHERE eliminado = 0;

-- Registro nutricional manual o por foto con IA (RF-07)
CREATE TABLE registro_comida (
  id_comida                TEXT    NOT NULL,
  id_usuario               TEXT    NOT NULL,
  id_solicitud             TEXT    NULL,                -- Escaneo de IA que la originó
  fecha_hora               TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now', '-6 hours') || '-06:00'),
  descripcion              TEXT    NOT NULL,
  calorias                 INTEGER NOT NULL,
  proteinas_g              REAL    NULL,
  carbohidratos_g          REAL    NULL,
  grasas_g                 REAL    NULL,
  origen                   TEXT    NOT NULL DEFAULT 'manual',
  creado_en                TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now', '-6 hours') || '-06:00'),
  actualizado_en           TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now', '-6 hours') || '-06:00'),
  eliminado                INTEGER NOT NULL DEFAULT 0,
  pendiente_sync           INTEGER NOT NULL DEFAULT 1,
  CONSTRAINT pk_registro_comida PRIMARY KEY (id_comida),
  CONSTRAINT fk_registro_comida_usuario FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_registro_comida_solicitud FOREIGN KEY (id_solicitud) REFERENCES solicitud_ia (id_solicitud) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT ck_registro_comida_id CHECK (length(id_comida) = 36),
  CONSTRAINT ck_registro_comida_calorias CHECK (calorias >= 0),
  CONSTRAINT ck_registro_comida_origen CHECK (origen IN ('manual', 'ia')),
  CONSTRAINT ck_registro_comida_eliminado CHECK (eliminado IN (0, 1)),
  CONSTRAINT ck_registro_comida_pendiente_sync CHECK (pendiente_sync IN (0, 1))
);
CREATE UNIQUE INDEX uk_registro_comida_id_solicitud ON registro_comida (id_solicitud) WHERE eliminado = 0;

-- Mensaje periódico de la IA; analiza sesiones y comidas del periodo (RF-11, RN-03)
CREATE TABLE feedback_ia (
  id_feedback              TEXT    NOT NULL,
  id_usuario               TEXT    NOT NULL,
  tipo_periodo             TEXT    NOT NULL,
  periodo_inicio           TEXT    NOT NULL,
  periodo_fin              TEXT    NOT NULL,
  mensaje                  TEXT    NOT NULL,
  detecto_estancamiento    INTEGER NOT NULL DEFAULT 0,
  generado_en              TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now', '-6 hours') || '-06:00'),
  leido                    INTEGER NOT NULL DEFAULT 0,
  creado_en                TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now', '-6 hours') || '-06:00'),
  actualizado_en           TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now', '-6 hours') || '-06:00'),
  eliminado                INTEGER NOT NULL DEFAULT 0,
  pendiente_sync           INTEGER NOT NULL DEFAULT 1,
  CONSTRAINT pk_feedback_ia PRIMARY KEY (id_feedback),
  CONSTRAINT fk_feedback_ia_usuario FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT ck_feedback_ia_1 CHECK (periodo_fin >= periodo_inicio),
  CONSTRAINT ck_feedback_ia_id CHECK (length(id_feedback) = 36),
  CONSTRAINT ck_feedback_ia_tipo_periodo CHECK (tipo_periodo IN ('semanal', 'mensual')),
  CONSTRAINT ck_feedback_ia_detecto_estancamiento CHECK (detecto_estancamiento IN (0, 1)),
  CONSTRAINT ck_feedback_ia_leido CHECK (leido IN (0, 1)),
  CONSTRAINT ck_feedback_ia_eliminado CHECK (eliminado IN (0, 1)),
  CONSTRAINT ck_feedback_ia_pendiente_sync CHECK (pendiente_sync IN (0, 1))
);

-- Compras Premium hechas en App Store o Google Play (en este proyecto, simuladas)
CREATE TABLE suscripcion (
  id_suscripcion           TEXT    NOT NULL,
  id_usuario               TEXT    NOT NULL,
  id_plan                  INTEGER NOT NULL,
  tienda                   TEXT    NOT NULL,
  id_transaccion_original  TEXT    NOT NULL,
  estado                   TEXT    NOT NULL DEFAULT 'activa',
  fecha_inicio             TEXT    NOT NULL,
  fecha_expiracion         TEXT    NOT NULL,
  renovacion_automatica    INTEGER NOT NULL DEFAULT 1,
  creado_en                TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now', '-6 hours') || '-06:00'),
  actualizado_en           TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now', '-6 hours') || '-06:00'),
  eliminado                INTEGER NOT NULL DEFAULT 0,
  pendiente_sync           INTEGER NOT NULL DEFAULT 1,
  CONSTRAINT pk_suscripcion PRIMARY KEY (id_suscripcion),
  CONSTRAINT fk_suscripcion_usuario FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_suscripcion_plan FOREIGN KEY (id_plan) REFERENCES plan (id_plan) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT ck_suscripcion_1 CHECK (fecha_expiracion > fecha_inicio),
  CONSTRAINT ck_suscripcion_id CHECK (length(id_suscripcion) = 36),
  CONSTRAINT ck_suscripcion_tienda CHECK (tienda IN ('app_store', 'google_play')),
  CONSTRAINT ck_suscripcion_estado CHECK (estado IN ('activa', 'en_gracia', 'cancelada', 'expirada')),
  CONSTRAINT ck_suscripcion_renovacion CHECK (renovacion_automatica IN (0, 1)),
  CONSTRAINT ck_suscripcion_eliminado CHECK (eliminado IN (0, 1)),
  CONSTRAINT ck_suscripcion_pendiente_sync CHECK (pendiente_sync IN (0, 1))
);
CREATE UNIQUE INDEX uk_suscripcion_id_transaccion_original ON suscripcion (id_transaccion_original) WHERE eliminado = 0;

-- Avisos (webhooks) de las tiendas sobre una suscripción
CREATE TABLE evento_pago (
  id_evento                TEXT    NOT NULL,
  id_suscripcion           TEXT    NOT NULL,
  tipo                     TEXT    NOT NULL,
  id_notificacion_tienda   TEXT    NOT NULL,
  recibido_en              TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now', '-6 hours') || '-06:00'),
  procesado                INTEGER NOT NULL DEFAULT 0,
  creado_en                TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now', '-6 hours') || '-06:00'),
  actualizado_en           TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now', '-6 hours') || '-06:00'),
  eliminado                INTEGER NOT NULL DEFAULT 0,
  pendiente_sync           INTEGER NOT NULL DEFAULT 1,
  CONSTRAINT pk_evento_pago PRIMARY KEY (id_evento),
  CONSTRAINT fk_evento_pago_suscripcion FOREIGN KEY (id_suscripcion) REFERENCES suscripcion (id_suscripcion) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT ck_evento_pago_id CHECK (length(id_evento) = 36),
  CONSTRAINT ck_evento_pago_tipo CHECK (tipo IN ('compra', 'renovacion', 'cancelacion', 'reembolso')),
  CONSTRAINT ck_evento_pago_procesado CHECK (procesado IN (0, 1)),
  CONSTRAINT ck_evento_pago_eliminado CHECK (eliminado IN (0, 1)),
  CONSTRAINT ck_evento_pago_pendiente_sync CHECK (pendiente_sync IN (0, 1))
);
CREATE UNIQUE INDEX uk_evento_pago_id_notificacion_tienda ON evento_pago (id_notificacion_tienda) WHERE eliminado = 0;
