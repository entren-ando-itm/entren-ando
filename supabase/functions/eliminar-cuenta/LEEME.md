# Eliminar mi cuenta y mis datos (ENT-51)

Publica la función en el proyecto de Supabase con `supabase functions deploy eliminar-cuenta`.
No necesita secretos propios: `SUPABASE_URL`, `SUPABASE_ANON_KEY` y `SUPABASE_SERVICE_ROLE_KEY`
ya están en el entorno de las funciones.

La app manda un POST con la sesión del usuario (sin cuerpo). La función toma el usuario del JWT,
nunca de un parámetro, y lo borra de `auth.users` con la llave de servicio. Las llaves foráneas
`ON DELETE CASCADE` (desde `auth.users` → `usuario` → todas las tablas del usuario) borran el resto.

* 200 `{"eliminada": true}`: ya no queda nada en la nube.
* 401: sin sesión o sesión no válida. 503: error temporal, se puede repetir.

Para probar: crea una cuenta de prueba (nunca la del demo del equipo), registra datos, elimínala
desde Perfil → Cuenta y privacidad y revisa en el Table Editor que no quede ninguna fila con su id.
