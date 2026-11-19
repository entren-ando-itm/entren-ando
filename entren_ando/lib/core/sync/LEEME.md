# core/sync

Dueño: Ángel. Historias: ENT-44 (subir cambios) y ENT-53 (bajar cambios, conflictos y segundo plano).

## Qué hay aquí (ENT-44)

| Archivo | Qué hace |
| --- | --- |
| `motor_sync.dart` | `MotorSync.subirPendientes()`: sube las filas con `pendiente_sync = 1` de cada tabla del usuario, en orden de llaves foráneas, con upsert por id en lotes de 100. Al confirmar pone `pendiente_sync = 0` (solo si la fila no cambió mientras subía). Si Supabase rechaza un lote, prueba fila por fila para que una mala no frene a las demás. |
| `sincronizacion.dart` | `sincronizacionProvider`: corre el motor al abrir la app, cuando vuelve la red (`hayRedProvider` de false a true) y al iniciar sesión. `SincronizacionAutomatica` ya está puesta en `lib/app.dart`. |

Reglas:

* Es la única parte de la app que pone `pendiente_sync = 0`. Los borrados viajan como `eliminado = true`;
  nunca se borran filas locales.
* El helper `EscrituraLocal` (`lib/core/db`) ya marca `pendiente_sync = 1` y `actualizado_en` en cada
  guardado (ENT-78): escribe siempre con él y tu cambio se sube solo.
* No se suben los catálogos. `solicitud_ia` y `evento_pago` los crea el servidor; de `feedback_ia`
  solo se sube `leido`.
* Usa la sesión del usuario en Supabase: la seguridad la da RLS. Nunca la service_role.
* Si la sesión de Supabase no es la del usuario de la app (`usuarioActualIdProvider`), no sube nada.
* Solo sube las filas del usuario: las tablas sin `id_usuario` (días, ejercicios programados,
  alternativas, registros, series) se filtran por su padre (`TablaSync.dueno`).
* Las solicitudes de IA las crea la nube y el celular guarda el mismo id (decisión 13 de la
  bitácora). Si una fila apunta a una solicitud que no existe en Supabase, se rechaza.
* Los datos demo vienen con `pendiente_sync = 0`: para verlos en la nube, Perfil → Modo de prueba →
  Nube y sincronización → "Subir también los datos de prueba".

## Para tu módulo

* Sincronizar ya (por ejemplo, después de algo importante):
  `ref.read(sincronizacionProvider.notifier).sincronizar();`
* Estado para mostrarlo (ENT-54): `ref.watch(sincronizacionProvider)` → `EstadoSync` con `fase`,
  `mensaje`, `ultimaVez`, `subidas` y `rechazadas`.
* Si agregas una tabla del usuario (con acuerdo del equipo), agrégala en `MotorSync.tablas` en su
  lugar; `test/sync_test.dart` revisa el orden contra el esquema.

## Cómo probar

1. Configura `entren_ando/.env` (ver `lib/features/nube/LEEME.md`) y corre
   `flutter run --dart-define-from-file=.env`.
2. Perfil → Modo de prueba → Nube y sincronización → "Iniciar sesión como demo".
3. Modo avión, registra una comida, quita el modo avión. En menos de un minuto aparece en la tabla
   `registro_comida` de Supabase.
