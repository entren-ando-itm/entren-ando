import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../diseno.dart';
import 'conectividad.dart';

/// Banda de arriba que aparece en toda la app cuando no hay internet
/// (ENT-14, criterios 1 y 2). Se pone una sola vez en `lib/app.dart`,
/// envolviendo a todas las pantallas:
///
///   builder: (context, child) => AvisoSinRed(child: child!)
///
/// Cuando vuelve la red, la banda se esconde sola.
class AvisoSinRed extends ConsumerWidget {
  const AvisoSinRed({super.key, required this.child});

  /// Las pantallas de la app.
  final Widget child;

  static const String texto = 'Sin conexión: tus datos se guardan en el celular.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hayRed = ref.watch(hayRedProvider);
    return Material(
      color: context.colores.fondo,
      child: Column(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: hayRed
                ? const SizedBox(width: double.infinity)
                : const SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        Medidas.margen,
                        Medidas.espacio2,
                        Medidas.margen,
                        0,
                      ),
                      child: Aviso.sinRed(texto),
                    ),
                  ),
          ),
          // La banda ya ocupa el espacio de la barra de estado; las pantallas
          // no deben dejarlo otra vez. Siempre se envuelve igual (con o sin
          // red) para que las pantallas no pierdan lo que tenían.
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: !hayRed,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
