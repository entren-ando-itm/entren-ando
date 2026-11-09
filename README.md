# Entren-Ando

App Android offline-first de entrenamiento de fuerza y nutrición. Proyecto escolar de
Ingeniería de Software, Tecnológico de Morelia.

Equipo: Pablo César Gallegos Valencia (Product Owner), Ángel Pedraza Contreras (Scrum Master),
Julio Axel Villanueva Aguado y Paola García García (Development Team).

## Cómo empezar (una sola vez)

Todos los comandos van en **Git Bash** (viene con Git para Windows).

### 1. Instala las herramientas

1. **Git para Windows** (git-scm.com), con las opciones por defecto. Luego dile a Git quién eres,
   con el correo de tu cuenta de GitHub:

   ```bash
   git config --global user.name "Tu nombre"
   git config --global user.email "tu-correo-de-github"
   ```

2. **Flutter (versión estable):** descarga el zip para Windows de docs.flutter.dev y descomprímelo
   en `C:\dev\flutter` (sin espacios ni acentos en la ruta y fuera de OneDrive). Agrega
   `C:\dev\flutter\bin` al `Path` de tu usuario (Windows → "Editar las variables de entorno de tu
   cuenta"). Cierra y abre Git Bash, y revisa con `flutter --version`.
3. **Android Studio**, con el asistente "Standard". Después, en la pantalla de inicio:
   * **More Actions → SDK Manager → SDK Platforms:** marca **API 37**.
   * **More Actions → SDK Manager → SDK Tools:** marca **Show Package Details** (abajo a la
     derecha) y deja marcados Android SDK Command-line Tools, Android SDK Build-Tools, Android SDK
     Platform-Tools, Android Emulator, **NDK (Side by side) 28.2.13676358** (esa versión exacta) y
     **CMake**. Dale Apply.
   * **More Actions → Plugins:** instala **Flutter** (te pide también Dart).
4. **Emulador:** More Actions → Virtual Device Manager → Create device → **Pixel 4** con una imagen
   **API 34 x86_64**. Si tu laptop tiene 8 GB de RAM, edítalo (lápiz → Show Advanced Settings) y
   pon Graphics en **Software**, RAM en 2048 MB y VM heap en 512 MB.
5. Revisa todo con `flutter doctor`. Deben salir en verde **Flutter**, **Android toolchain** y
   **Connected device**. Puedes ignorar Chrome y Visual Studio: solo hacemos la app de Android.

### 2. Clona y corre la app

```bash
mkdir -p /c/proyectos
cd /c/proyectos
git clone https://github.com/entren-ando-itm/entren-ando.git
cd entren-ando/entren_ando
flutter pub get
flutter run
```

Abre el emulador antes de `flutter run` (`flutter devices` debe mostrarlo). La primera compilación
tarda de 10 a 20 minutos porque descarga lo de Android; las siguientes tardan mucho menos. Mientras
la app está abierta, presiona `r` en Git Bash para ver tus cambios al instante y `q` para cerrarla.

En modo debug la app crea sola el usuario demo `demo@entrenando.test` con su rutina, sesiones de
los últimos 45 días y comidas de hoy, así que cada quien puede trabajar su módulo sin esperar a los
demás. Para volver a crear esos datos con fechas de hoy: pestaña Perfil → "Reiniciar datos de
prueba".

### Si algo falla

| Lo que pasa | Qué hacer |
| --- | --- |
| El emulador se queda en negro y se cierra | Graphics en Software, usa el Pixel 4 y cierra Chrome y Android Studio mientras pruebas |
| `NDK 28.2.13676358` "did not install" | Instálalo a mano: SDK Manager → SDK Tools → Show Package Details → NDK (Side by side) → 28.2.13676358 |
| Pide `compileSdk` 37 o "Android SDK 37" | Instala API 37 en SDK Manager → SDK Platforms |
| "No supported devices connected" | Abre primero el emulador y espera a que se vea la pantalla de inicio de Android |
| `--android-licenses` dice "no longer needed" | Es normal, no hay que hacer nada |
| Errores raros después de cambiar de rama | `flutter clean` y luego `flutter pub get` |

## Antes de programar

1. Lee la guía del equipo en Jira (ENT-1).
2. Dale a tu IA el archivo `AGENTS.md`: tiene las reglas, el contrato técnico, cómo usar la base y
   las reglas del diseño. Para ver todos los componentes del diseño en la app: Perfil → "Ver
   componentes del diseño".
3. Crea tu rama desde main con la clave de tu historia (`git switch -c ENT-49-bitacora`), haz
   commits que empiecen con esa clave y abre un Pull Request. Nadie sube directo a main.

## Estructura

```
AGENTS.md, CLAUDE.md          reglas para la IA (mismo texto)
docs/                         ERS, scripts SQL entregados y pantallas del diseño
entren_ando/                  la app de Flutter
  lib/main.dart, app.dart     arranque, tema y las 4 pestañas (go_router + Riverpod)
  lib/core/db                 base cifrada, esquema, catálogo, datos demo y escritura local
  lib/core/tema               colores, letra, medidas y tema claro y oscuro
  lib/core/componentes        piezas del diseño para todas las pantallas
  lib/core/conectividad       detector de red
  lib/core/sync               sincronización con Supabase
  lib/features/<módulo>       pantallas, lógica y repositorio de cada módulo
  assets/fonts                Barlow y Barlow Semi Condensed (licencia SIL Open Font)
```

## Prueba del cifrado

Con la app abierta en el emulador: Android Studio → View → Tool Windows → Device Explorer →
`/data/data/mx.entrenando.app/databases/entren_ando.db` → Save As. Al abrir ese archivo con
DB Browser for SQLite debe pedir contraseña o marcar error: sin la llave del Keystore no se lee.
