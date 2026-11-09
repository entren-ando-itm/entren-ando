-- =====================================================================
-- Entren-Ando: datos de prueba para el modelo físico (MySQL 8.0)
-- Ejecutar DESPUÉS de entren_ando_modelo_logico.sql
-- =====================================================================
USE entren_ando;

INSERT INTO usuario (id_usuario, correo, nombre, fecha_nacimiento, sexo, id_plan, fecha_registro) VALUES
  (1, 'ana.lopez@correo.com',   'Ana López',     '2002-04-15', 'femenino',  1, '2026-08-01 09:00:00'),
  (2, 'luis.mendez@correo.com', 'Luis Méndez',   '1999-11-02', 'masculino', 2, '2026-08-03 18:30:00'),
  (3, 'sofia.ruiz@correo.com',  'Sofía Ruiz',    '2004-01-20', 'femenino',  1, '2026-09-10 07:45:00');

INSERT INTO perfil_entrenamiento (id_perfil, id_usuario, objetivo, nivel_experiencia, dias_por_semana, notas_lesiones) VALUES
  (1, 1, 'hipertrofia', 'principiante', 4, NULL),
  (2, 2, 'fuerza',      'avanzado',     5, 'Molestia leve en hombro derecho'),
  (3, 3, 'salud',       'intermedio',   3, NULL);

INSERT INTO medicion_biometrica (id_medicion, id_usuario, fecha, peso_kg, estatura_cm, porcentaje_grasa) VALUES
  (1, 1, '2026-08-01', 58.40, 162.0, 24.5),
  (2, 1, '2026-09-01', 59.10, 162.0, 23.8),
  (3, 2, '2026-08-03', 82.00, 178.5, 16.0),
  (4, 3, '2026-09-10', 64.20, 168.0, NULL);

INSERT INTO equipo (id_equipo, nombre, categoria) VALUES
  (1, 'Barra olímpica',      'Peso libre'),
  (2, 'Mancuernas',          'Peso libre'),
  (3, 'Rack de sentadillas', 'Estructura'),
  (4, 'Banco plano',         'Estructura'),
  (5, 'Máquina de poleas',   'Máquina'),
  (6, 'Prensa de piernas',   'Máquina');

INSERT INTO usuario_equipo (id_usuario, id_equipo) VALUES
  (1, 2), (1, 4), (1, 5), (2, 1), (2, 2), (2, 3), (2, 4), (3, 2), (3, 6);

INSERT INTO ejercicio (id_ejercicio, nombre_oficial, grupo_muscular, tipo_movimiento, id_equipo, descripcion_tecnica) VALUES
  (1, 'Sentadilla con barra',          'Pierna',  'compuesto',   1, 'Barra sobre trapecios, bajar con espalda neutra.'),
  (2, 'Prensa de piernas',             'Pierna',  'compuesto',   6, 'Empujar la plataforma sin bloquear rodillas.'),
  (3, 'Press de banca',                'Pecho',   'compuesto',   1, 'Bajar la barra a la línea del pecho.'),
  (4, 'Press con mancuernas',          'Pecho',   'compuesto',   2, 'Mancuernas a la altura del pecho en banco plano.'),
  (5, 'Peso muerto',                   'Espalda', 'compuesto',   1, 'Levantar la barra desde el suelo con cadera y piernas.'),
  (6, 'Jalón al pecho',                'Espalda', 'compuesto',   5, 'Tirar de la barra de la polea hacia el pecho.'),
  (7, 'Curl de bíceps con mancuernas', 'Brazo',   'aislamiento', 2, 'Flexionar el codo sin mover el hombro.'),
  (8, 'Plancha abdominal',             'Core',    'aislamiento', NULL, 'Mantener el cuerpo recto apoyado en antebrazos.');

INSERT INTO usuario_ejercicio (id_usuario, id_ejercicio, nombre_alias) VALUES
  (2, 5, 'Levantamiento de garrafón'),
  (1, 6, 'Jalón de polea');

INSERT INTO solicitud_ia (id_solicitud, id_usuario, tipo, fecha_hora, estado) VALUES
  (1, 1, 'rutina',   '2026-08-01 09:10:00', 'completada'),
  (2, 2, 'rutina',   '2026-08-03 18:40:00', 'completada'),
  (3, 1, 'escaneo',  '2026-10-28 14:05:00', 'completada'),
  (4, 2, 'escaneo',  '2026-10-28 20:15:00', 'completada'),
  (5, 1, 'feedback', '2026-11-01 06:00:00', 'completada');

INSERT INTO ciclo_rutina (id_ciclo, id_usuario, id_solicitud, nombre, fecha_inicio, fecha_fin, estado, origen) VALUES
  (1, 1, 1,    'Semestre agosto-diciembre', '2026-08-01', '2026-12-15', 'activo', 'ia'),
  (2, 2, 2,    'Fuerza base',               '2026-08-03', NULL,         'activo', 'ia'),
  (3, 3, NULL, 'Rutina de mantenimiento',   '2026-09-10', NULL,         'activo', 'manual');

INSERT INTO dia_rutina (id_dia, id_ciclo, dia_semana, nombre, es_descanso) VALUES
  (1, 1, 1, 'Pierna',          FALSE),
  (2, 1, 3, 'Pecho y brazo',   FALSE),
  (3, 1, 7, 'Descanso',        TRUE),
  (4, 2, 1, 'Pierna pesada',   FALSE),
  (5, 2, 2, 'Empuje',          FALSE),
  (6, 3, 2, 'Cuerpo completo', FALSE);

INSERT INTO ejercicio_programado (id_programado, id_dia, id_ejercicio, orden, series_objetivo, reps_objetivo, peso_objetivo_kg, descanso_seg, trabajo_seg) VALUES
  (1, 1, 2, 1, 4, 12, 80.00,  90,  NULL),
  (2, 1, 8, 2, 3, 1,  NULL,   60,  45),
  (3, 2, 4, 1, 4, 10, 12.00,  90,  NULL),
  (4, 2, 7, 2, 3, 12, 8.00,   60,  NULL),
  (5, 4, 1, 1, 5, 5,  100.00, 180, NULL),
  (6, 4, 5, 2, 3, 5,  120.00, 180, NULL),
  (7, 5, 3, 1, 5, 5,  85.00,  150, NULL),
  (8, 6, 6, 1, 3, 12, 35.00,  90,  NULL);

INSERT INTO alternativa_ejercicio (id_alternativa, id_programado, id_ejercicio, prioridad) VALUES
  (1, 5, 2, 1),
  (2, 7, 4, 1),
  (3, 3, 3, 1);

INSERT INTO sesion_entrenamiento (id_sesion, id_usuario, id_dia, fecha, estado, es_override, comentario, hora_inicio, hora_fin) VALUES
  (1, 1, 1, '2026-10-26', 'completa', FALSE, NULL,                          '07:00:00', '08:05:00'),
  (2, 1, 2, '2026-10-28', 'parcial',  FALSE, 'Me faltó el curl por tiempo', '19:00:00', '19:40:00'),
  (3, 2, 4, '2026-10-26', 'completa', FALSE, NULL,                          '06:30:00', '08:00:00'),
  (4, 2, 5, '2026-10-27', 'completa', TRUE,  'Olvidé el celular; marcado después', NULL, NULL),
  (5, 1, 3, '2026-11-01', 'descanso', FALSE, NULL,                          NULL,       NULL);

INSERT INTO registro_ejercicio (id_registro, id_sesion, id_programado, id_ejercicio, es_sustitucion, orden, completado) VALUES
  (1, 1, 1, 2, FALSE, 1, TRUE),
  (2, 1, 2, 8, FALSE, 2, TRUE),
  (3, 2, 3, 4, FALSE, 1, TRUE),
  (4, 3, 5, 2, TRUE,  1, TRUE),
  (5, 3, 6, 5, FALSE, 2, TRUE),
  (6, 4, 7, 3, FALSE, 1, TRUE);

INSERT INTO serie (id_serie, id_registro, numero_serie, peso_kg, repeticiones, completada_en) VALUES
  (1,  1, 1, 80.00,  12, '2026-10-26 07:10:00'),
  (2,  1, 2, 80.00,  12, '2026-10-26 07:13:00'),
  (3,  1, 3, 85.00,  10, '2026-10-26 07:16:00'),
  (4,  1, 4, 85.00,  10, '2026-10-26 07:19:00'),
  (5,  2, 1, 0.00,   1,  '2026-10-26 07:30:00'),
  (6,  3, 1, 12.00,  10, '2026-10-28 19:10:00'),
  (7,  3, 2, 12.00,  9,  '2026-10-28 19:13:00'),
  (8,  4, 1, 160.00, 8,  '2026-10-26 06:45:00'),
  (9,  5, 1, 120.00, 5,  '2026-10-26 07:20:00'),
  (10, 5, 2, 120.00, 5,  '2026-10-26 07:25:00'),
  (11, 6, 1, 85.00,  5,  NULL);

INSERT INTO registro_comida (id_comida, id_usuario, id_solicitud, fecha_hora, descripcion, calorias, proteinas_g, carbohidratos_g, grasas_g, origen) VALUES
  (1, 1, NULL, '2026-10-28 08:00:00', 'Avena con plátano',       350, 12.0, 60.0, 7.0,  'manual'),
  (2, 1, 3,    '2026-10-28 14:05:00', 'Pechuga con arroz',       520, 45.0, 55.0, 10.0, 'ia'),
  (3, 2, 4,    '2026-10-28 20:15:00', 'Tacos de bistec (3)',     610, 38.0, 48.0, 28.0, 'ia'),
  (4, 3, NULL, '2026-10-29 13:30:00', 'Ensalada con atún',       300, 28.0, 12.0, 14.0, 'manual');

INSERT INTO feedback_ia (id_feedback, id_usuario, tipo_periodo, periodo_inicio, periodo_fin, mensaje, detecto_estancamiento, generado_en, leido) VALUES
  (1, 1, 'mensual', '2026-10-01', '2026-10-31', 'Buen mes: cumpliste 80% de tus días. Tu prensa subió 5 kg.', FALSE, '2026-11-01 06:00:00', FALSE),
  (2, 2, 'semanal', '2026-10-26', '2026-11-01', 'Tu press de banca lleva 3 semanas en 85 kg; prueba subir 2.5 kg.', TRUE, '2026-11-02 06:00:00', TRUE);

INSERT INTO suscripcion (id_suscripcion, id_usuario, id_plan, tienda, id_transaccion_original, estado, fecha_inicio, fecha_expiracion, renovacion_automatica) VALUES
  (1, 2, 2, 'google_play', 'GPA.3312-4521-8890-12345', 'activa', '2026-09-01 10:00:00', '2026-12-01 10:00:00', TRUE);

INSERT INTO evento_pago (id_evento, id_suscripcion, tipo, id_notificacion_tienda, recibido_en, procesado) VALUES
  (1, 1, 'compra',     'rtdn-0001-2026-09-01', '2026-09-01 10:00:05', TRUE),
  (2, 1, 'renovacion', 'rtdn-0002-2026-10-01', '2026-10-01 10:00:04', TRUE);
