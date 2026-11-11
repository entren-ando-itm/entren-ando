# Entren-Ando: instrucciones para la IA

Lee este archivo completo antes de proponer o escribir código. CLAUDE.md tiene el mismo texto.

El proyecto de Flutter está en la carpeta `entren_ando/`: las rutas `lib/...` y `test/...` de este
archivo son dentro de esa carpeta y los comandos (`flutter run`, `flutter test`...) se corren ahí.
La carpeta `docs/` está en la raíz del repositorio.

## Qué es Entren-Ando

App Android (Flutter) de entrenamiento de fuerza y nutrición para un proyecto escolar de
Ingeniería de Software (Tecnológico de Morelia). La ERS está en `docs/01_ERS_Entren-Ando.pdf`
y manda sobre cualquier otra idea.

* **Offline-first:** todo se guarda primero en la base local cifrada y funciona en modo avión.
  Solo necesitan red la IA, la cámara para escanear comida y el inicio de sesión.
* **Freemium:** plan gratuito con 1 ciclo activo (RN-01), 3 escaneos de comida al día (RN-02)
  y feedback mensual (RN-03). Premium es simulado.
* **Sin rol de administrador.** Textos de la app en español.
* Backend: Supabase (Auth, PostgreSQL, Edge Functions y pg_cron). IA: Gemini, siempre a través
  de una función de Supabase.

## 6. Reglas para programar con IA

Antes:

* Dale a la IA el archivo AGENTS.md y la descripción técnica de tu historia.
* Pídele primero un plan y revisa qué archivos va a tocar. Si toca algo fuera de
  lib/features/tu_modulo, detente y coméntalo en el daily.

Ten cuidado de que la IA:

* Cambie el esquema de la base (lib/core/db). Solo se cambia con acuerdo del equipo.
* Agregue paquetes al pubspec.yaml sin avisar.
* "Arregle" errores quitando el cifrado, validaciones o límites freemium.
* Use otra arquitectura o gestor de estado distinto al del proyecto base.
* Invente tablas o columnas que no están en el esquema.
* Ponga llaves de Supabase o de la IA en el código.
* Llame a la IA desde la app. Siempre se llama por una función de Supabase.
* Haga muchos cambios de golpe. Pide cambios chicos y prueba cada uno.

Después:

* Corre la app, prueba en modo avión y revisa con git diff qué cambió antes del commit.
* Si no entiendes un bloque de código, pide a la IA que te lo explique. En la revisión te
  pueden preguntar.

## 7. Contrato técnico común

* Carpetas: lib/core (base de datos, conectividad, sincronización, tema) y
  lib/features/nombre_modulo (pantallas, lógica y repositorio de cada módulo).
* Estado con Riverpod y navegación con go_router (los deja listos ENT-11).
* Base local: SQLite cifrada con SQLCipher; la llave se guarda en el Keystore con
  flutter_secure_storage.
* Tablas: las 20 del modelo lógico entregado, con los mismos nombres.
  * Tablas del usuario: id de texto con UUID generado en el celular, más creado_en,
    actualizado_en, eliminado (0 o 1) y pendiente_sync (0 o 1).
  * Catálogos plan, equipo y ejercicio: id entero fijo, igual en el celular y en Supabase.
  * Nunca se borra con DELETE: se marca eliminado = 1 para que el borrado se sincronice.
* Fechas en ISO 8601 con hora de Ciudad de México. Pesos en kilogramos. Textos en español.
* Datos de prueba (solo en modo debug): usuario demo@entrenando.test con plan Gratuito, un ciclo
  activo de 4 días con alternativas y sesiones de los últimos 45 días (completas, parciales,
  descanso y días sin registro).

## Cómo usar la base local

Todo está en `lib/core/db`. El esquema (`esquema.sql`) es el contrato: no lo cambies sin
acuerdo del equipo.

* **Conexión:** `final bd = await ref.watch(baseDatosProvider.future);` dentro de un
  `FutureProvider` (o `ref.read` en un botón). Nunca abras otra conexión y nunca importes el
  paquete `sqflite` normal: siempre `package:sqflite_sqlcipher/sqflite.dart`.
* **Usuario actual:** `ref.watch(usuarioActualIdProvider)`. En debug es el usuario demo; ENT-41
  lo cambiará por el usuario que inició sesión.
* **Leer:** `bd.rawQuery('... WHERE ... AND eliminado = 0', [argumentos])`. Filtra siempre
  `eliminado = 0` y usa `?` para los valores, nunca los pegues en el texto del SQL.
* **Escribir:** siempre con `EscrituraLocal` (`insertar`, `actualizar`, `marcarEliminado`). Llena
  creado_en y actualizado_en, genera el UUID y marca pendiente_sync = 1. Si guardas varias filas
  que dependen entre sí, hazlo dentro de `bd.transaction((txn) async { ... EscrituraLocal(txn) ... })`.
* **Borrar:** `marcarEliminado`. Si la fila tiene hijos (ciclo → días → ejercicios programados →
  alternativas, sesión → registros → series), márcalos también en la misma transacción.
* **Fechas:** `Fechas.hoy()` para columnas DATE ('2026-11-09'), `Fechas.ahoraIso()` para fecha y
  hora ('2026-11-09T07:30:00-06:00'), `Fechas.hoyComoFecha()` para calcular rangos de días.
  `dia_semana` va de 1 (lunes) a 7 (domingo), igual que `DateTime.weekday`.
* **Catálogos:** `plan`, `equipo` y `ejercicio` son de solo lectura. Para nombrar un ejercicio usa
  `COALESCE(usuario_ejercicio.nombre_alias, ejercicio.nombre_oficial)`.
* **Límites freemium:** se leen de la tabla `plan` (NULL = ilimitado), no se escriben fijos en
  el código.
* **Sincronización:** solo el motor de `lib/core/sync` pone `pendiente_sync = 0`. Los datos demo
  ya vienen con `pendiente_sync = 0` y no se suben.
* **Cambios al esquema:** con acuerdo del equipo, sube `BaseDatos.version` y agrega la migración
  en `_migrar`. Mientras tanto, desinstala la app del emulador para que la base se cree de nuevo.
* **Datos demo con fechas de hoy:** pestaña Perfil → "Reiniciar datos de prueba" (solo debug).

## Diseño visual (ENT-12)

El diseño aprobado está en el lienzo "Pantallas Entren-Ando" (pídele el enlace a Pablo) y en
`docs/pantallas/` (un PNG por pantalla, en claro y oscuro; `docs/pantallas/LEEME.md` dice qué
historia y qué componentes usa cada una). **Antes de programar una pantalla, la IA debe ver su PNG y
reproducirlo con los componentes; si la pantalla no tiene PNG, se toma como modelo la más parecida.** Es minimalista: superficies sólidas,
sin bordes ni sombras, letra Barlow y modo claro y oscuro. Todo lo visual ya está hecho en
`lib/core/tema` y `lib/core/componentes`, y se importa con una sola línea:

```dart
import 'package:entren_ando/core/diseno.dart';
```

### Reglas (la IA siempre las sigue)

1. **Colores:** solo los del tema: `context.colores.fondo`, `sup1` a `sup4`, `tinta`, `tinta2`,
   `medio`, `tenue`, `boton`, `botonTexto` y `error`, y `ColoresSemaforo` para el calendario.
   Nunca `Color(0xFF...)`, `Colors.algo` (solo se permite `Colors.transparent`) ni opacidades
   inventadas en una pantalla.
2. **Sin bordes ni sombras:** nada de `Border`, `BorderSide` con color, `OutlineInputBorder` con
   línea, `Divider` para separar, `BoxShadow` ni `elevation` mayor que 0. Se separa con espacio o
   con superficies de distinto nivel (sup1 → sup4).
3. **Colores sólidos:** sin degradados, sin imágenes de fondo y sin efectos de vidrio o desenfoque.
4. **Letra:** Barlow en todo el texto. Barlow Semi Condensed en MAYÚSCULAS solo para títulos
   grandes, números y botones principales. Usa los estilos de `Theme.of(context).textTheme` (tabla
   abajo); no inventes tamaños ni familias. Escribe los textos normales ("Seguir entrenando"): los
   componentes ponen las mayúsculas.
5. **Formas y medidas:** usa `Medidas`: margen lateral 28, espacios de 4 a 32, esquinas de 18
   (campos, filas, avisos), 20 (tarjetas), 28 (tarjeta grande) y 32 (hoja inferior). Botones y
   pastillas en forma de píldora. Todo lo que se toca mide al menos 44 × 44.
6. **Un solo botón principal por pantalla** (`BotonPrincipal`). Las demás acciones van con
   `BotonSecundario`, `BotonChico`, `BotonTexto` o `BotonCircular`.
7. **Íconos:** `Icons.*_rounded` u `Icons.*_outlined`, de 20 a 24, en `tinta` o `tinta2`. Las
   pestañas usan `IconoPestana` (ya están en la barra).
8. **Claro y oscuro:** todo debe verse bien en los dos. Prueba tu pantalla en ambos (Perfil →
   Ajustes → Tema) antes de abrir el Pull Request.
9. **Sin red (RNF-02):** el botón que necesita internet va desactivado (`alPresionar: null`) y
   junto a él un `Aviso.sinRed(...)` que diga qué hacer mientras tanto.
10. **Textos:** español de México, tuteando y cortos. Fechas como "lunes 9 de noviembre".
11. **Pantallas:** cada pantalla es `Scaffold(body: ContenidoPantalla(children: [...]))` y empieza
    con su encabezado como en el lienzo (`EncabezadoPantalla` casi siempre). Las que se ven sin la
    barra de abajo (Ejercicio, Premium, inicio de sesión) van en `lib/app.dart` con
    `parentNavigatorKey: navegadorRaiz`.
12. **Si falta un componente,** no lo inventes en tu módulo ni copies uno con otro estilo: pregúntale
    a Pablo y, si se aprueba, se agrega a `lib/core/componentes` para todo el equipo.
13. **Pantallas nuevas:** una pantalla que no está en `docs/pantallas/` se arma con las mismas piezas y
    se le avisa a Pablo antes del Pull Request, para agregarla al lienzo y a esa carpeta.

### Componentes

| Componente | Para qué |
| --- | --- |
| `ContenidoPantalla` | Cuerpo con scroll, márgenes del diseño y espacio para la barra |
| `EncabezadoPantalla` | Etiqueta, título grande y subtítulo ("LUNES", "9 de noviembre · Pierna") |
| `EtiquetaSeccion` | Etiqueta en mayúsculas ("TU EQUIPO", "AJUSTES") |
| `NumeroConUnidad` | Números con su unidad ("1410 kcal", "120 kg") |
| `Tarjeta` | Superficie sólida de nivel 1 a 4; se puede tocar |
| `TarjetaDato` | Número con su nombre abajo ("74.6 kg / Peso") |
| `Pastilla` | Equipo, plan y marcas chicas ("Plan Gratuito", "Sigue") |
| `AvatarIniciales` | Círculo con las iniciales del usuario |
| `BotonPrincipal`, `BotonSecundario` | Botones de 56 de alto (60 con `grande: true`) |
| `BotonChico`, `BotonTexto`, `BotonCircular` | Acciones chicas, acciones de texto y Volver/Cerrar |
| `CampoTexto`, `Casilla` | Campos sin borde (con contraseña) y casilla para aceptar |
| `Aviso`, `Aviso.sinRed`, `InsigniaSinRed` | Avisos y el estado sin conexión |
| `CirculoDia`, `PuntoSemaforo`, `EstadoDia` | Días del calendario semáforo |
| `BarraProgreso`, `BarraSegmentos`, `ElementoLeyenda`, `MarcaColor` | Avances, macros y leyendas |
| `GrupoFilas`, `FilaAjuste`, `SelectorSegmentos` | Ajustes y selectores tipo "Claro / Oscuro" |
| `mostrarHojaInferior`, `EncabezadoHoja`, `FilaOpcion` | Hoja que sube desde abajo con opciones |
| `MensajeCentrado` | Pantalla vacía o con error |
| `modoTemaProvider` | Modo claro u oscuro (`ref.read(modoTemaProvider.notifier).cambiar(...)`) |

Para verlos todos en la app: pestaña Perfil → Modo de prueba → "Ver componentes del diseño". Las 4
pantallas del proyecto base (Hoy, Calendario, Comidas y Perfil) son ejemplos de cómo usarlos, y
`pantalla_calendario.dart` trae el ejemplo de la hoja "tocar un día".

### Estilos de texto

| Estilo | Para qué | Ejemplo del lienzo |
| --- | --- | --- |
| `displayLarge` | Número gigante | Día del calendario "9" (128) |
| `displayMedium` | Cifra principal | "1410" kcal (104) |
| `displaySmall` | Título de portada | "PREMIUM" (80) |
| `headlineLarge` | Título de pantalla | "LUNES" (64) |
| `headlineMedium` | Título de detalle | "PRENSA DE PIERNAS" (48) |
| `headlineSmall` | Nombre, mes y títulos de diálogo | "Usuario Demo", "NOVIEMBRE" (30) |
| `titleLarge` | Franjas y bloques | "MARTES" (26) |
| `titleMedium` | Texto de filas | "Sentadilla con barra" (16) |
| `titleSmall` | Botones chicos y pastillas | "Cambiar solo hoy" (14) |
| `bodyLarge` | Subtítulos y campos | "9 de noviembre · Pierna" (17) |
| `bodyMedium` | Detalles y párrafos | "4 × 8 · 60 kg" (15) |
| `bodySmall` | Notas al pie (tinta2) | "Medido el 25 de octubre" (13) |
| `labelLarge` | Acciones de texto | "Crear cuenta" (16) |
| `labelMedium` | Etiquetas en mayúsculas (tinta2) | "CORREO" (13) |
| `labelSmall` | Pastillas chicas | "Sigue", "Sin conexión" (12) |

Para números que cambian (temporizador, pesos, kcal) agrega
`fontFeatures: TipografiaEntrenAndo.numerosTabulares` o usa `NumeroConUnidad`.

### Ejemplo de pantalla

```dart
import 'package:flutter/material.dart';
import 'package:entren_ando/core/diseno.dart';

class PantallaEjemplo extends StatelessWidget {
  const PantallaEjemplo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ContenidoPantalla(
        children: [
          const EncabezadoPantalla(
            etiqueta: 'Hoy · lunes 9 de noviembre',
            titulo: 'Comidas',
            accion: InsigniaSinRed(),
          ),
          const SizedBox(height: Medidas.espacio5),
          BotonPrincipal(
            texto: 'Registrar a mano',
            icono: Icons.edit_outlined,
            alPresionar: () {},
          ),
          const SizedBox(height: Medidas.espacio4),
          const Tarjeta(child: Text('Avena con plátano y leche')),
        ],
      ),
    );
  }
}
```

## Estructura y dueños

| Carpeta | Dueño | Historias |
| --- | --- | --- |
| lib/core/db, lib/app.dart, lib/main.dart | Pablo | ENT-11 |
| lib/features/cuenta | Pablo | ENT-41, ENT-42, ENT-43, ENT-51, ENT-52 |
| lib/core/conectividad, lib/core/sync, lib/features/nube | Ángel | ENT-13, ENT-14, ENT-44, ENT-53, ENT-54 |
| lib/features/nutricion (pestaña Comidas) | Ángel | ENT-45, ENT-65 |
| lib/features/perfil, lib/features/rutinas, lib/features/ia | Axel | ENT-17, ENT-18, ENT-47, ENT-48, ENT-57, ENT-58, ENT-68, ENT-69 |
| lib/features/entrenamiento (pestaña Hoy), lib/features/calendario | Paola | ENT-19, ENT-20, ENT-49, ENT-50, ENT-59, ENT-60, ENT-70, ENT-71 |
| lib/core/tema, lib/core/componentes | Pablo (cambios con acuerdo en el daily) | ENT-12 |

Cada módulo trae un `LEEME.md` con lo que le toca. Las pantallas nuevas de tu módulo se agregan
como rutas hijas de tu pestaña en `lib/app.dart`.

## Comandos

Dentro de la carpeta `entren_ando/`:

* `flutter pub get`: instala los paquetes.
* `flutter run`: abre la app en el emulador.
* `flutter analyze`: revisa errores antes del commit.
* `flutter test`: pruebas rápidas (esquema, fechas, archivos SQL y que los componentes se dibujen
  en claro y oscuro).
