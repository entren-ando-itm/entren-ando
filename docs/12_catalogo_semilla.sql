-- =====================================================================
-- Entren-Ando: catálogo semilla (planes, equipo y ejercicios)
-- Sirve igual para SQLite (celular) y PostgreSQL (Supabase).
-- Los id son fijos y deben ser iguales en ambos lados: la IA usa id_ejercicio.
-- Los primeros 6 equipos y 8 ejercicios coinciden con 10_MySQL_datos_prueba.sql.
-- El usuario no crea ejercicios; solo les pone alias (usuario_ejercicio).
-- =====================================================================

-- Planes y límites freemium (RN-01 a RN-03). Precio de Premium temporal: 59 MXN al mes.
INSERT INTO plan (id_plan, nombre, max_ciclos_activos, max_escaneos_dia, frecuencia_feedback, precio) VALUES
  (1, 'Gratuito', 1, 3, 'mensual', 0.00),
  (2, 'Premium', NULL, NULL, 'semanal', 59.00);

-- Equipo de gimnasio más común
INSERT INTO equipo (id_equipo, nombre, categoria) VALUES
  (1,  'Barra olímpica',                  'Peso libre'),
  (2,  'Mancuernas',                      'Peso libre'),
  (3,  'Rack de sentadillas',             'Estructura'),
  (4,  'Banco plano',                     'Estructura'),
  (5,  'Máquina de poleas',               'Máquina'),
  (6,  'Prensa de piernas',               'Máquina'),
  (7,  'Banco inclinable',                'Estructura'),
  (8,  'Barra Z',                         'Peso libre'),
  (9,  'Kettlebell',                      'Peso libre'),
  (10, 'Barra de dominadas',              'Estructura'),
  (11, 'Paralelas para fondos',           'Estructura'),
  (12, 'Máquina Smith',                   'Máquina'),
  (13, 'Máquina de extensión de piernas', 'Máquina'),
  (14, 'Máquina de curl femoral',         'Máquina'),
  (15, 'Máquina de pecho (pec deck)',     'Máquina'),
  (16, 'Máquina de pantorrilla',          'Máquina'),
  (17, 'Ligas de resistencia',            'Accesorio'),
  (18, 'Máquina de abductores',           'Máquina');

-- Ejercicios. id_equipo NULL = peso corporal.
-- grupo_muscular: Pierna, Glúteo, Pecho, Espalda, Hombro, Brazo, Core, Pantorrilla.
INSERT INTO ejercicio (id_ejercicio, nombre_oficial, grupo_muscular, tipo_movimiento, id_equipo, descripcion_tecnica) VALUES
  (1,  'Sentadilla con barra',                 'Pierna',      'compuesto',   1,    'Barra sobre trapecios, bajar con espalda neutra.'),
  (2,  'Prensa de piernas',                    'Pierna',      'compuesto',   6,    'Empujar la plataforma sin bloquear rodillas.'),
  (3,  'Press de banca',                       'Pecho',       'compuesto',   1,    'Bajar la barra a la línea del pecho.'),
  (4,  'Press con mancuernas',                 'Pecho',       'compuesto',   2,    'Mancuernas a la altura del pecho en banco plano.'),
  (5,  'Peso muerto',                          'Espalda',     'compuesto',   1,    'Levantar la barra desde el suelo con cadera y piernas.'),
  (6,  'Jalón al pecho',                       'Espalda',     'compuesto',   5,    'Tirar de la barra de la polea hacia el pecho.'),
  (7,  'Curl de bíceps con mancuernas',        'Brazo',       'aislamiento', 2,    'Flexionar el codo sin mover el hombro.'),
  (8,  'Plancha abdominal',                    'Core',        'aislamiento', NULL, 'Mantener el cuerpo recto apoyado en antebrazos.'),
  (9,  'Sentadilla goblet',                    'Pierna',      'compuesto',   9,    'Kettlebell al pecho, bajar con el torso erguido.'),
  (10, 'Sentadilla en máquina Smith',          'Pierna',      'compuesto',   12,   'Pies un poco adelante, bajar de forma controlada.'),
  (11, 'Zancadas con mancuernas',              'Pierna',      'compuesto',   2,    'Paso largo y bajar la rodilla trasera cerca del piso.'),
  (12, 'Sentadilla búlgara',                   'Pierna',      'compuesto',   2,    'Pie trasero en un banco, bajar con la pierna delantera.'),
  (13, 'Extensión de piernas',                 'Pierna',      'aislamiento', 13,   'Extender las rodillas sin despegar la cadera del asiento.'),
  (14, 'Curl femoral acostado',                'Pierna',      'aislamiento', 14,   'Llevar los talones hacia los glúteos sin arquear la espalda.'),
  (15, 'Peso muerto rumano',                   'Pierna',      'compuesto',   1,    'Bajar la barra pegada a las piernas con rodillas semiflexionadas.'),
  (16, 'Sentadilla con peso corporal',         'Pierna',      'compuesto',   NULL, 'Bajar hasta paralelo con los talones en el piso.'),
  (17, 'Hip thrust con barra',                 'Glúteo',      'compuesto',   1,    'Espalda en el banco, empujar la cadera hacia arriba.'),
  (18, 'Puente de glúteo',                     'Glúteo',      'aislamiento', NULL, 'Acostado, elevar la cadera apretando los glúteos.'),
  (19, 'Patada de glúteo en polea',            'Glúteo',      'aislamiento', 5,    'Llevar la pierna atrás sin arquear la espalda baja.'),
  (20, 'Abducción de cadera en máquina',       'Glúteo',      'aislamiento', 18,   'Separar las piernas de forma controlada.'),
  (21, 'Press inclinado con barra',            'Pecho',       'compuesto',   1,    'Banco a 30 grados, bajar a la parte alta del pecho.'),
  (22, 'Press inclinado con mancuernas',       'Pecho',       'compuesto',   2,    'Banco inclinado, subir las mancuernas sin chocarlas.'),
  (23, 'Aperturas con mancuernas',             'Pecho',       'aislamiento', 2,    'Brazos semiflexionados, abrir hasta sentir el estiramiento.'),
  (24, 'Cruce de poleas',                      'Pecho',       'aislamiento', 5,    'Juntar las manos al frente con los codos fijos.'),
  (25, 'Fondos en paralelas',                  'Pecho',       'compuesto',   11,   'Inclinar el torso adelante y bajar hasta 90 grados.'),
  (26, 'Lagartijas',                           'Pecho',       'compuesto',   NULL, 'Cuerpo recto, bajar el pecho cerca del piso.'),
  (27, 'Pec deck',                             'Pecho',       'aislamiento', 15,   'Cerrar los brazos al frente sin despegar la espalda.'),
  (28, 'Dominadas',                            'Espalda',     'compuesto',   10,   'Subir hasta que la barbilla pase la barra.'),
  (29, 'Remo con barra',                       'Espalda',     'compuesto',   1,    'Torso inclinado, llevar la barra al abdomen.'),
  (30, 'Remo con mancuerna a una mano',        'Espalda',     'compuesto',   2,    'Apoyo en banco, llevar el codo hacia atrás.'),
  (31, 'Remo sentado en polea',                'Espalda',     'compuesto',   5,    'Espalda recta, llevar el agarre al abdomen.'),
  (32, 'Jalón con agarre cerrado',             'Espalda',     'compuesto',   5,    'Agarre en V, tirar hacia el pecho sin balancearse.'),
  (33, 'Pullover en polea',                    'Espalda',     'aislamiento', 5,    'Brazos casi rectos, bajar la barra hasta los muslos.'),
  (34, 'Hiperextensiones',                     'Espalda',     'aislamiento', NULL, 'Subir el torso hasta alinearlo con las piernas.'),
  (35, 'Press militar con barra',              'Hombro',      'compuesto',   1,    'De pie, empujar la barra sobre la cabeza sin arquear.'),
  (36, 'Press de hombro con mancuernas',       'Hombro',      'compuesto',   2,    'Sentado, subir las mancuernas hasta casi juntarlas.'),
  (37, 'Elevaciones laterales',                'Hombro',      'aislamiento', 2,    'Subir los brazos a los lados hasta la altura del hombro.'),
  (38, 'Elevaciones frontales',                'Hombro',      'aislamiento', 2,    'Subir los brazos al frente hasta la altura de los ojos.'),
  (39, 'Pájaros con mancuernas',               'Hombro',      'aislamiento', 2,    'Torso inclinado, abrir los brazos hacia atrás.'),
  (40, 'Face pull en polea',                   'Hombro',      'aislamiento', 5,    'Llevar la cuerda hacia la cara con los codos altos.'),
  (41, 'Encogimientos con mancuernas',         'Hombro',      'aislamiento', 2,    'Subir los hombros hacia las orejas sin girarlos.'),
  (42, 'Curl con barra',                       'Brazo',       'aislamiento', 1,    'Codos pegados al cuerpo, subir sin balanceo.'),
  (43, 'Curl con barra Z',                     'Brazo',       'aislamiento', 8,    'Agarre en la curva de la barra, subir controlado.'),
  (44, 'Curl martillo',                        'Brazo',       'aislamiento', 2,    'Palmas hacia adentro, flexionar el codo.'),
  (45, 'Curl en polea',                        'Brazo',       'aislamiento', 5,    'Codos fijos, subir la barra de la polea baja.'),
  (46, 'Extensión de tríceps en polea',        'Brazo',       'aislamiento', 5,    'Codos fijos, extender los brazos hacia abajo.'),
  (47, 'Press francés con barra Z',            'Brazo',       'aislamiento', 8,    'Acostado, bajar la barra a la frente y extender.'),
  (48, 'Fondos en banco',                      'Brazo',       'compuesto',   4,    'Manos en el banco, bajar flexionando los codos.'),
  (49, 'Extensión de tríceps sobre la cabeza', 'Brazo',       'aislamiento', 2,    'Mancuerna detrás de la cabeza, extender los codos.'),
  (50, 'Press de banca con agarre cerrado',    'Brazo',       'compuesto',   1,    'Manos al ancho de hombros, codos pegados al cuerpo.'),
  (51, 'Crunch abdominal',                     'Core',        'aislamiento', NULL, 'Subir los hombros del piso contrayendo el abdomen.'),
  (52, 'Elevación de piernas colgado',         'Core',        'aislamiento', 10,   'Colgado de la barra, subir las piernas sin balanceo.'),
  (53, 'Plancha lateral',                      'Core',        'aislamiento', NULL, 'Apoyado en un antebrazo, cadera alineada.'),
  (54, 'Crunch en polea',                      'Core',        'aislamiento', 5,    'De rodillas, flexionar el torso jalando la cuerda.'),
  (55, 'Giros rusos',                          'Core',        'aislamiento', NULL, 'Sentado, girar el torso de lado a lado.'),
  (56, 'Swing con kettlebell',                 'Glúteo',      'compuesto',   9,    'Impulsar la kettlebell con la cadera hasta el pecho.'),
  (57, 'Elevación de talones de pie',          'Pantorrilla', 'aislamiento', 16,   'Subir sobre las puntas y bajar lento.'),
  (58, 'Elevación de talones en prensa',       'Pantorrilla', 'aislamiento', 6,    'Empujar la plataforma solo con las puntas.'),
  (59, 'Remo con liga de resistencia',         'Espalda',     'compuesto',   17,   'Tirar de la liga hacia el abdomen con la espalda recta.'),
  (60, 'Peso muerto con mancuernas',           'Pierna',      'compuesto',   2,    'Bajar las mancuernas pegadas a las piernas.');
