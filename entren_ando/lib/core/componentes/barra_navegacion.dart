import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tema/colores.dart';
import '../tema/medidas.dart';

/// Íconos de las 4 pestañas, dibujados con los mismos trazos del lienzo.
enum IconoPestana { hoy, calendario, comidas, perfil }

/// Una pestaña de la [BarraNavegacion].
class DestinoBarra {
  const DestinoBarra({required this.icono, required this.etiqueta});

  final IconoPestana icono;

  /// Lo que lee el lector de pantalla ("Hoy", "Calendario"...).
  final String etiqueta;
}

/// Barra de navegación en forma de píldora: fondo `barra` y la pestaña activa
/// en un círculo del color del fondo.
///
/// La usa `EsqueletoPestanas` en lib/app.dart; las pantallas no la usan.
class BarraNavegacion extends StatelessWidget {
  const BarraNavegacion({
    super.key,
    required this.destinos,
    required this.indice,
    required this.alCambiar,
  });

  final List<DestinoBarra> destinos;
  final int indice;
  final ValueChanged<int> alCambiar;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: Medidas.espacio3),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Medidas.espacio5, 0, Medidas.espacio5, Medidas.espacio3),
        child: Material(
          color: colores.barra,
          shape: const StadiumBorder(),
          child: SizedBox(
            height: Medidas.altoBarra,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Medidas.espacio2),
              child: LayoutBuilder(
                builder: (context, limites) {
                  final cabe = destinos.isEmpty ? Medidas.botonBarra : limites.maxWidth / destinos.length;
                  final tamano = math.min(Medidas.botonBarra, cabe);
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var i = 0; i < destinos.length; i++)
                        _BotonBarra(
                          destino: destinos[i],
                          activo: i == indice,
                          tamano: tamano,
                          alTocar: () {
                            if (i != indice) HapticFeedback.selectionClick();
                            alCambiar(i);
                          },
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BotonBarra extends StatelessWidget {
  const _BotonBarra({
    required this.destino,
    required this.activo,
    required this.tamano,
    required this.alTocar,
  });

  final DestinoBarra destino;
  final bool activo;
  final double tamano;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final colorIcono = activo ? colores.tinta : colores.barraIcono;
    const duracion = Duration(milliseconds: 220);
    return Semantics(
      label: destino.etiqueta,
      selected: activo,
      button: true,
      child: AnimatedContainer(
        duration: duracion,
        curve: Curves.easeOutCubic,
        width: tamano,
        height: tamano,
        decoration: BoxDecoration(
          color: activo ? colores.fondo : colores.barra,
          shape: BoxShape.circle,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: alTocar,
            child: Center(
              child: TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: colorIcono),
                duration: duracion,
                builder: (context, color, _) => DibujoPestana(
                  destino.icono,
                  color: color ?? colorIcono,
                  tamano: destino.icono == IconoPestana.calendario ? 24 : 26,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dibuja el ícono de una pestaña. Se puede usar fuera de la barra, por
/// ejemplo en una pantalla vacía de Comidas.
class DibujoPestana extends StatelessWidget {
  const DibujoPestana(this.icono, {super.key, this.color, this.tamano = 26});

  final IconoPestana icono;

  /// Por defecto, el color de los íconos del tema (tinta).
  final Color? color;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? IconTheme.of(context).color ?? context.colores.tinta;
    return SizedBox.square(
      dimension: tamano,
      child: CustomPaint(painter: _PintorPestana(icono, color)),
    );
  }
}

/// Trazos en una cuadrícula de 24 × 24, iguales a los SVG del lienzo.
class _PintorPestana extends CustomPainter {
  _PintorPestana(this.icono, this.color);

  final IconoPestana icono;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final trazo = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final relleno = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (icono) {
      case IconoPestana.hoy:
        // Pesa: dos discos, dos topes y la barra.
        canvas.drawLine(const Offset(6, 7), const Offset(6, 17), trazo);
        canvas.drawLine(const Offset(18, 7), const Offset(18, 17), trazo);
        canvas.drawLine(const Offset(3, 10), const Offset(3, 14), trazo);
        canvas.drawLine(const Offset(21, 10), const Offset(21, 14), trazo);
        canvas.drawLine(const Offset(6, 12), const Offset(18, 12), trazo);
      case IconoPestana.calendario:
        // Nueve puntos, como los días del calendario.
        for (final y in const [6.0, 12.0, 18.0]) {
          for (final x in const [6.0, 12.0, 18.0]) {
            canvas.drawCircle(Offset(x, y), 1.8, relleno);
          }
        }
      case IconoPestana.comidas:
        // Plato hondo con vapor.
        final plato = Path()
          ..moveTo(3.5, 11)
          ..lineTo(20.5, 11)
          ..arcToPoint(const Offset(3.5, 11), radius: const Radius.circular(8.5))
          ..close();
        canvas.drawPath(plato, trazo);
        for (final x in const [9.0, 14.0]) {
          final vapor = Path()
            ..moveTo(x, 7.5)
            ..cubicTo(x, 6.3, x + 0.8, 5.9, x + 0.8, 4.7);
          canvas.drawPath(vapor, trazo);
        }
      case IconoPestana.perfil:
        // Cabeza y hombros.
        canvas.drawCircle(const Offset(12, 8), 4, trazo);
        final hombros = Path()
          ..moveTo(4.5, 20.5)
          ..cubicTo(5.9, 16.9, 8.7, 15, 12, 15)
          ..cubicTo(15.3, 15, 18.1, 16.9, 19.5, 20.5);
        canvas.drawPath(hombros, trazo);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PintorPestana oldDelegate) =>
      oldDelegate.icono != icono || oldDelegate.color != color;
}
