import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'colores.dart';

/// Tipografía de Entren-Ando.
///
/// * Barlow para todo el texto.
/// * Barlow Semi Condensed, en MAYÚSCULAS, para títulos grandes, números y
///   botones principales. Las mayúsculas las ponen los componentes: escribe
///   los textos normales ("Seguir entrenando").
///
/// En las pantallas usa los estilos de `Theme.of(context).textTheme`
/// (la tabla de usos está en AGENTS.md). No inventes tamaños nuevos.
class TipografiaEntrenAndo {
  TipografiaEntrenAndo._();

  /// Familia para todo el texto.
  static const String barlow = 'Barlow';

  /// Familia para títulos grandes, números y botones principales.
  static const String condensada = 'BarlowSemiCondensed';

  /// Números del mismo ancho, para que no "bailen" al cambiar
  /// (temporizador, kcal, pesos y repeticiones).
  static const List<ui.FontFeature> numerosTabulares = [ui.FontFeature.tabularFigures()];

  /// Texto del botón principal y del secundario (56 de alto).
  static const TextStyle boton = TextStyle(
    fontFamily: condensada,
    fontSize: 19,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    height: 1.0,
  );

  /// Texto del botón de 60 de alto (inicio de sesión y Premium).
  static const TextStyle botonGrande = TextStyle(
    fontFamily: condensada,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.5,
    height: 1.0,
  );

  /// Estilos de texto de la app con los colores del modo actual.
  static TextTheme textos(ColoresEntrenAndo c) {
    TextStyle condensado(double tamano, FontWeight peso, {double alto = 1.0, double espacio = 0}) {
      return TextStyle(
        fontFamily: condensada,
        fontSize: tamano,
        fontWeight: peso,
        height: alto,
        letterSpacing: espacio,
        color: c.tinta,
      );
    }

    TextStyle normal(double tamano, FontWeight peso,
        {double alto = 1.3, double espacio = 0, Color? color}) {
      return TextStyle(
        fontFamily: barlow,
        fontSize: tamano,
        fontWeight: peso,
        height: alto,
        letterSpacing: espacio,
        color: color ?? c.tinta,
      );
    }

    return TextTheme(
      // Día gigante del calendario ("9").
      displayLarge: condensado(128, FontWeight.w800, alto: 0.85, espacio: -3),
      // Cifra principal de una pantalla ("1410" kcal).
      displayMedium: condensado(104, FontWeight.w800, alto: 0.88, espacio: -2),
      // Título de portada ("PREMIUM").
      displaySmall: condensado(80, FontWeight.w800, alto: 0.88, espacio: -1),
      // Título de pantalla ("LUNES", "ENTREN-ANDO").
      headlineLarge: condensado(64, FontWeight.w800, alto: 0.92, espacio: -0.5),
      // Título de detalle ("PRENSA DE PIERNAS").
      headlineMedium: condensado(48, FontWeight.w800, alto: 0.95, espacio: -0.5),
      // Nombre o mes ("Usuario Demo", "NOVIEMBRE"); títulos de diálogo.
      headlineSmall: condensado(30, FontWeight.w700),
      // Franjas de días y encabezados de bloque ("MARTES").
      titleLarge: condensado(26, FontWeight.w800, alto: 1.1),
      // Texto de filas ("Sentadilla con barra").
      titleMedium: normal(16, FontWeight.w500, alto: 1.25),
      // Botones chicos y pastillas ("Cambiar solo hoy").
      titleSmall: normal(14, FontWeight.w600, alto: 1.25),
      // Subtítulos y texto de los campos.
      bodyLarge: normal(17, FontWeight.w400, alto: 1.35),
      // Detalles ("4 × 8 · 60 kg") y párrafos.
      bodyMedium: normal(15, FontWeight.w400, alto: 1.35),
      // Notas al pie, en tinta2.
      bodySmall: normal(13, FontWeight.w400, alto: 1.4, color: c.tinta2),
      // Acciones de texto ("Crear cuenta").
      labelLarge: normal(16, FontWeight.w600, alto: 1.2),
      // Etiquetas en mayúsculas ("CORREO"), en tinta2.
      labelMedium: normal(13, FontWeight.w600, alto: 1.2, espacio: 0.8, color: c.tinta2),
      // Pastillas chicas ("Sigue", "Sin conexión").
      labelSmall: normal(12, FontWeight.w600, alto: 1.2, espacio: 0.4),
    );
  }
}
