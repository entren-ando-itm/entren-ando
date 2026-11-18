# features/nube

Dueño: Ángel. Historias: ENT-13 (proyecto Supabase), ENT-44 (sincronización) y ENT-54 (indicador y
botón "Sincronizar ahora").

## Qué hay aquí

| Archivo | Qué hace |
| --- | --- |
| `cliente_supabase.dart` | `ClienteSupabase.iniciar()` (se llama en `main.dart`) y `ClienteSupabase.cliente`. Lee las llaves del archivo `.env`. |
| `pantalla_nube_prueba.dart` | Solo modo de prueba: iniciar sesión con el demo, ver el estado y sincronizar a mano. Perfil → Modo de prueba → Nube y sincronización. |

## Configurar las llaves (cada quien en su compu)

Las llaves de Supabase nunca van en el código ni en GitHub.

1. En `entren_ando/`, copia `.env.example` como `.env`.
2. En Supabase → botón **Connect** (o Project Settings → API) copia la **Project URL** y la llave
   **anon / publishable**. Nunca la service_role.
3. `DEMO_PASSWORD` es la contraseña del demo que acordó el equipo. **Quítala antes de armar el APK
   de entrega**: `--dart-define` la deja dentro del APK.
4. Corre la app con `flutter run --dart-define-from-file=.env`.

Sin `.env` la app funciona igual (todo local), solo que no sincroniza.

## Una sola vez en Supabase

Corre `supabase/ajustes_ent44.sql` en el SQL Editor (se puede correr más de una vez):

1. Zona horaria de Ciudad de México.
2. Le da al demo de Supabase el mismo id que el demo del celular
   (`00000000-0000-0000-0000-000000000001`). Sin eso, RLS rechaza todo lo que sube el demo.
3. Crea las 3 solicitudes de IA del demo con los mismos ids que en el celular. Sin eso se rechaza
   el ciclo demo y todo lo que cuelga de él (días, ejercicios, sesiones, series).
