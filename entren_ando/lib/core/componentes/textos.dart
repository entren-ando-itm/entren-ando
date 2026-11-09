import 'package:flutter/material.dart';

import '../tema/colores.dart';
import '../tema/tipografia.dart';

/// Etiqueta corta en mayúsculas, en tinta2: "CORREO", "TU EQUIPO", "AJUSTES".
///
/// Escribe el texto normal; el componente pone las mayúsculas.
class EtiquetaSeccion extends StatelessWidget {
  const EtiquetaSeccion(this.texto, {super.key, this.color});

  final String texto;

  /// Solo si la etiqueta va sobre otro fondo (por ejemplo tinta).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).textTheme.labelMedium;
    final color = this.color;
    return Text(
      texto.toUpperCase(),
      style: color == null ? estilo : estilo?.copyWith(color: color),
    );
  }
}

/// Encabezado de pantalla: etiqueta, título grande en mayúsculas y subtítulo.
///
///   EncabezadoPantalla(
///     etiqueta: 'Ciclo demo · torso y pierna',
///     titulo: 'Lunes',
///     subtitulo: '9 de noviembre · Pierna',
///   )
class EncabezadoPantalla extends StatelessWidget {
  const EncabezadoPantalla({
    super.key,
    required this.titulo,
    this.etiqueta,
    this.subtitulo,
    this.accion,
    this.estiloTitulo,
  });

  final String titulo;
  final String? etiqueta;
  final String? subtitulo;

  /// Algo chico a la derecha de la etiqueta, como `InsigniaSinRed()`.
  final Widget? accion;

  /// Otro tamaño de título. Por defecto es `textTheme.headlineLarge` (64);
  /// para el nombre de un ejercicio usa `textTheme.headlineMedium` (48).
  final TextStyle? estiloTitulo;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final etiqueta = this.etiqueta;
    final subtitulo = this.subtitulo;
    final accion = this.accion;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (etiqueta != null || accion != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: etiqueta == null ? const SizedBox.shrink() : EtiquetaSeccion(etiqueta),
                ),
                ?accion,
              ],
            ),
          ),
        Semantics(
          header: true,
          child: Text(titulo.toUpperCase(), style: estiloTitulo ?? textos.headlineLarge),
        ),
        if (subtitulo != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              subtitulo,
              style: textos.bodyLarge?.copyWith(color: context.colores.tinta2),
            ),
          ),
      ],
    );
  }
}

/// Número con su unidad, con la letra condensada y números del mismo ancho:
/// "1410 kcal" (tamaño 104), "120 kg" (24), "74.6 kg" (28), "420 kcal" (22).
class NumeroConUnidad extends StatelessWidget {
  const NumeroConUnidad({
    super.key,
    required this.numero,
    this.unidad,
    this.tamano = 28,
    this.color,
  });

  /// El número ya con formato ("74.6", "1410").
  final String numero;
  final String? unidad;
  final double tamano;

  /// Solo si va sobre otro fondo (por ejemplo la serie actual, en botonTexto).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final grande = tamano >= 56;
    final unidad = this.unidad;
    final colorUnidad = color ?? colores.tinta2;
    return Text.rich(
      TextSpan(
        text: numero,
        style: TextStyle(
          fontFamily: TipografiaEntrenAndo.condensada,
          fontWeight: grande ? FontWeight.w800 : FontWeight.w700,
          fontSize: tamano,
          height: grande ? 0.88 : 1.0,
          letterSpacing: grande ? -2 : 0,
          color: color ?? colores.tinta,
          fontFeatures: TipografiaEntrenAndo.numerosTabulares,
        ),
        children: [
          if (unidad != null)
            TextSpan(
              text: grande ? '  $unidad' : ' $unidad',
              style: TextStyle(
                fontFamily: grande ? TipografiaEntrenAndo.condensada : TipografiaEntrenAndo.barlow,
                fontWeight: grande ? FontWeight.w600 : FontWeight.w500,
                fontSize: (tamano * 0.55).clamp(12.0, 28.0),
                letterSpacing: 0,
                color: colorUnidad,
              ),
            ),
        ],
      ),
    );
  }
}
