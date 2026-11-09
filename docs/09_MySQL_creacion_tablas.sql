-- =====================================================================
-- Entren-Ando · Nivel 2: Modelo lógico relacional (MySQL 8.0 o superior)
-- 20 tablas con llaves primarias (PK), foráneas (FK) y únicas (UK).
-- Para ver el diagrama: MySQL Workbench > Database > Reverse Engineer.
-- Los tipos de dato son simples para poder crear las tablas; el modelo
-- físico definitivo (UUID, campos de sincronización) va en el Nivel 3.
-- =====================================================================

DROP DATABASE IF EXISTS entren_ando;   -- Borra la base anterior si existe (solo para pruebas)
CREATE DATABASE entren_ando CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE entren_ando;

-- Catálogo de planes y sus límites freemium (RN-01 a RN-03)
CREATE TABLE plan (
  id_plan                  INT UNSIGNED NOT NULL AUTO_INCREMENT,
  nombre                   VARCHAR(30) NOT NULL,
  max_ciclos_activos       TINYINT UNSIGNED NULL COMMENT 'NULL = ilimitado (RN-01)',
  max_escaneos_dia         TINYINT UNSIGNED NULL COMMENT 'NULL = ilimitado (RN-02)',
  frecuencia_feedback      ENUM('semanal','mensual') NOT NULL COMMENT 'RN-03',
  precio                   DECIMAL(8,2) NULL,
  CONSTRAINT pk_plan PRIMARY KEY (id_plan),
  CONSTRAINT uk_plan_nombre UNIQUE (nombre)
) ENGINE = InnoDB COMMENT = 'Catálogo de planes y sus límites freemium (RN-01 a RN-03)';

-- Cuenta del deportista; id_plan es el plan vigente
CREATE TABLE usuario (
  id_usuario               INT UNSIGNED NOT NULL AUTO_INCREMENT,
  correo                   VARCHAR(255) NOT NULL,
  nombre                   VARCHAR(100) NOT NULL,
  fecha_nacimiento         DATE NULL,
  sexo                     ENUM('masculino','femenino','otro') NULL,
  id_plan                  INT UNSIGNED NOT NULL DEFAULT 1,
  fecha_registro           DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT pk_usuario PRIMARY KEY (id_usuario),
  CONSTRAINT uk_usuario_correo UNIQUE (correo),
  CONSTRAINT fk_usuario_plan FOREIGN KEY (id_plan) REFERENCES plan (id_plan) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE = InnoDB COMMENT = 'Cuenta del deportista; id_plan es el plan vigente';

-- Objetivos y nivel del usuario (RF-01); 1 a 1 con usuario
CREATE TABLE perfil_entrenamiento (
  id_perfil                INT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_usuario               INT UNSIGNED NOT NULL,
  objetivo                 ENUM('fuerza','hipertrofia','perdida_grasa','resistencia','salud') NOT NULL,
  nivel_experiencia        ENUM('principiante','intermedio','avanzado') NOT NULL,
  dias_por_semana          TINYINT UNSIGNED NOT NULL,
  notas_lesiones           TEXT NULL,
  CONSTRAINT pk_perfil_entrenamiento PRIMARY KEY (id_perfil),
  CONSTRAINT uk_perfil_entrenamiento_id_usuario UNIQUE (id_usuario),
  CONSTRAINT fk_perfil_entrenamiento_usuario FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT ck_perfil_entrenamiento_1 CHECK (dias_por_semana BETWEEN 1 AND 7)
) ENGINE = InnoDB COMMENT = 'Objetivos y nivel del usuario (RF-01); 1 a 1 con usuario';

-- Historial de medidas corporales (RF-01)
CREATE TABLE medicion_biometrica (
  id_medicion              INT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_usuario               INT UNSIGNED NOT NULL,
  fecha                    DATE NOT NULL,
  peso_kg                  DECIMAL(5,2) NOT NULL,
  estatura_cm              DECIMAL(5,1) NOT NULL,
  porcentaje_grasa         DECIMAL(4,1) NULL,
  CONSTRAINT pk_medicion_biometrica PRIMARY KEY (id_medicion),
  CONSTRAINT fk_medicion_biometrica_usuario FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT ck_medicion_biometrica_1 CHECK (peso_kg > 0),
  CONSTRAINT ck_medicion_biometrica_2 CHECK (estatura_cm > 0)
) ENGINE = InnoDB COMMENT = 'Historial de medidas corporales (RF-01)';

-- Catálogo de equipo de gimnasio
CREATE TABLE equipo (
  id_equipo                INT UNSIGNED NOT NULL AUTO_INCREMENT,
  nombre                   VARCHAR(80) NOT NULL,
  categoria                VARCHAR(50) NULL,
  CONSTRAINT pk_equipo PRIMARY KEY (id_equipo),
  CONSTRAINT uk_equipo_nombre UNIQUE (nombre)
) ENGINE = InnoDB COMMENT = 'Catálogo de equipo de gimnasio';

-- Equipo que tiene disponible cada usuario (N:M)
CREATE TABLE usuario_equipo (
  id_usuario               INT UNSIGNED NOT NULL,
  id_equipo                INT UNSIGNED NOT NULL,
  CONSTRAINT pk_usuario_equipo PRIMARY KEY (id_usuario, id_equipo),
  CONSTRAINT fk_usuario_equipo_usuario FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_usuario_equipo_equipo FOREIGN KEY (id_equipo) REFERENCES equipo (id_equipo) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE = InnoDB COMMENT = 'Equipo que tiene disponible cada usuario (N:M)';

-- Catálogo global; la IA usa siempre id_ejercicio (RF-05)
CREATE TABLE ejercicio (
  id_ejercicio             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  nombre_oficial           VARCHAR(120) NOT NULL,
  grupo_muscular           VARCHAR(50) NOT NULL,
  tipo_movimiento          ENUM('compuesto','aislamiento') NOT NULL,
  id_equipo                INT UNSIGNED NULL,
  descripcion_tecnica      TEXT NULL,
  CONSTRAINT pk_ejercicio PRIMARY KEY (id_ejercicio),
  CONSTRAINT uk_ejercicio_nombre_oficial UNIQUE (nombre_oficial),
  CONSTRAINT fk_ejercicio_equipo FOREIGN KEY (id_equipo) REFERENCES equipo (id_equipo) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE = InnoDB COMMENT = 'Catálogo global; la IA usa siempre id_ejercicio (RF-05)';

-- Alias personalizado de un ejercicio por usuario (RF-05)
CREATE TABLE usuario_ejercicio (
  id_usuario               INT UNSIGNED NOT NULL,
  id_ejercicio             INT UNSIGNED NOT NULL,
  nombre_alias             VARCHAR(100) NOT NULL,
  CONSTRAINT pk_usuario_ejercicio PRIMARY KEY (id_usuario, id_ejercicio),
  CONSTRAINT fk_usuario_ejercicio_usuario FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_usuario_ejercicio_ejercicio FOREIGN KEY (id_ejercicio) REFERENCES ejercicio (id_ejercicio) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE = InnoDB COMMENT = 'Alias personalizado de un ejercicio por usuario (RF-05)';

-- Peticiones a la IA; sirve para contar los escaneos del día (RN-02)
CREATE TABLE solicitud_ia (
  id_solicitud             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_usuario               INT UNSIGNED NOT NULL,
  tipo                     ENUM('rutina','escaneo','feedback') NOT NULL,
  fecha_hora               DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  estado                   ENUM('pendiente','completada','fallida') NOT NULL DEFAULT 'pendiente',
  CONSTRAINT pk_solicitud_ia PRIMARY KEY (id_solicitud),
  CONSTRAINT fk_solicitud_ia_usuario FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE CASCADE ON UPDATE CASCADE,
  INDEX idx_solicitud_cuota (id_usuario, tipo, fecha_hora)
) ENGINE = InnoDB COMMENT = 'Peticiones a la IA; sirve para contar los escaneos del día (RN-02)';

-- Rutina por ciclos o semestres (RF-02); plan gratuito: 1 activo (RN-01)
CREATE TABLE ciclo_rutina (
  id_ciclo                 INT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_usuario               INT UNSIGNED NOT NULL,
  id_solicitud             INT UNSIGNED NULL COMMENT 'Solicitud de IA que la originó',
  nombre                   VARCHAR(100) NOT NULL,
  fecha_inicio             DATE NOT NULL,
  fecha_fin                DATE NULL,
  estado                   ENUM('activo','archivado') NOT NULL DEFAULT 'activo',
  origen                   ENUM('ia','manual') NOT NULL,
  CONSTRAINT pk_ciclo_rutina PRIMARY KEY (id_ciclo),
  CONSTRAINT uk_ciclo_rutina_id_solicitud UNIQUE (id_solicitud),
  CONSTRAINT fk_ciclo_rutina_usuario FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_ciclo_rutina_solicitud FOREIGN KEY (id_solicitud) REFERENCES solicitud_ia (id_solicitud) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT ck_ciclo_rutina_1 CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio)
) ENGINE = InnoDB COMMENT = 'Rutina por ciclos o semestres (RF-02); plan gratuito: 1 activo (RN-01)';

-- Día de la plantilla tipo horario escolar
CREATE TABLE dia_rutina (
  id_dia                   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_ciclo                 INT UNSIGNED NOT NULL,
  dia_semana               TINYINT UNSIGNED NOT NULL COMMENT '1 = lunes ... 7 = domingo',
  nombre                   VARCHAR(60) NOT NULL,
  es_descanso              BOOLEAN NOT NULL DEFAULT FALSE,
  CONSTRAINT pk_dia_rutina PRIMARY KEY (id_dia),
  CONSTRAINT uk_dia_rutina_id_ciclo_dia_semana UNIQUE (id_ciclo, dia_semana),
  CONSTRAINT fk_dia_rutina_ciclo FOREIGN KEY (id_ciclo) REFERENCES ciclo_rutina (id_ciclo) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT ck_dia_rutina_1 CHECK (dia_semana BETWEEN 1 AND 7)
) ENGINE = InnoDB COMMENT = 'Día de la plantilla tipo horario escolar';

-- Ejercicio planeado dentro de un día de la rutina
CREATE TABLE ejercicio_programado (
  id_programado            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_dia                   INT UNSIGNED NOT NULL,
  id_ejercicio             INT UNSIGNED NOT NULL,
  orden                    TINYINT UNSIGNED NOT NULL,
  series_objetivo          TINYINT UNSIGNED NOT NULL,
  reps_objetivo            TINYINT UNSIGNED NOT NULL,
  peso_objetivo_kg         DECIMAL(6,2) NULL,
  descanso_seg             SMALLINT UNSIGNED NOT NULL DEFAULT 90,
  trabajo_seg              SMALLINT UNSIGNED NULL,
  CONSTRAINT pk_ejercicio_programado PRIMARY KEY (id_programado),
  CONSTRAINT fk_ejercicio_programado_dia FOREIGN KEY (id_dia) REFERENCES dia_rutina (id_dia) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_ejercicio_programado_ejercicio FOREIGN KEY (id_ejercicio) REFERENCES ejercicio (id_ejercicio) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE = InnoDB COMMENT = 'Ejercicio planeado dentro de un día de la rutina';

-- Alternativas preconfiguradas para sustituir un ejercicio (RF-04)
CREATE TABLE alternativa_ejercicio (
  id_alternativa           INT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_programado            INT UNSIGNED NOT NULL,
  id_ejercicio             INT UNSIGNED NOT NULL,
  prioridad                TINYINT UNSIGNED NOT NULL DEFAULT 1,
  CONSTRAINT pk_alternativa_ejercicio PRIMARY KEY (id_alternativa),
  CONSTRAINT fk_alternativa_ejercicio_programado FOREIGN KEY (id_programado) REFERENCES ejercicio_programado (id_programado) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_alternativa_ejercicio_ejercicio FOREIGN KEY (id_ejercicio) REFERENCES ejercicio (id_ejercicio) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE = InnoDB COMMENT = 'Alternativas preconfiguradas para sustituir un ejercicio (RF-04)';

-- Entrenamiento de un día; su estado colorea el calendario (RF-08 a RF-10)
CREATE TABLE sesion_entrenamiento (
  id_sesion                INT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_usuario               INT UNSIGNED NOT NULL,
  id_dia                   INT UNSIGNED NULL,
  fecha                    DATE NOT NULL,
  estado                   ENUM('completa','parcial','descanso') NOT NULL,
  es_override              BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'RF-09',
  comentario               TEXT NULL,
  hora_inicio              TIME NULL,
  hora_fin                 TIME NULL,
  CONSTRAINT pk_sesion_entrenamiento PRIMARY KEY (id_sesion),
  CONSTRAINT fk_sesion_entrenamiento_usuario FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_sesion_entrenamiento_dia FOREIGN KEY (id_dia) REFERENCES dia_rutina (id_dia) ON DELETE SET NULL ON UPDATE CASCADE,
  INDEX idx_sesion_calendario (id_usuario, fecha)
) ENGINE = InnoDB COMMENT = 'Entrenamiento de un día; su estado colorea el calendario (RF-08 a RF-10)';

-- Ejercicio realmente ejecutado en una sesión (RF-03, RF-04)
CREATE TABLE registro_ejercicio (
  id_registro              INT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_sesion                INT UNSIGNED NOT NULL,
  id_programado            INT UNSIGNED NULL,
  id_ejercicio             INT UNSIGNED NOT NULL,
  es_sustitucion           BOOLEAN NOT NULL DEFAULT FALSE,
  orden                    TINYINT UNSIGNED NOT NULL,
  completado               BOOLEAN NOT NULL DEFAULT FALSE,
  CONSTRAINT pk_registro_ejercicio PRIMARY KEY (id_registro),
  CONSTRAINT fk_registro_ejercicio_sesion FOREIGN KEY (id_sesion) REFERENCES sesion_entrenamiento (id_sesion) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_registro_ejercicio_programado FOREIGN KEY (id_programado) REFERENCES ejercicio_programado (id_programado) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_registro_ejercicio_ejercicio FOREIGN KEY (id_ejercicio) REFERENCES ejercicio (id_ejercicio) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE = InnoDB COMMENT = 'Ejercicio realmente ejecutado en una sesión (RF-03, RF-04)';

-- Cada serie marcada en la bitácora (RF-03)
CREATE TABLE serie (
  id_serie                 INT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_registro              INT UNSIGNED NOT NULL,
  numero_serie             TINYINT UNSIGNED NOT NULL,
  peso_kg                  DECIMAL(6,2) NOT NULL,
  repeticiones             TINYINT UNSIGNED NOT NULL,
  completada_en            DATETIME NULL,
  CONSTRAINT pk_serie PRIMARY KEY (id_serie),
  CONSTRAINT uk_serie_id_registro_numero_serie UNIQUE (id_registro, numero_serie),
  CONSTRAINT fk_serie_registro FOREIGN KEY (id_registro) REFERENCES registro_ejercicio (id_registro) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT ck_serie_1 CHECK (peso_kg >= 0)
) ENGINE = InnoDB COMMENT = 'Cada serie marcada en la bitácora (RF-03)';

-- Registro nutricional manual o por foto con IA (RF-07)
CREATE TABLE registro_comida (
  id_comida                INT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_usuario               INT UNSIGNED NOT NULL,
  id_solicitud             INT UNSIGNED NULL COMMENT 'Escaneo de IA que la originó',
  fecha_hora               DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  descripcion              VARCHAR(255) NOT NULL,
  calorias                 SMALLINT UNSIGNED NOT NULL,
  proteinas_g              DECIMAL(6,1) NULL,
  carbohidratos_g          DECIMAL(6,1) NULL,
  grasas_g                 DECIMAL(6,1) NULL,
  origen                   ENUM('manual','ia') NOT NULL DEFAULT 'manual',
  CONSTRAINT pk_registro_comida PRIMARY KEY (id_comida),
  CONSTRAINT uk_registro_comida_id_solicitud UNIQUE (id_solicitud),
  CONSTRAINT fk_registro_comida_usuario FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_registro_comida_solicitud FOREIGN KEY (id_solicitud) REFERENCES solicitud_ia (id_solicitud) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE = InnoDB COMMENT = 'Registro nutricional manual o por foto con IA (RF-07)';

-- Mensaje periódico de la IA; analiza sesiones y comidas del periodo (RF-11, RN-03)
CREATE TABLE feedback_ia (
  id_feedback              INT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_usuario               INT UNSIGNED NOT NULL,
  tipo_periodo             ENUM('semanal','mensual') NOT NULL,
  periodo_inicio           DATE NOT NULL,
  periodo_fin              DATE NOT NULL,
  mensaje                  TEXT NOT NULL,
  detecto_estancamiento    BOOLEAN NOT NULL DEFAULT FALSE,
  generado_en              DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  leido                    BOOLEAN NOT NULL DEFAULT FALSE,
  CONSTRAINT pk_feedback_ia PRIMARY KEY (id_feedback),
  CONSTRAINT fk_feedback_ia_usuario FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT ck_feedback_ia_1 CHECK (periodo_fin >= periodo_inicio)
) ENGINE = InnoDB COMMENT = 'Mensaje periódico de la IA; analiza sesiones y comidas del periodo (RF-11, RN-03)';

-- Compras Premium hechas en App Store o Google Play
CREATE TABLE suscripcion (
  id_suscripcion           INT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_usuario               INT UNSIGNED NOT NULL,
  id_plan                  INT UNSIGNED NOT NULL,
  tienda                   ENUM('app_store','google_play') NOT NULL,
  id_transaccion_original  VARCHAR(100) NOT NULL,
  estado                   ENUM('activa','en_gracia','cancelada','expirada') NOT NULL DEFAULT 'activa',
  fecha_inicio             DATETIME NOT NULL,
  fecha_expiracion         DATETIME NOT NULL,
  renovacion_automatica    BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT pk_suscripcion PRIMARY KEY (id_suscripcion),
  CONSTRAINT uk_suscripcion_id_transaccion_original UNIQUE (id_transaccion_original),
  CONSTRAINT fk_suscripcion_usuario FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_suscripcion_plan FOREIGN KEY (id_plan) REFERENCES plan (id_plan) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT ck_suscripcion_1 CHECK (fecha_expiracion > fecha_inicio)
) ENGINE = InnoDB COMMENT = 'Compras Premium hechas en App Store o Google Play';

-- Avisos (webhooks) de las tiendas sobre una suscripción
CREATE TABLE evento_pago (
  id_evento                INT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_suscripcion           INT UNSIGNED NOT NULL,
  tipo                     ENUM('compra','renovacion','cancelacion','reembolso') NOT NULL,
  id_notificacion_tienda   VARCHAR(100) NOT NULL,
  recibido_en              DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  procesado                BOOLEAN NOT NULL DEFAULT FALSE,
  CONSTRAINT pk_evento_pago PRIMARY KEY (id_evento),
  CONSTRAINT uk_evento_pago_id_notificacion_tienda UNIQUE (id_notificacion_tienda),
  CONSTRAINT fk_evento_pago_suscripcion FOREIGN KEY (id_suscripcion) REFERENCES suscripcion (id_suscripcion) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB COMMENT = 'Avisos (webhooks) de las tiendas sobre una suscripción';

-- Planes iniciales (el precio de Premium está pendiente por definir)
INSERT INTO plan (id_plan, nombre, max_ciclos_activos, max_escaneos_dia, frecuencia_feedback, precio) VALUES
  (1, 'Gratuito', 1, 3, 'mensual', 0.00),
  (2, 'Premium', NULL, NULL, 'semanal', NULL);
