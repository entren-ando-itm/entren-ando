import 'package:flutter/material.dart';

import '../tema/medidas.dart';

/// Cuerpo de una pantalla: lista con desplazamiento y los márgenes del diseño
/// (28 a los lados). Deja espacio abajo para la barra de navegación.
///
///   Scaffold(
///     body: ContenidoPantalla(children: [
///       const EncabezadoPantalla(titulo: 'Comidas'),
///       ...
///     ]),
///   )
class ContenidoPantalla extends StatelessWidget {
  const ContenidoPantalla({
    super.key,
    this.arriba = Medidas.espacio4,
    this.controlador,
    required this.children,
  });

  /// Espacio arriba, debajo de la barra de estado.
  final double arriba;
  final ScrollController? controlador;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final abajo = MediaQuery.paddingOf(context).bottom + Medidas.espacio5;
    return SafeArea(
      bottom: false,
      child: ListView(
        controller: controlador,
        padding: EdgeInsets.fromLTRB(Medidas.margen, arriba, Medidas.margen, abajo),
        children: children,
      ),
    );
  }
}
