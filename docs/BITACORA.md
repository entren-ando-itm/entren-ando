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
13. **Ids de las solicitudes de IA:** las solicitudes de IA las crea la nube y el celular guarda el
    mismo id (`id_solicitud`), igual que con el usuario. Así el ciclo generado con IA, la comida
    escaneada y el feedback apuntan a una solicitud que sí existe en Supabase al sincronizar
    (ENT-44; lo usan ENT-101 de Axel y ENT-109). Las del usuario demo las crea
    `supabase/ajustes_ent44.sql`.
14. **Sesión (ENT-41):** sin sesión la app abre en el inicio de sesión (`/entrar`); en modo debug
    hay "Entrar como demo" para trabajar sin internet ni cuenta. La contraseña nunca se guarda en
    el celular: la sesión la guarda `supabase_flutter`, así que después se entra sin red. Si el
    correo o la contraseña están mal, el mensaje es el mismo en los dos casos.
15. **Aviso de privacidad aceptado (ENT-42):** su versión y fecha van en el `user_metadata` de
    Supabase Auth (`aviso_version`, `aviso_aceptado_en`), no en una tabla. La app trae una copia en
    `assets/legal/aviso_privacidad.md` para leerlo sin red; si cambia el aviso, se copia de nuevo y
    se sube `Cuenta.versionAviso` (una prueba lo revisa).
16. **Cerrar sesión (ENT-43):** por ahora NO borra los datos del celular, porque todavía no existe
    la bajada desde la nube (ENT-53) y el usuario vería su app vacía al volver. Si hay cambios sin
    subir, avisa y deja subirlos antes de salir.
17. **Regla de los 30 días en la nube (RF-10, ENT-53):** Supabase rechaza **cambiar o borrar**
    sesiones, registros y series de un día con más de 30 días (código `EA010`); el celular se queda con
    la versión de la nube. **Subir por primera vez** un entrenamiento viejo sí se permite: se guardó en
    su día sin red; también deja subir los datos de prueba y bajar el respaldo a un celular nuevo.
18. **Bajar cambios (ENT-53):** por tabla, desde la última marca (`actualizado_en`, en
    shared_preferences); en conflicto gana el más reciente; una vez al día se revisa todo, porque un
    cambio hecho sin red llega a la nube con su hora vieja.

---

## Pendientes técnicos

Cosas detectadas que todavía no se arreglan. Quien la resuelva, la tacha (~~así~~) y pone su PR.

* ~~**Zona horaria de Supabase (para ENT-44, Ángel).**~~ Resuelto en PR #11: `ALTER DATABASE postgres SET
  timezone TO 'America/Mexico_City'` en `supabase/esquema.sql` y `supabase/ajustes_ent44.sql`.
* **`feedback_ia` en Supabase (para ENT-69, Axel / Ángel).** La política de UPDATE deja cambiar el
  texto del mensaje, no solo `leido`. Se cierra permitiendo actualizar solo esa columna.
* **Ramas viejas en GitHub.** Las ramas de los PR #1 a #6 ya están integradas y se pueden borrar
  (GitHub → Branches).
* **Hoy con varios ciclos activos (para ENT-20, Paola).** `hoy_repositorio.dart` toma el ciclo
  activo con `LIMIT 1` sin orden; con Premium puede haber varios y ENT-47 pide el de `fecha_inicio`
  más reciente. Arreglo: usar `RutinasRepositorio.consultaCicloParaHoy` (o agregar
  `ORDER BY fecha_inicio DESC, creado_en DESC`). Con el plan Gratuito no se nota.
* **Borrar los datos al cerrar sesión (para ENT-53, Ángel / Pablo).** ENT-43 lo pide, pero se activa
  cuando exista la bajada desde la nube (decisión 16).

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
* **Después de `flutter upgrade` falla Gradle ("JVM 17 or later" o "Android Gradle Plugin version ... is lower"):**
  usa el Java de Android Studio con `flutter config --jdk-dir "C:\Program Files\Android\Android Studio\jbr"`,
  reabre Git Bash y corre `flutter clean`. El proyecto usa Android Gradle Plugin 9.1.1 y Gradle 9.5.0 (PR #13, ENT-22).
* **La app no sincroniza (sale "Nube apagada"):** falta `entren_ando/.env` o correr con
  `flutter run --dart-define-from-file=.env`. Copia `.env.example` y llénalo (ver
  `lib/features/nube/LEEME.md`).
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
| `baseDatosProvider`, `usuarioActualIdProvider` | `lib/core/db` | La única conexión a la base y el usuario que inició sesión (null si nadie ha entrado) |
| `sesionActualProvider` (correo y si es el demo) y `Cuenta.cerrarSesion()` | `lib/core/db/usuario_actual.dart`, `lib/features/cuenta/sesion_cuenta.dart` | Quién usa la app; al cambiar la sesión, go_router manda a `/entrar` o a Hoy |
| Rutas `/entrar`, `/registro`, `/aviso` y `/perfil/cuenta` | `lib/app.dart` | Inicio de sesión, crear cuenta, aviso de privacidad y Cuenta (cerrar sesión) |
| `EscrituraLocal` (`insertar`, `actualizar`, `marcarEliminado`) | `lib/core/db/escritura_local.dart` | Toda escritura: llena fechas, UUID y `pendiente_sync` |
| `Fechas.hoy()`, `Fechas.ahoraIso()`, `Fechas.hoyComoFecha()` | `lib/core/db/fechas.dart` | Fechas en hora de CDMX |
| `import 'package:entren_ando/core/diseno.dart'` | `lib/core/tema`, `lib/core/componentes` | Tema, medidas y todos los componentes |
| `hayRedProvider` y `ref.read(hayRedProvider.notifier).revisar()` | `lib/core/conectividad/conectividad.dart` | Saber si hay internet de verdad y reaccionar cuando vuelve la red (ENT-44) |
| `BotonConRed` | `lib/core/conectividad/boton_con_red.dart` | Botones que necesitan internet |
| `ClienteSupabase.cliente` | `lib/features/nube/cliente_supabase.dart` | El cliente de Supabase (null si no hay `.env`). ENT-41 inicia sesión con él |
| `sincronizacionProvider` y `.notifier.sincronizar()` | `lib/core/sync/sincronizacion.dart` | Estado de la sincronización (`ultimaVez`, `bajadas`, `descartadas`) y sincronizar ya: sube y baja (ENT-54) |
| `MarcasSync` | `lib/core/sync/marcas_sync.dart` | Hora de la última sincronización por usuario (también la de segundo plano) |
| `IconoSincronizacion` | `lib/features/nube/indicador_sync.dart` | Icono pequeño con el estado del respaldo (ENT-54) |
| `AvisoSinRed` | ya puesto en `lib/app.dart` | No lo agregues en tus pantallas |
| `CatalogoRepositorio.nombreVisible` y `joinAlias` | `lib/features/perfil/catalogo/catalogo_repositorio.dart` | Nombre del ejercicio con el alias del usuario (lo necesitan ENT-39 y ENT-49) |
| `resumenPerfilProvider`, `perfilRepositorioProvider` | `lib/features/perfil/perfil_repositorio.dart` | Objetivo, nivel, días por semana, última medición y equipo (lo necesita la IA, ENT-58) |
| `diaDeHoyProvider` (`DiaDeHoy`, `EjercicioDelDia`) | `lib/features/entrenamiento/hoy_repositorio.dart` | Rutina de hoy con alias, descanso y avance; también los días que vienen |
| `TemporizadorFlotante`, `temporizadorProvider` | `lib/features/entrenamiento/temporizador/` | Descanso o trabajo con hora de fin (lo usa ENT-49) |
| `BitacoraRepositorio`, `ejercicioBitacoraProvider`, `sesionDeHoyProvider` | `lib/features/entrenamiento/bitacora/` | Series de hoy de un ejercicio (guardar, quitar y precarga), terminar ejercicio, estado y comentario de la sesión; ruta `/hoy/ejercicio/:idProgramado` |
| Rutas `/perfil/catalogo`, `/perfil/editar`, `/perfil/mediciones`, `/perfil/equipo` | `lib/app.dart` | Abrir esas pantallas con `context.push(...)` |
| `rutinasRepositorioProvider`, `RutinasRepositorio.consultaCicloParaHoy` y `consultaEjerciciosDelDia` | `lib/features/rutinas/rutinas_repositorio.dart` | Ciclos, días y ejercicios programados; el ciclo que usa Hoy (lo necesita ENT-58 para guardar la rutina de la IA) |
| Rutas `/perfil/ciclos`, `/perfil/ciclos/:idCiclo` y `/perfil/ciclos/:idCiclo/dia/:idDia` | `lib/app.dart` | Abrir Mis ciclos, un ciclo o el editor de un día |
| `alternativasRepositorioProvider` y `AlternativasRepositorio.consultaAlternativas` | `lib/features/rutinas/alternativas/alternativas_repositorio.dart` | Alternativas de un ejercicio por prioridad, con alias (para cambiar de ejercicio en la sesión, RF-04) |

---

## Historial por módulo

Cada quien agrega su entrada **arriba** de su sección (la más nueva primero).

### Pablo · base, diseño y cuenta (`lib/core/db`, `lib/core/tema`, `lib/core/componentes`, `lib/features/cuenta`)

* **2026-11-18 · ENT-41, ENT-42 y ENT-43 · Pablo · PR #18**
  Qué: inicio de sesión, crear cuenta y recuperar contraseña con Supabase Auth (usa
  `ClienteSupabase` de Ángel); la app abre en `/entrar` sin sesión y entra sin red si ya había
  sesión; aviso de privacidad dentro de la app y casilla obligatoria al registrarse; Perfil →
  "Cuenta y privacidad" con correo, plan y cerrar sesión (avisa si hay cambios sin subir).
  `usuarioActualIdProvider` ya devuelve el usuario que inició sesión.
  Para el siguiente: en debug usa "Entrar como demo". Para cuentas reales corre con
  `flutter run --dart-define-from-file=.env` y apaga "Confirm email" en Supabase → Authentication.
  Toqué una línea de Perfil (Axel): la fila "Cuenta y privacidad".

* **2026-11-17 · ENT-22 · Pablo · PR #13**
  Qué: Android Gradle Plugin 9.1.0 → 9.1.1 y Gradle 9.3.1 → 9.5.0, porque el Flutter nuevo pide
  mínimo AGP 9.1.1 y ya no compilaba.
  Para el siguiente: después de `flutter upgrade`, revisa la trampa de Gradle en "Trampas conocidas".

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

* **2026-11-23 · ENT-56 · Ángel · PR #22**
  Qué: `docs/reportes/sprint3.md`, corte al 23 de noviembre (día 1): estado y puntos de cada historia
  (28 comprometidos, 7 en revisión) e impedimentos.
  Para el siguiente: al cierre del sprint se completan puntos terminados, burndown y retrospectiva.

* **2026-11-23 · ENT-55 · Ángel · PR #21**
  * Qué cambió: `docs/pruebas/cifrado_y_sync.md` con las 6 pruebas de cifrado y sincronización y su
    evidencia. Las pruebas 2 a 6 pasan en el simulador `docs/pruebas/simulador/` (PostgreSQL 16 que imita
    Supabase con nuestro esquema, RLS y los ajustes de ENT-44 y ENT-53). Faltan las capturas del
    emulador (prueba 1 de cifrado y prueba 2 en modo avión).
  * Qué debe saber el siguiente: para probar cambios del servidor sin tocar el Supabase del equipo,
    corre `bash nube_limpia.sh` y `python3 pruebas55.py` (Linux o WSL). Los scripts leen las tablas de
    `motor_sync.dart`, así que si agregas una tabla allí también entra en la prueba.

* **2026-11-23 · ENT-54 · Ángel · PR #20**
  Qué: Perfil → Ajustes → "Respaldo en la nube" con `IconoSincronizacion` (sincronizado, pendiente con
  número, sincronizando o error); su pantalla muestra la última sincronización y "Sincronizar ahora".
  Por qué / decisión: pantalla nueva armada con los componentes de Ajustes (no hay PNG); la fila va
  antes de "Tema" para no chocar con "Cuenta y privacidad" (PR #18).
  Para el siguiente: el icono se puede poner en otras pantallas (`IconoSincronizacion()`). Depende
  del PR #19 (ENT-53).

* **2026-11-23 · ENT-53 · Ángel · PR #19**
  Qué: bajar cambios de la nube (gana el `actualizado_en` más reciente), celular nuevo baja todo,
  sincronización cada 15 minutos en segundo plano (`workmanager`) y trigger de 30 días en Supabase
  (`supabase/ajustes_ent53.sql`, código `EA010`).
  Por qué / decisión: decisiones 17 y 18. Probado contra PostgreSQL 16 con RLS: cambio en la nube,
  los dos lados de un conflicto, rechazo de 30 días y celular nuevo (503 de 503 filas).
  Para el siguiente: correr `ajustes_ent53.sql` en Supabase. ENT-54 lee `EstadoSync.ultimaVez`,
  `bajadas` y `descartadas`. Paquetes nuevos: `shared_preferences` y `workmanager`.

* **2026-11-18 · ENT-44 · Ángel · PR #11**
  Qué: `MotorSync` sube lo pendiente a Supabase (upsert por id, lotes de 100, orden de llaves
  foráneas) al abrir la app, al volver la red y al iniciar sesión. Cliente de Supabase con `.env` y
  pantalla de prueba para entrar como demo.
  Las tablas hijas (días, ejercicios, registros, series) se filtran por su dueño.
  Por qué / decisión: el demo de Supabase usa el mismo id que el del celular y
  `supabase/ajustes_ent44.sql` crea sus 3 solicitudes de IA (decisión 13); con eso suben todas las
  filas del demo (antes solo 19, revisión de Pablo). Probado contra PostgreSQL 16 con RLS: 532 de
  532 filas, sin duplicar al repetir.
  Para el siguiente: corre la app con `--dart-define-from-file=.env`; ENT-41 debe iniciar sesión
  con `ClienteSupabase.cliente` y ENT-54 lee `sincronizacionProvider`. Quita `DEMO_PASSWORD` del
  `.env` antes de armar el APK de entrega (ENT-62).

* **2026-11-17 · ENT-46 · Ángel · PR #12**
  Qué: `docs/reportes/sprint2.md`, corte al 17 de noviembre (estado de cada historia e impedimentos).
  Para el siguiente: al cierre del sprint se completan puntos, burndown y retrospectiva.

* **2026-11-17 · ENT-45 · Ángel · PR #10**
  Qué: pestaña Comidas con total del día (calorías y macros con `SUM` por fecha de CDMX),
  "Registrar a mano" en una hoja y editar o borrar al tocar una comida. Funciona en modo avión.
  Por qué / decisión: sin meta calórica (no está en la ERS); borrar pide un segundo toque en vez
  de un diálogo.
  Para el siguiente: ENT-65 le pone la acción al botón "Escanear con cámara" (ya está con
  `BotonConRed`); detalles en `lib/features/nutricion/LEEME.md`.

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

* **2026-11-17 · ENT-48 (ENT-86) · Axel · PR #17**
  Qué: alternativas por ejercicio programado (Editor del día → tocar ejercicio → Alternativas):
  hasta 3 del catálogo con prioridad 1 a 3, sin repetir ni usar el mismo ejercicio. El selector
  muestra por defecto el mismo grupo muscular. Subir, bajar y quitar renumeran la prioridad.
  Por qué / decisión: quitar es `eliminado = 1`; en ciclos archivados se ven en solo lectura.
  Para el siguiente: ENT-58 guarda las alternativas de la IA con prioridad 1, 2, 3 y aquí se
  editan. RF-04 (cambiar en la sesión) las lee con `AlternativasRepositorio.consultaAlternativas`.

* **2026-11-17 · ENT-47 (ENT-83, ENT-84, ENT-85) · Axel · PR #15**
  Qué: Perfil → Mis ciclos: crear ciclos con nombre y fechas, sus 7 días (rutina o descanso) y el
  editor de cada día (agregar, quitar y reordenar ejercicios del catálogo; series, reps, peso,
  descanso y trabajo). Archivar y reactivar; un ciclo archivado se ve en solo lectura.
  Por qué / decisión: el límite sale de `plan.max_ciclos_activos`; al llegar a él se ofrece
  archivar el ciclo actual o ver Premium (por ahora avisa "muy pronto" hasta ENT-52). Las fechas
  se escriben dd/mm/aaaa porque la app no tiene el calendario de Android en español.
  Para el siguiente: Hoy debe tomar el ciclo de `RutinasRepositorio.consultaCicloParaHoy` (ver
  "Pendientes técnicos"). Quitar un ejercicio también marca sus alternativas (ENT-48).

* **2026-11-10 · ENT-18 · Axel · PR #4 (integrado con #3)**
  Qué: editar perfil (objetivo, nivel, días, lesiones), mediciones biométricas y equipo que tiene
  el usuario, con validaciones y pruebas.
  Para el siguiente: `resumenPerfilProvider` ya da lo que necesita la IA para la rutina inicial.

* **2026-11-10 · ENT-17 · Axel · PR #3**
  Qué: catálogo con búsqueda (por nombre oficial o alias), filtros por grupo y equipo, y alias por
  usuario (borrar el alias es `eliminado = 1`).
  Para el siguiente: usa `CatalogoRepositorio.nombreVisible` y `joinAlias` para mostrar nombres.

### Paola · entrenamiento del día y calendario (`lib/features/entrenamiento`, `lib/features/calendario`)

* **2026-11-17 · ENT-50 (ENT-90) · Paola · PR #(pendiente)**
  Qué: botón "Terminar ejercicio" en la pantalla del ejercicio (marca `registro_ejercicio.completado`
  aunque falten series y regresa a Hoy; "Volver a abrir" lo desmarca). La marca "Sigue" de Hoy ya
  avanza. Tarjeta "Sesión completa / parcial" en Hoy con el comentario libre del día.
  Por qué / decisión: `BitacoraRepositorio._recalcularSesion` corre en la misma transacción cada vez
  que cambia una serie o un ejercicio: 'completa' si todos los ejercicios del día están completados
  con sus series objetivo; si no, 'parcial' (regla pura `estadoSesion`, con pruebas). `hora_inicio`
  se guarda al crear la sesión y `hora_fin` con el último cambio (formato 'HH:MM:SS').
  Para el siguiente: el calendario (ENT-60) ya puede leer `sesion_entrenamiento.estado` de los días
  entrenados en la app. El comentario se guarda en `sesion_entrenamiento.comentario` para la IA (ENT-68).

* **2026-11-17 · ENT-49 (ENT-87, ENT-88, ENT-89) · Paola · PR #(pendiente)**
  Qué: bitácora rápida en `/hoy/ejercicio/:idProgramado` (`03_ejercicio.png`). Series precargadas
  de la última vez del mismo `id_ejercicio` o de los objetivos; 1 toque guarda la serie y empieza el
  descanso; tocar los números abre + y −. `BitacoraRepositorio` crea la sesión del día (una por
  usuario y fecha, 'parcial'), el `registro_ejercicio` y cada `serie` en una transacción.
  También los pendientes de la revisión del PR #9: el aviso del temporizador hace programar y
  cancelar en orden (ya no suena si pausas o saltas al empezar), el permiso de alarmas exactas ya
  no abre Ajustes solo (la tarjeta muestra un aviso con "Activar"), tiempo como "01:12" y pruebas
  en `test/temporizador_test.dart` y `test/bitacora_test.dart`. Se quitó "Probar temporizador".
  Por qué / decisión: el descanso empieza solo al marcar la serie (1 toque; el diseño dice
  "Empezó al marcar la serie 2"). Una serie se actualiza si ya existe (índice único
  `id_registro, numero_serie`) y quitar el ✓ la marca eliminada.
  Para el siguiente: "Terminar ejercicio" y `registro_ejercicio.completado` son de ENT-50; hasta
  entonces la marca "Sigue" de Hoy no avanza. "Cambiar solo hoy" es ENT-59. Se tocó
  `lib/app.dart` solo para agregar la ruta hija de `/hoy`.

* **2026-11-11 · ENT-19 (ENT-37, ENT-38) · Paola · PR #9**
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
