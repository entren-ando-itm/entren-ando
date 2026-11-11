import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../diseno.dart';
import 'conectividad.dart';

/// Envuelve un botón que necesita internet (IA, cámara, inicio de sesión).
/// Sin red el botón se desactiva y abajo aparece un `Aviso.sinRed` que dice
/// qué hacer mientras tanto (ENT-14 criterio 3, RNF-02, regla de diseño 9).
///
///   BotonConRed(
///     alPresionar: escanearComida,
///     boton: (alPresionar) => BotonSecundario(
///       texto: 'Escanear con cámara',
///       icono: Icons.photo_camera_outlined,
///       alPresionar: alPresionar,
///     ),
///     avisoSinRed: 'Sin conexión. El escaneo con IA vuelve cuando tengas red; '
///         'mientras, regístralo a mano.',
///   )
///
/// No lo uses en lo que funciona sin red (bitácora, temporizador, registro
/// manual de comidas): eso nunca se bloquea.
class BotonConRed extends ConsumerWidget {
  const BotonConRed({
    super.key,
    required this.boton,
    required this.alPresionar,
    this.avisoSinRed = textoPorDefecto,
  });

  /// Construye el botón con la acción que le toca: la real con red, o
  /// `null` (desactivado) sin red.
  final Widget Function(VoidCallback? alPresionar) boton;

  /// Lo que hace el botón cuando hay internet.
  final VoidCallback? alPresionar;

  /// Qué hacer mientras no hay red.
  final String avisoSinRed;

  static const String textoPorDefecto = 'Necesita internet. Usa el registro manual.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hayRed = ref.watch(hayRedProvider);
    if (hayRed) return boton(alPresionar);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        boton(null),
        const SizedBox(height: Medidas.espacio3),
        Aviso.sinRed(avisoSinRed),
      ],
    );
  }
}
