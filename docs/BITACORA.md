# Bitácora de Entren-Ando

Memoria compartida del equipo y de las IA: qué ya está hecho, qué se decidió y por qué, y qué trampas
hay que evitar. Git dice **qué** cambió y Jira **qué falta**; aquí va lo que no está en ninguno de los
dos: **el porqué y lo que el siguiente debe saber**.

## Cómo se usa (léelo antes de tu primer cambio)

* **Antes de empezar:** la IA lee este archivo completo, después AGENTS.md y el `LEEME.md` de tu
  módulo.
* **En cada Pull Request:** agrega tu entrada **arriba de tu sección** en "Historial por módulo"
  (formato abajo). Va en el mismo PR que tu código, no en uno aparte.
* **Solo tocas tu sección.** Así dos PR no editan las mismas líneas y no hay conflictos. Si
  descubres una trampa o tomas una decisión que afecta a otros, agrégala también en "Decisiones" o
  en "Trampas conocidas", al final de esa lista.
* **"Estado general"** lo actualiza Pablo (o quien haga el merge) al cerrar el día o el sprint.
* **Corto:** 3 a 5 líneas por entrada. Nada de pegar código; para eso están el PR y el `LEEME.md`.
* Si GitHub marca conflicto en este archivo: **Resolve conflicts** → deja las dos entradas → Mark as
  resolved.

Formato de una entrada:

```markdown
* **2026-11-12 · ENT-39 · Paola · PR #7**
  Qué: HoyRepositorio lee la rutina del día con el alias del usuario.
  Por qué / decisión: …
  Para el siguiente: …
```

---

## Estado general

*Actualizado: martes 11 de noviembre de 2026.*

**Sprint 1 (9 al 15 de noviembre):** 25 de 31 tarjetas hechas. Faltan las de Paola: ENT-19
(temporizador) y ENT-20 (vista del día), con sus subtareas ENT-37 a ENT-40. ENT-20 está en curso.

**Ya está en `main`:**

| Historia | Qué quedó | Dueño | PR |
| --- | --- | --- | --- |
| ENT-11 | App Flutter, carpetas, navegación (go_router), base SQLite cifrada con esquema, catálogo y usuario demo | Pablo | (base) |
| ENT-12 | Tema claro/oscuro, Barlow, componentes en `lib/core/componentes` y los PNG de `docs/pantallas` | Pablo | #1 |
| ENT-13 / ENT-27 | `supabase/esquema.sql` (20 tablas) y `supabase/politicas.sql` (RLS: cada usuario solo ve lo suyo) | Ángel | #2 |
| ENT-14 | `hayRedProvider`, banda "Sin conexión" en toda la app y `BotonConRed` | Ángel | #6 |
| ENT-15 | `docs/aviso_privacidad.md` v1.0 (LFPDPPP 2025) | Ángel | #5 |
| ENT-17 | Catálogo de ejercicios con búsqueda, filtros y alias | Axel | #3 |
| ENT-18 | Perfil: objetivos, mediciones y equipo | Axel | #4 → #3 |

**PR abiertos:** ninguno.

**Sigue (Sprint 2, según el backlog):** ENT-41 a ENT-43 (cuenta, Pablo), ENT-44 y ENT-45
(sincronización y comidas, Ángel), ENT-47 y ENT-48 (ciclos y alternativas, Axel), ENT-49 y ENT-50
(bitácora de series, Paola).

**Fechas:** 4 sprints de una semana (9 nov a 6 dic). La ERS debe funcionar completa antes del 11 de
diciembre de 2026. La maestra revisa avances al azar en la hora de clase (lunes a jueves).

---

## Decisiones

Lo que ya se acordó. La IA no debe proponer lo contrario sin hablarlo en el daily.

1. **Base local:** `sqflite_sqlcipher` con SQL a mano (no drift ni otro ORM). La llave vive en el
   Keystore con `flutter_secure_storage`. Estado con Riverpod y rutas con go_router.
2. **Ids y borrado:** las tablas del usuario usan UUID creado en el celular; nunca se usa DELETE,
   se marca `eliminado = 1`. Solo el motor de `lib/core/sync` pone `pendiente_sync = 0`. En Supabase
   un trigger siempre guarda `pendiente_sync = false`.
3. **Catálogos** (`plan`, `equipo`, `ejercicio`): id entero fijo, igual en el celular y en Supabase.
   Son de solo lectura en los dos lados.
4. **Fechas:** ISO 8601 con hora de Ciudad de México (`-06:00`), con `Fechas.hoy()` y
   `Fechas.ahoraIso()`. Pesos en kg.
5. **IA:** siempre a través de una Edge Function de Supabase; la llave `GEMINI_API_KEY` es un secreto
   de Supabase (ENT-28), nunca va en la app. A la IA se manda `id_ejercicio` y `nombre_oficial`,
   **nunca el alias** del usuario (ENT-17).
6. **Freemium:** los límites se leen de la tabla `plan` (NULL = ilimitado). Premium es simulado; en
   Supabase cada usuario puede cambiar su propio `id_plan` y se aceptó así porque no hay cobro real.
7. **Solicitudes de IA:** la app no puede crear filas en `solicitud_ia` ni en `feedback_ia` en la
   nube; las crea la Edge Function. Así nadie se salta el límite de 3 escaneos al día.
8. **Sin red:** lo que necesita internet (IA, cámara, inicio de sesión) usa `BotonConRed`; la
   bitácora, el temporizador y el registro manual de comidas nunca se bloquean.
9. **Diseño:** antes de programar una pantalla se abre su PNG en `docs/pantallas/` y se arma con los
   componentes de `lib/core/componentes`. Pantalla nueva → avisarle a Pablo antes del PR.
10. **Git:** una rama por historia (`ENT-xx-descripcion`), PR hacia `main`, 1 aprobación de otra
    persona y nadie aprueba su propio PR. `main` está protegida. Un PR por historia, siempre hacia
    `main` (no PR hacia la rama de otra historia).
11. **Cuentas:** cada quien sube su código y abre sus PR con **su** cuenta de GitHub. Los cuatro son
    miembros de la organización `entren-ando-itm` y admin del repositorio.
12. **Aviso de privacidad:** versión 1.0 del 10 de noviembre de 2026; correo de contacto
    l24120371@morelia.tecnm.mx. ENT-42 guarda la versión aceptada (ENT-76).

---

## Pendientes técnicos

Cosas detectadas que todavía no se arreglan. Quien la resuelva, la tacha (~~así~~) y pone su PR.

* **Zona horaria de Supabase (para ENT-44, Ángel).** Supabase trabaja en UTC: una comida registrada
  a las 23:30 del día 9 regresa como "10 de noviembre 05:30" y cambiaría de día. Arreglo:
  `ALTER DATABASE postgres SET timezone TO 'America/Mexico_City';` en `supabase/esquema.sql`, o
  convertir a hora de CDMX al bajar los datos.
* **`feedback_ia` en Supabase (para ENT-69, Axel / Ángel).** La política de UPDATE deja cambiar el
  texto del mensaje, no solo `leido`. Se cierra permitiendo actualizar solo esa columna.
* **Ramas viejas en GitHub.** Las ramas de los PR #1 a #6 ya están integradas y se pueden borrar
  (GitHub → Branches).

---

## Trampas conocidas

Problemas que ya le pasaron a alguien, con su solución.

* **Emulador en negro o muy lento:** Pixel 4 con API 34, Graphics en **Software**, RAM 2048 MB y VM
  heap 512 MB.
* **Flutter no ve el emulador ("offline" o "No supported devices"):** cierra `qemu-system-x86_64`
  en el Administrador de tareas y enciende el Pixel 4 con **Cold Boot Now**.
* **Error de NDK al compilar:** instalar NDK (Side by side) **28.2.13676358** exacta en el SDK
  Manager.
* **Error de compileSdk:** el proyecto usa `compileSdk = 37` y
  `android.suppressUnsupportedCompileSdk=37` en `android/gradle.properties`. No los cambies.
* **Cambié el esquema y la app truena:** desinstala la app del emulador para que la base se cree de
  nuevo (o sube `BaseDatos.version` con su migración, con acuerdo del equipo).
* **Los datos demo tienen fechas viejas:** Perfil → "Reiniciar datos de prueba" (solo en debug).
* **El PR sale a nombre de otra persona:** pasa si usas la cuenta compartida de Claude o un Git
  configurado con otro nombre. Revisa `git config user.name` y `user.email`, y conecta Claude con tu
  propia cuenta de GitHub.
* **"Review required" y no deja hacer merge:** falta que alguien que no sea el autor dé **Files
  changed → Review changes → Approve**.
* **No borrar al quitar un alias o equipo:** `EscrituraLocal.insertar` en `usuario_ejercicio` y
  `usuario_equipo` reactiva la fila si existía con `eliminado = 1`.

---

## Contratos entre módulos

Lo que un módulo ya ofrece a los demás. Úsalo en vez de programarlo otra vez.

| Qué | Dónde | Para qué |
| --- | --- | --- |
| `baseDatosProvider`, `usuarioActualIdProvider` | `lib/core/db` | La única conexión a la base y el usuario actual (demo en debug; ENT-41 lo cambia por el de la sesión) |
| `EscrituraLocal` (`insertar`, `actualizar`, `marcarEliminado`) | `lib/core/db/escritura_local.dart` | Toda escritura: llena fechas, UUID y `pendiente_sync` |
| `Fechas.hoy()`, `Fechas.ahoraIso()`, `Fechas.hoyComoFecha()` | `lib/core/db/fechas.dart` | Fechas en hora de CDMX |
| `import 'package:entren_ando/core/diseno.dart'` | `lib/core/tema`, `lib/core/componentes` | Tema, medidas y todos los componentes |
| `hayRedProvider` y `ref.read(hayRedProvider.notifier).revisar()` | `lib/core/conectividad/conectividad.dart` | Saber si hay internet de verdad y reaccionar cuando vuelve la red (ENT-44) |
| `BotonConRed` | `lib/core/conectividad/boton_con_red.dart` | Botones que necesitan internet |
| `AvisoSinRed` | ya puesto en `lib/app.dart` | No lo agregues en tus pantallas |
| `CatalogoRepositorio.nombreVisible` y `joinAlias` | `lib/features/perfil/catalogo/catalogo_repositorio.dart` | Nombre del ejercicio con el alias del usuario (lo necesitan ENT-39 y ENT-49) |
| `resumenPerfilProvider`, `perfilRepositorioProvider` | `lib/features/perfil/perfil_repositorio.dart` | Objetivo, nivel, días por semana, última medición y equipo (lo necesita la IA, ENT-58) |
| `diaDeHoyProvider` (`DiaDeHoy`, `EjercicioDelDia`) | `lib/features/entrenamiento/hoy_repositorio.dart` | Rutina de hoy con alias, descanso y avance; también los días que vienen |
| `TemporizadorFlotante`, `temporizadorProvider` | `lib/features/entrenamiento/temporizador/` | Descanso o trabajo con hora de fin (lo usa ENT-49) |
| Rutas `/perfil/catalogo`, `/perfil/editar`, `/perfil/mediciones`, `/perfil/equipo` | `lib/app.dart` | Abrir esas pantallas con `context.push(...)` |

---

## Historial por módulo

Cada quien agrega su entrada **arriba** de su sección (la más nueva primero).

### Pablo · base, diseño y cuenta (`lib/core/db`, `lib/core/tema`, `lib/core/componentes`, `lib/features/cuenta`)

* **2026-11-11 · ENT-24 · Pablo · bitácora**
  Qué: se crea esta bitácora y la regla en AGENTS.md y CLAUDE.md para mantenerla al día.
  Para el siguiente: agrega tu entrada en tu sección en cada PR.

* **2026-11-10 · ENT-12 · Pablo · PR #1**
  Qué: los 18 PNG de las pantallas aprobadas en `docs/pantallas/` (claro y oscuro) y las reglas
  para diseñar en AGENTS.md.
  Para el siguiente: si tu pantalla no tiene PNG, toma la más parecida y avísale a Pablo.

* **2026-11-09 · ENT-11 y ENT-12 · Pablo · base del proyecto**
  Qué: app Flutter, base cifrada con las 20 tablas, catálogo (60 ejercicios, 18 equipos, 2 planes),
  usuario demo con 45 días de sesiones, tema claro/oscuro con Barlow y los componentes.
  Por qué: que cada quien pueda trabajar su módulo sin esperar a los demás.

### Ángel · nube, red, sincronización y comidas (`supabase/`, `lib/core/conectividad`, `lib/core/sync`, `lib/features/nube`, `lib/features/nutricion`)

* **2026-11-10 · ENT-14 · Ángel · PR #6**
  Qué: `hayRedProvider` revisa internet real (no solo Wi-Fi) y reintenta a los 10, 20, 40 y 60 s;
  banda "Sin conexión" en toda la app y `BotonConRed`.
  Para el siguiente: ENT-44 debe escuchar `hayRedProvider` para subir pendientes al volver la red.

* **2026-11-10 · ENT-15 · Ángel · PR #5**
  Qué: aviso de privacidad v1.0 según la LFPDPPP 2025, con datos de salud como sensibles y
  consentimiento expreso con casilla.
  Para el siguiente: ENT-42 muestra este texto y guarda la versión aceptada.

* **2026-11-10 · ENT-13 / ENT-27 · Ángel · PR #2**
  Qué: las 20 tablas en Supabase con los mismos nombres y columnas que el celular, y RLS para que
  cada usuario solo vea lo suyo. Se probó con dos usuarios en una copia de PostgreSQL 16.
  Pendiente: zona horaria de CDMX y UPDATE de `feedback_ia` (ver "Pendientes técnicos").

### Axel · perfil, catálogo, rutinas e IA (`lib/features/perfil`, `lib/features/rutinas`, `lib/features/ia`)

* **2026-11-10 · ENT-18 · Axel · PR #4 (integrado con #3)**
  Qué: editar perfil (objetivo, nivel, días, lesiones), mediciones biométricas y equipo que tiene
  el usuario, con validaciones y pruebas.
  Para el siguiente: `resumenPerfilProvider` ya da lo que necesita la IA para la rutina inicial.

* **2026-11-10 · ENT-17 · Axel · PR #3**
  Qué: catálogo con búsqueda (por nombre oficial o alias), filtros por grupo y equipo, y alias por
  usuario (borrar el alias es `eliminado = 1`).
  Para el siguiente: usa `CatalogoRepositorio.nombreVisible` y `joinAlias` para mostrar nombres.

### Paola · entrenamiento del día y calendario (`lib/features/entrenamiento`, `lib/features/calendario`)

* **2026-11-11 · ENT-19 (ENT-37, ENT-38) · Paola · PR #(pendiente)**
  Qué: temporizador de descanso y trabajo (`temporizadorProvider`, `TemporizadorFlotante`) con −15 s,
  +15 s, Reiniciar y Saltar, y notificación local con sonido y vibración a la hora de fin.
  Por qué / decisión: guarda la hora de fin en vez de contar segundos (no se desfasa en segundo
  plano). Se agregaron permisos y receptores en AndroidManifest y se declaró `timezone` en
  pubspec (ya venía con flutter_local_notifications, misma versión).
  Para el siguiente: sin el permiso de alarmas exactas (Android 14+) el aviso puede llegar unos
  segundos tarde. El botón "Probar temporizador" de Hoy (solo debug) se quita en ENT-49.

* **2026-11-11 · ENT-20 (ENT-39, ENT-40) · Paola · PR #8**
  Qué: pestaña Hoy como en `02_hoy.png`: encabezado, ejercicios con estado (hecho, "Sigue",
  pendiente), botón "Seguir entrenando" y franjas de los días que vienen.
  Por qué / decisión: si hoy no está en la rutina se muestra como descanso. El estado de cada
  ejercicio se lee de `registro_ejercicio.completado` de la sesión de hoy.
  Para el siguiente: el botón "Seguir entrenando" se conecta en ENT-49.
