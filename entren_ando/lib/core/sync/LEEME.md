# core/sync

Dueño: Ángel. Historias: ENT-44 (subir cambios) y ENT-53 (bajar cambios, conflictos y segundo plano).

## Qué hay aquí

| Archivo | Qué hace |
| --- | --- |
| `motor_sync.dart` | `MotorSync.sincronizar()`: sube y luego baja. **Subir** (`subirPendientes`, ENT-44): filas con `pendiente_sync = 1` de cada tabla del usuario, en orden de llaves foráneas, upsert por id en lotes de 100; al confirmar pone `pendiente_sync = 0`. **Bajar** (`bajarCambios`, ENT-53): por tabla, lo que cambió en la nube desde la última vez (`actualizado_en`); en conflicto gana el más reciente. |
| `marcas_sync.dart` | `MarcasSync`: hasta dónde se bajó cada tabla y la hora de la última sincronización, en shared_preferences (por usuario). |
| `sincronizacion.dart` | `sincronizacionProvider`: corre el motor al abrir la app, cuando vuelve la red (`hayRedProvider` de false a true) y al iniciar sesión. `SincronizacionAutomatica` ya está puesta en `lib/app.dart`. Si bajó algo, vuelve a leer la base (`ref.invalidate(baseDatosProvider)`) para que las pantallas lo muestren. |
| `segundo_plano.dart` | ENT-97: tarea de Android (paquete `workmanager`) cada 15 minutos con red, aunque la app esté cerrada. Se programa en `main.dart`. |

## Cómo baja los cambios (ENT-53)

* **Gana el más reciente:** si una fila tiene un cambio pendiente en el celular y también cambió en la
  nube, se queda el `actualizado_en` más reciente. Si gana el celular, se sube la próxima vez.
* **Celular nuevo:** sin marcas, baja todo el respaldo del usuario (también al iniciar sesión).
* **Revisión completa una vez al día:** un cambio que otro celular hizo sin red llega a la nube con su
  hora vieja (anterior a la marca). Para no perderlo, cada 24 horas se revisan todas las filas; las
  que ya están iguales no se vuelven a escribir.
* **Regla de los 30 días (RF-10):** la nube rechaza cambiar o borrar sesiones, registros y series de
  un día con más de 30 días (`supabase/ajustes_ent53.sql`, código `EA010`). El celular descarta su
  cambio y se queda con la versión de la nube. Subir por primera vez un entrenamiento viejo (por
  ejemplo, después de muchos días sin red) sí se permite: es un dato guardado en su día, no una
  edición.
* Lo que baja se guarda con `INSERT ... ON CONFLICT DO UPDATE`, nunca con `REPLACE` (borraría y
  dispararía los `ON DELETE CASCADE`), y llega con `pendiente_sync = 0`.

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
3. **Subir:** modo avión, registra una comida, quita el modo avión. En menos de un minuto aparece en
   la tabla `registro_comida` de Supabase.
4. **Bajar:** cambia esa comida en el panel de Supabase (Table Editor) y pon `actualizado_en` en
   `now()`. Toca "Sincronizar ahora": el cambio aparece en la pestaña Comidas.
5. **Conflicto:** en modo avión cambia la comida en el celular; luego cámbiala en Supabase. Quita el
   modo avión: se queda el cambio más reciente.
6. **Segundo plano:** cierra la app con red y espera unos 15 minutos (Android decide el momento
   exacto). Cambia algo en Supabase antes: al abrir la app sin red, el cambio ya está. En la consola
   (`flutter logs`) sale "Entren-Ando (segundo plano): … subidas, … bajadas".
