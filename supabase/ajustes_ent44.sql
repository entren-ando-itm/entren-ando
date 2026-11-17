-- =====================================================================
-- Entren-Ando: ajustes de Supabase para la sincronización · ENT-44
--
-- Se corre UNA sola vez, después de esquema.sql, del catálogo y de
-- politicas.sql: panel de Supabase > SQL Editor > pegar todo > Run.
-- Se puede volver a correr sin problema: si ya está aplicado, no cambia nada.
--
-- 1. Zona horaria de Ciudad de México (pendiente técnico de la bitácora).
--    Supabase trabaja en UTC: una comida de las 23:30 del día 9 regresaría
--    como "10 de noviembre 05:30". Con esto las fechas regresan con -06:00.
--
-- 2. El usuario demo de Supabase usa el mismo id que el demo del celular
--    (00000000-0000-0000-0000-000000000001, lib/core/db/datos_prueba.dart).
--    La seguridad (RLS) solo deja subir filas cuyo id_usuario es el del que
--    inició sesión; con ids distintos, todo lo del demo se rechazaría.
--    Se cambia el id en Authentication (auth.users y su identidad) en una sola
--    sentencia; la contraseña del demo no cambia. Si ya hay una sesión del demo
--    abierta en un celular, hay que cerrar sesión y volver a entrar.
-- =====================================================================

ALTER DATABASE postgres SET timezone TO 'America/Mexico_City';

-- Las sesiones abiertas del demo se cierran (guardan el id viejo).
DELETE FROM auth.sessions
WHERE user_id IN (
  SELECT id FROM auth.users
  WHERE email = 'demo@entrenando.test'
    AND id <> '00000000-0000-0000-0000-000000000001'
);

-- Las llaves foráneas se revisan al final de la sentencia, por eso la
-- identidad y el usuario cambian juntos con un WITH.
WITH viejo AS (
  SELECT id FROM auth.users
  WHERE email = 'demo@entrenando.test'
    AND id <> '00000000-0000-0000-0000-000000000001'
),
identidad AS (
  UPDATE auth.identities
  SET user_id = '00000000-0000-0000-0000-000000000001',
      provider_id = CASE WHEN provider = 'email'
                         THEN '00000000-0000-0000-0000-000000000001'
                         ELSE provider_id END,
      identity_data = identity_data || '{"sub": "00000000-0000-0000-0000-000000000001"}'::jsonb
  WHERE user_id IN (SELECT id FROM viejo)
)
UPDATE auth.users
SET id = '00000000-0000-0000-0000-000000000001'
WHERE id IN (SELECT id FROM viejo);

-- Comprobación: debe dar una fila con el id 00000000-...-0001 y la zona
-- America/Mexico_City (la zona se ve en conexiones nuevas; si sale UTC,
-- vuelve a correr solo este SELECT en otra pestaña).
SELECT id, email, current_setting('TimeZone') AS zona
FROM auth.users
WHERE email = 'demo@entrenando.test';
