-- =====================================================================
-- Entren-Ando: datos de prueba (solo en modo debug)
--
-- Lo ejecuta datos_prueba.dart cuando la base está vacía. Todas las
-- fechas se calculan a partir de HOY (hora de Ciudad de México), así que
-- siempre hay sesiones de los últimos 45 días.
--
-- Qué crea:
--   * Usuario demo 00000000-0000-0000-0000-000000000001
--     (demo@entrenando.test) con plan Gratuito, perfil y 2 mediciones.
--   * Ciclo activo: lunes Pierna, martes Empuje, jueves Pierna y glúteo,
--     viernes Jalón; miércoles, sábado y domingo son descanso.
--     4 o 5 ejercicios por día y una alternativa por ejercicio.
--   * Sesiones de los últimos 45 días: completas, parciales, descanso,
--     una forzada (override), una con sustitución y días sin registro,
--     tanto en los últimos 30 días como más atrás (bloqueo de RF-10).
--   * El press de banca lleva más de 3 semanas en 60 kg (estancamiento).
--   * 2 alias, 3 comidas de hoy (una por escaneo de IA: 1 de 3 escaneos
--     del día) y 1 feedback mensual sin leer.
--
-- Los id son UUID fijos para poder relacionar las filas entre sí.
-- Todo se crea con pendiente_sync = 0: los datos demo no se suben a Supabase.
-- No uses comentarios de bloque ni punto y coma dentro de los comentarios.
-- =====================================================================


-- Tablas temporales de apoyo (se borran al final)
CREATE TEMP TABLE hoy AS SELECT date('now', '-6 hours') AS fecha;

CREATE TEMP TABLE numeros (n INTEGER PRIMARY KEY);
INSERT INTO numeros (n) VALUES
  (0), (1), (2), (3), (4), (5), (6), (7), (8), (9),
  (10), (11), (12), (13), (14), (15), (16), (17), (18), (19),
  (20), (21), (22), (23), (24), (25), (26), (27), (28), (29),
  (30), (31), (32), (33), (34), (35), (36), (37), (38), (39),
  (40), (41), (42), (43), (44), (45);


-- Usuario demo, perfil y mediciones
INSERT INTO usuario (id_usuario, correo, nombre, fecha_nacimiento, sexo, id_plan, fecha_registro, pendiente_sync)
SELECT '00000000-0000-0000-0000-000000000001', 'demo@entrenando.test', 'Usuario Demo', '2004-05-10', 'masculino', 1,
       date(fecha, '-60 days') || 'T09:00:00-06:00', 0
FROM hoy;

INSERT INTO perfil_entrenamiento (id_perfil, id_usuario, objetivo, nivel_experiencia, dias_por_semana, notas_lesiones, pendiente_sync)
VALUES ('00000001-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000001',
        'hipertrofia', 'intermedio', 4, 'Molestia leve en la rodilla izquierda al bajar en sentadilla', 0);

INSERT INTO medicion_biometrica (id_medicion, id_usuario, fecha, peso_kg, estatura_cm, porcentaje_grasa, pendiente_sync)
SELECT '00000002-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000001', date(fecha, '-60 days'), 75.4, 175.0, 18.5, 0 FROM hoy
UNION ALL
SELECT '00000002-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000001', date(fecha, '-15 days'), 74.6, 175.0, 17.8, 0 FROM hoy;

-- Equipo disponible y alias
INSERT INTO usuario_equipo (id_usuario, id_equipo, pendiente_sync) VALUES
  ('00000000-0000-0000-0000-000000000001', 1, 0),
  ('00000000-0000-0000-0000-000000000001', 2, 0),
  ('00000000-0000-0000-0000-000000000001', 3, 0),
  ('00000000-0000-0000-0000-000000000001', 4, 0),
  ('00000000-0000-0000-0000-000000000001', 5, 0),
  ('00000000-0000-0000-0000-000000000001', 6, 0),
  ('00000000-0000-0000-0000-000000000001', 7, 0),
  ('00000000-0000-0000-0000-000000000001', 10, 0),
  ('00000000-0000-0000-0000-000000000001', 13, 0),
  ('00000000-0000-0000-0000-000000000001', 14, 0),
  ('00000000-0000-0000-0000-000000000001', 17, 0);

INSERT INTO usuario_ejercicio (id_usuario, id_ejercicio, nombre_alias, pendiente_sync) VALUES
  ('00000000-0000-0000-0000-000000000001', 6, 'Jalón de polea', 0),
  ('00000000-0000-0000-0000-000000000001', 15, 'Levantamiento de garrafón', 0);


-- Solicitudes a la IA: la rutina inicial, el feedback del mes y 1 escaneo de hoy
INSERT INTO solicitud_ia (id_solicitud, id_usuario, tipo, fecha_hora, estado, pendiente_sync)
SELECT '00000003-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000001', 'rutina',
       date(fecha, '-60 days') || 'T09:10:00-06:00', 'completada', 0 FROM hoy
UNION ALL
SELECT '00000003-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000001', 'feedback',
       date(fecha, 'start of month') || 'T06:00:00-06:00', 'completada', 0 FROM hoy
UNION ALL
SELECT '00000003-0000-4000-8000-000000000003', '00000000-0000-0000-0000-000000000001', 'escaneo',
       fecha || 'T14:30:00-06:00', 'completada', 0 FROM hoy;


-- Ciclo activo de 4 días
INSERT INTO ciclo_rutina (id_ciclo, id_usuario, id_solicitud, nombre, fecha_inicio, fecha_fin, estado, origen, pendiente_sync)
SELECT '00000004-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000001', '00000003-0000-4000-8000-000000000001',
       'Ciclo demo: torso y pierna', date(fecha, '-60 days'), date(fecha, '+60 days'), 'activo', 'ia', 0
FROM hoy;

-- El último número del id de cada día es su dia_semana (1 = lunes ... 7 = domingo)
INSERT INTO dia_rutina (id_dia, id_ciclo, dia_semana, nombre, es_descanso, pendiente_sync) VALUES
  ('00000005-0000-4000-8000-000000000001', '00000004-0000-4000-8000-000000000001', 1, 'Pierna', 0, 0),
  ('00000005-0000-4000-8000-000000000002', '00000004-0000-4000-8000-000000000001', 2, 'Empuje', 0, 0),
  ('00000005-0000-4000-8000-000000000003', '00000004-0000-4000-8000-000000000001', 3, 'Descanso', 1, 0),
  ('00000005-0000-4000-8000-000000000004', '00000004-0000-4000-8000-000000000001', 4, 'Pierna y glúteo', 0, 0),
  ('00000005-0000-4000-8000-000000000005', '00000004-0000-4000-8000-000000000001', 5, 'Jalón', 0, 0),
  ('00000005-0000-4000-8000-000000000006', '00000004-0000-4000-8000-000000000001', 6, 'Descanso', 1, 0),
  ('00000005-0000-4000-8000-000000000007', '00000004-0000-4000-8000-000000000001', 7, 'Descanso', 1, 0);

-- Plantilla de cada día: ejercicio, series, repeticiones, peso, descanso, trabajo y alternativa
CREATE TEMP TABLE programa_demo (
  dia INTEGER, orden INTEGER, id_ejercicio INTEGER, series INTEGER, reps INTEGER,
  peso REAL, descanso INTEGER, trabajo INTEGER, alternativa INTEGER
);
INSERT INTO programa_demo VALUES
  (1, 1,  1, 4,  8,  60.0, 120, NULL, 10),
  (1, 2,  2, 4, 12, 120.0,  90, NULL, 11),
  (1, 3, 13, 3, 12,  40.0,  60, NULL, 12),
  (1, 4, 14, 3, 12,  35.0,  60, NULL, 15),
  (1, 5, 58, 4, 15,  80.0,  45, NULL, 57),
  (2, 1,  3, 4,  8,  60.0, 120, NULL,  4),
  (2, 2, 22, 3, 10,  20.0,  90, NULL, 21),
  (2, 3, 36, 3, 10,  16.0,  90, NULL, 35),
  (2, 4, 37, 3, 15,   8.0,  60, NULL, 38),
  (2, 5, 46, 3, 12,  25.0,  60, NULL, 48),
  (4, 1, 15, 4, 10,  60.0, 120, NULL, 60),
  (4, 2, 17, 4, 10,  70.0,  90, NULL, 18),
  (4, 3, 11, 3, 12,  14.0,  90, NULL, 12),
  (4, 4,  8, 3,  1,  NULL,  60,   45, 53),
  (5, 1,  6, 4, 10,  50.0,  90, NULL, 28),
  (5, 2, 29, 4,  8,  50.0, 120, NULL, 30),
  (5, 3, 31, 3, 12,  45.0,  90, NULL, 59),
  (5, 4,  7, 3, 12,  10.0,  60, NULL, 44),
  (5, 5, 40, 3, 15,  20.0,  60, NULL, 39);

INSERT INTO ejercicio_programado (id_programado, id_dia, id_ejercicio, orden, series_objetivo, reps_objetivo,
                                  peso_objetivo_kg, descanso_seg, trabajo_seg, pendiente_sync)
SELECT printf('00000006-0000-4000-8000-%012d', dia * 10 + orden),
       printf('00000005-0000-4000-8000-%012d', dia),
       id_ejercicio, orden, series, reps, peso, descanso, trabajo, 0
FROM programa_demo;

INSERT INTO alternativa_ejercicio (id_alternativa, id_programado, id_ejercicio, prioridad, pendiente_sync)
SELECT printf('00000007-0000-4000-8000-%012d', dia * 10 + orden),
       printf('00000006-0000-4000-8000-%012d', dia * 10 + orden),
       alternativa, 1, 0
FROM programa_demo;


-- Calendario de los últimos 45 días (n = días hacia atrás, sin contar hoy)
CREATE TEMP TABLE calendario_demo AS
SELECT x.n AS n,
       date(h.fecha, '-' || x.n || ' days') AS fecha,
       ((CAST(strftime('%w', date(h.fecha, '-' || x.n || ' days')) AS INTEGER) + 6) % 7) + 1 AS dia_semana
FROM numeros x, hoy h
WHERE x.n BETWEEN 1 AND 45;

-- k numera los días de entrenamiento (y aparte los de descanso) del más reciente al más antiguo.
-- Entrenamiento: k 4 y 11 sin registro (últimos 30 días), k 20 y 24 sin registro (más de 30 días),
-- k 9 forzado con override, k 2, 7, 12, 17 y 22 parciales, el resto completos.
-- Descanso: uno sí y uno no se registra como descanso.
CREATE TEMP TABLE sesiones_demo AS
SELECT n, fecha, dia_semana, es_descanso, k,
       CASE
         WHEN es_descanso = 1 THEN CASE WHEN k % 2 = 1 THEN 'descanso' END
         WHEN k IN (4, 11, 20, 24) THEN NULL
         WHEN k = 9 THEN 'override'
         WHEN k % 5 = 2 THEN 'parcial'
         ELSE 'completa'
       END AS estado
FROM (
  SELECT c.n, c.fecha, c.dia_semana, d.es_descanso,
         ROW_NUMBER() OVER (PARTITION BY d.es_descanso ORDER BY c.n) AS k
  FROM calendario_demo c
  JOIN dia_rutina d ON d.id_ciclo = '00000004-0000-4000-8000-000000000001' AND d.dia_semana = c.dia_semana
);

-- El viernes completo más reciente se cambió el jalón al pecho por dominadas (RF-04)
CREATE TEMP TABLE sustitucion_demo AS
SELECT MIN(n) AS n FROM sesiones_demo WHERE dia_semana = 5 AND estado = 'completa';

INSERT INTO sesion_entrenamiento (id_sesion, id_usuario, id_dia, fecha, estado, es_override, comentario,
                                  hora_inicio, hora_fin, pendiente_sync)
SELECT printf('00000008-0000-4000-8000-%012d', n),
       '00000000-0000-0000-0000-000000000001',
       printf('00000005-0000-4000-8000-%012d', dia_semana),
       fecha,
       CASE estado WHEN 'override' THEN 'completa' ELSE estado END,
       CASE estado WHEN 'override' THEN 1 ELSE 0 END,
       CASE estado
         WHEN 'override' THEN 'Olvidé el celular; marcado después'
         WHEN 'parcial' THEN 'Me faltaron ejercicios por tiempo'
       END,
       CASE estado WHEN 'completa' THEN '07:00:00' WHEN 'parcial' THEN '19:00:00' END,
       CASE estado WHEN 'completa' THEN '08:10:00' WHEN 'parcial' THEN '19:45:00' END,
       0
FROM sesiones_demo
WHERE estado IS NOT NULL;

-- Ejercicios hechos: todos en sesiones completas y forzadas, solo los 3 primeros en las parciales
INSERT INTO registro_ejercicio (id_registro, id_sesion, id_programado, id_ejercicio, es_sustitucion, orden,
                                completado, pendiente_sync)
SELECT printf('00000009-0000-4000-8000-%012d', s.n * 100 + p.orden),
       printf('00000008-0000-4000-8000-%012d', s.n),
       printf('00000006-0000-4000-8000-%012d', p.dia * 10 + p.orden),
       CASE WHEN s.n = (SELECT n FROM sustitucion_demo) AND p.orden = 1 THEN p.alternativa ELSE p.id_ejercicio END,
       CASE WHEN s.n = (SELECT n FROM sustitucion_demo) AND p.orden = 1 THEN 1 ELSE 0 END,
       p.orden, 1, 0
FROM sesiones_demo s
JOIN programa_demo p ON p.dia = s.dia_semana
WHERE s.estado IN ('completa', 'override') OR (s.estado = 'parcial' AND p.orden <= 3);

-- Series: el peso sube 2.5 kg (1 kg en pesos ligeros) cada 2 semanas, salvo el press de banca,
-- que lleva más de 3 semanas en 60 kg. La última serie sale con una repetición menos.
INSERT INTO serie (id_serie, id_registro, numero_serie, peso_kg, repeticiones, completada_en, pendiente_sync)
SELECT printf('0000000a-0000-4000-8000-%012d', s.n * 10000 + p.orden * 100 + x.n),
       printf('00000009-0000-4000-8000-%012d', s.n * 100 + p.orden),
       x.n,
       CASE
         WHEN s.n = (SELECT n FROM sustitucion_demo) AND p.orden = 1 THEN 0
         WHEN p.peso IS NULL THEN 0
         WHEN p.id_ejercicio = 3 THEN CASE WHEN s.n <= 24 THEN 60.0 ELSE 57.5 END
         ELSE max(p.peso - (CASE WHEN p.peso >= 20 THEN 2.5 ELSE 1.0 END) * (s.n / 14), p.peso * 0.6)
       END,
       CASE
         WHEN s.n = (SELECT n FROM sustitucion_demo) AND p.orden = 1 THEN 8
         WHEN x.n = p.series AND p.reps > 1 THEN p.reps - 1
         ELSE p.reps
       END,
       CASE WHEN s.estado = 'override' THEN NULL
            ELSE strftime('%Y-%m-%dT%H:%M:%S',
                          s.fecha || CASE s.estado WHEN 'parcial' THEN ' 19:00:00' ELSE ' 07:00:00' END,
                          '+' || (5 + (p.orden - 1) * 12 + (x.n - 1) * 3) || ' minutes') || '-06:00'
       END,
       0
FROM sesiones_demo s
JOIN programa_demo p ON p.dia = s.dia_semana
JOIN numeros x ON x.n BETWEEN 1 AND p.series
WHERE s.estado IN ('completa', 'override') OR (s.estado = 'parcial' AND p.orden <= 3);


-- Comidas de hoy (la de las 14:30 viene del escaneo de IA)
INSERT INTO registro_comida (id_comida, id_usuario, id_solicitud, fecha_hora, descripcion, calorias,
                             proteinas_g, carbohidratos_g, grasas_g, origen, pendiente_sync)
SELECT '0000000b-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000001', NULL,
       fecha || 'T08:00:00-06:00', 'Avena con plátano y leche', 420, 15.0, 68.0, 9.0, 'manual', 0 FROM hoy
UNION ALL
SELECT '0000000b-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000001', '00000003-0000-4000-8000-000000000003',
       fecha || 'T14:30:00-06:00', 'Pechuga de pollo con arroz y ensalada', 610, 48.0, 62.0, 14.0, 'ia', 0 FROM hoy
UNION ALL
SELECT '0000000b-0000-4000-8000-000000000003', '00000000-0000-0000-0000-000000000001', NULL,
       fecha || 'T20:00:00-06:00', 'Quesadillas de frijol (2)', 380, 18.0, 44.0, 14.0, 'manual', 0 FROM hoy;

-- Feedback mensual del mes pasado, sin leer
INSERT INTO feedback_ia (id_feedback, id_usuario, tipo_periodo, periodo_inicio, periodo_fin, mensaje,
                         detecto_estancamiento, generado_en, leido, pendiente_sync)
SELECT '0000000c-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000001', 'mensual',
       date(fecha, 'start of month', '-1 month'), date(fecha, 'start of month', '-1 day'),
       'Buen mes: cumpliste la mayoría de tus entrenamientos. Tu press de banca lleva 3 semanas en 60 kg, si te sientes bien prueba subir 2.5 kg.',
       1, date(fecha, 'start of month') || 'T06:00:00-06:00', 0, 0
FROM hoy;


-- Limpieza
DROP TABLE temp.sustitucion_demo;
DROP TABLE temp.sesiones_demo;
DROP TABLE temp.calendario_demo;
DROP TABLE temp.programa_demo;
DROP TABLE temp.numeros;
DROP TABLE temp.hoy;
