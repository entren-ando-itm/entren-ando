import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tema/colores.dart';

/// Barra de avance sólida (por ejemplo el descanso del temporizador).
///
///   BarraProgreso(valor: 18 / 90, descripcion: 'Descanso transcurrido')
class BarraProgreso extends StatelessWidget {
  const BarraProgreso({super.key, required this.valor, this.alto = 8, this.descripcion});

  /// De 0 a 1.
  final double valor;
  final double alto;
  final String? descripcion;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final avance = valor.clamp(0.0, 1.0);
    final radio = BorderRadius.circular(alto / 2);
    return Semantics(
      label: descripcion,
      value: '${(avance * 100).round()} %',
      child: Container(
        height: alto,
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(color: colores.sup2, borderRadius: radio),
        child: AnimatedFractionallySizedBox(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          alignment: Alignment.centerLeft,
          widthFactor: avance,
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(color: colores.tinta, borderRadius: radio),
          ),
        ),
      ),
    );
  }
}

/// Una parte de [BarraSegmentos].
class SegmentoBarra {
  const SegmentoBarra({required this.valor, required this.color});

  final double valor;

  /// Usa colores del tema: `colores.tinta`, `colores.medio`, `colores.sup4`.
  final Color color;
}

/// Barra partida en segmentos según su proporción, como los macros en Comidas.
///
///   BarraSegmentos(
///     descripcion: 'Proteína 81 gramos, carbohidratos 174 gramos, grasa 37 gramos',
///     segmentos: [
///       SegmentoBarra(valor: 81, color: colores.tinta),
///       SegmentoBarra(valor: 174, color: colores.medio),
///       SegmentoBarra(valor: 37, color: colores.sup4),
///     ],
///   )
class BarraSegmentos extends StatelessWidget {
  const BarraSegmentos({
    super.key,
    required this.segmentos,
    this.alto = 14,
    this.separacion = 3,
    this.descripcion,
  });

  final List<SegmentoBarra> segmentos;
  final double alto;
  final double separacion;
  final String? descripcion;

  @override
  Widget build(BuildContext context) {
    final visibles = segmentos.where((s) => s.valor > 0).toList();
    final total = visibles.fold<double>(0, (suma, s) => suma + s.valor);
    final radio = BorderRadius.circular(alto / 2);
    return Semantics(
      label: descripcion,
      child: SizedBox(
        height: alto,
        child: total <= 0
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: context.colores.sup2, borderRadius: radio),
                    ),
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < visibles.length; i++) ...[
                    if (i > 0) SizedBox(width: separacion),
                    Expanded(
                      flex: math.max(1, (visibles[i].valor / total * 1000).round()),
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: visibles[i].color, borderRadius: radio),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Cuadrito (o punto) de color para leyendas.
class MarcaColor extends StatelessWidget {
  const MarcaColor(this.color, {super.key, this.tamano = 10, this.redonda = false});

  final Color color;
  final double tamano;
  final bool redonda;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        color: color,
        shape: redonda ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: redonda ? null : BorderRadius.circular(3),
      ),
    );
  }
}

/// Elemento de una leyenda: marca, nombre y valor opcional ("● Completo  2").
class ElementoLeyenda extends StatelessWidget {
  const ElementoLeyenda({super.key, required this.marca, required this.texto, this.valor});

  /// `PuntoSemaforo(...)` o `MarcaColor(...)`.
  final Widget marca;
  final String texto;
  final String? valor;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final valor = this.valor;
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(padding: const EdgeInsets.only(right: 8), child: marca),
          ),
          TextSpan(text: texto, style: const TextStyle(fontWeight: FontWeight.w500)),
          if (valor != null) TextSpan(text: '  $valor', style: TextStyle(color: colores.tinta2)),
        ],
      ),
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14),
    );
  }
}
