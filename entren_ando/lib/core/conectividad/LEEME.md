# core/conectividad

Dueño: Ángel. Historia: ENT-14 (detector de conexión y aviso sin red), subtareas ENT-29 y ENT-30.

Las pantallas que necesitan internet (IA, cámara, inicio de sesión) se desactivan sin red y sugieren
el registro manual (RNF-02). Lo demás (bitácora, temporizador, comidas a mano) nunca se bloquea.

## Qué hay aquí

| Archivo | Qué hace |
| --- | --- |
| `conectividad.dart` | `hayRedProvider`: `true` si hay internet de verdad. Usa `connectivity_plus` y, cuando cambia la red, una petición ligera a `connectivitycheck.gstatic.com/generate_204` (tener Wi-Fi no siempre es tener internet). Si hay red sin internet, reintenta a los 10, 20, 40 y luego cada 60 segundos. |
| `aviso_sin_red.dart` | `AvisoSinRed`: banda "Sin conexión: tus datos se guardan en el celular." arriba de toda la app. Ya está puesta en `lib/app.dart`; no la agregues en tus pantallas. |
| `boton_con_red.dart` | `BotonConRed`: envuelve un botón que necesita internet. Sin red lo desactiva y pone abajo un `Aviso.sinRed`. |

## Cómo usarlo en tu módulo

Botón que necesita internet (cámara, IA):

```dart
import 'package:entren_ando/core/conectividad/boton_con_red.dart';

BotonConRed(
  alPresionar: escanearComida,
  boton: (alPresionar) => BotonSecundario(
    texto: 'Escanear con cámara',
    icono: Icons.photo_camera_outlined,
    alPresionar: alPresionar,
  ),
  avisoSinRed: 'Sin conexión. El escaneo con IA vuelve cuando tengas red; mientras, regístralo a mano.',
)
```

Si no pones `avisoSinRed`, dice "Necesita internet. Usa el registro manual."

Saber si hay red (por ejemplo, para la pastilla `InsigniaSinRed` del encabezado):

```dart
import 'package:entren_ando/core/conectividad/conectividad.dart';

final hayRed = ref.watch(hayRedProvider);
EncabezadoPantalla(titulo: 'Comidas', accion: hayRed ? null : const InsigniaSinRed())
```

Hacer algo cuando vuelve la red (la sincronización, ENT-44):

```dart
ref.listen(hayRedProvider, (antes, ahora) {
  if (antes == false && ahora) subirPendientes();
});
```

Revisar otra vez a mano (un botón "Reintentar"): `ref.read(hayRedProvider.notifier).revisar();`

## Cómo probar

Con la app abierta en el emulador, activa y desactiva el modo avión (desliza desde arriba). Sin red
aparece la banda en menos de un segundo; al volver la red se va en unos segundos.
