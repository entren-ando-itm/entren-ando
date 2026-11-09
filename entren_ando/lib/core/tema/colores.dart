import 'package:flutter/material.dart';

/// Colores de Entren-Ando, los mismos del lienzo de diseño (ENT-12).
///
/// En las pantallas úsalos siempre con `context.colores`, por ejemplo
/// `context.colores.sup1`. No escribas colores sueltos (`Color(0xFF...)`,
/// `Colors.grey`, etc.): si falta uno, se agrega aquí con acuerdo del equipo.
///
/// Los colores del semáforo del calendario están en `ColoresSemaforo`.
@immutable
class ColoresEntrenAndo extends ThemeExtension<ColoresEntrenAndo> {
  const ColoresEntrenAndo({
    required this.fondo,
    required this.sup1,
    required this.sup2,
    required this.sup3,
    required this.sup4,
    required this.tinta,
    required this.tinta2,
    required this.medio,
    required this.tenue,
    required this.barra,
    required this.barraIcono,
    required this.boton,
    required this.botonTexto,
    required this.velo,
    required this.error,
  });

  /// Fondo de todas las pantallas.
  final Color fondo;

  /// Superficie normal: tarjetas, filas, campos y botones secundarios.
  final Color sup1;

  /// Superficie un poco más marcada: pistas de barras, avatar, segundo nivel.
  final Color sup2;

  /// Tercer nivel (por ejemplo la "escalera" de días en Hoy).
  final Color sup3;

  /// Cuarto nivel, el más marcado.
  final Color sup4;

  /// Texto principal e íconos.
  final Color tinta;

  /// Texto secundario: subtítulos, etiquetas, unidades y notas.
  final Color tinta2;

  /// Tono intermedio para gráficas (por ejemplo carbohidratos).
  final Color medio;

  /// Muy suave: días que vienen en el calendario.
  final Color tenue;

  /// Fondo de la barra de navegación.
  final Color barra;

  /// Íconos sin seleccionar dentro de la barra.
  final Color barraIcono;

  /// Fondo del botón principal.
  final Color boton;

  /// Texto del botón principal.
  final Color botonTexto;

  /// Velo detrás de las hojas inferiores.
  final Color velo;

  /// Solo para mensajes de error de un campo o de una acción.
  final Color error;

  static const ColoresEntrenAndo claro = ColoresEntrenAndo(
    fondo: Color(0xFFE8E6E2),
    sup1: Color(0xFFDDDAD5),
    sup2: Color(0xFFD1CDC7),
    sup3: Color(0xFFC5C0B9),
    sup4: Color(0xFFB9B3AB),
    tinta: Color(0xFF1A1A1A),
    tinta2: Color(0xFF5C5852),
    medio: Color(0xFF8A857E),
    tenue: Color(0xFFD6D2CC),
    barra: Color(0xFF1A1A1A),
    barraIcono: Color(0xFFE8E6E2),
    boton: Color(0xFF1A1A1A),
    botonTexto: Color(0xFFF1EFEB),
    velo: Color(0x6B1A1A1A),
    error: Color(0xFFB3261E),
  );

  static const ColoresEntrenAndo oscuro = ColoresEntrenAndo(
    fondo: Color(0xFF121212),
    sup1: Color(0xFF1C1C1C),
    sup2: Color(0xFF2A2A2A),
    sup3: Color(0xFF333333),
    sup4: Color(0xFF3D3D3D),
    tinta: Color(0xFFF1EFEB),
    tinta2: Color(0xFFA39E96),
    medio: Color(0xFF7D7870),
    tenue: Color(0xFF262626),
    barra: Color(0xFFF1EFEB),
    barraIcono: Color(0xFF121212),
    boton: Color(0xFFF1EFEB),
    botonTexto: Color(0xFF121212),
    velo: Color(0x9E000000),
    error: Color(0xFFF2B8B5),
  );

  /// Superficie por nivel, de 1 (sup1) a 4 (sup4).
  Color superficie(int nivel) => switch (nivel) {
        <= 1 => sup1,
        2 => sup2,
        3 => sup3,
        _ => sup4,
      };

  @override
  ColoresEntrenAndo copyWith({
    Color? fondo,
    Color? sup1,
    Color? sup2,
    Color? sup3,
    Color? sup4,
    Color? tinta,
    Color? tinta2,
    Color? medio,
    Color? tenue,
    Color? barra,
    Color? barraIcono,
    Color? boton,
    Color? botonTexto,
    Color? velo,
    Color? error,
  }) {
    return ColoresEntrenAndo(
      fondo: fondo ?? this.fondo,
      sup1: sup1 ?? this.sup1,
      sup2: sup2 ?? this.sup2,
      sup3: sup3 ?? this.sup3,
      sup4: sup4 ?? this.sup4,
      tinta: tinta ?? this.tinta,
      tinta2: tinta2 ?? this.tinta2,
      medio: medio ?? this.medio,
      tenue: tenue ?? this.tenue,
      barra: barra ?? this.barra,
      barraIcono: barraIcono ?? this.barraIcono,
      boton: boton ?? this.boton,
      botonTexto: botonTexto ?? this.botonTexto,
      velo: velo ?? this.velo,
      error: error ?? this.error,
    );
  }

  /// Mezcla los colores al cambiar entre claro y oscuro (la transición es suave).
  @override
  ColoresEntrenAndo lerp(ThemeExtension<ColoresEntrenAndo>? other, double t) {
    if (other is! ColoresEntrenAndo) return this;
    Color mezcla(Color a, Color b) => Color.lerp(a, b, t) ?? b;
    return ColoresEntrenAndo(
      fondo: mezcla(fondo, other.fondo),
      sup1: mezcla(sup1, other.sup1),
      sup2: mezcla(sup2, other.sup2),
      sup3: mezcla(sup3, other.sup3),
      sup4: mezcla(sup4, other.sup4),
      tinta: mezcla(tinta, other.tinta),
      tinta2: mezcla(tinta2, other.tinta2),
      medio: mezcla(medio, other.medio),
      tenue: mezcla(tenue, other.tenue),
      barra: mezcla(barra, other.barra),
      barraIcono: mezcla(barraIcono, other.barraIcono),
      boton: mezcla(boton, other.boton),
      botonTexto: mezcla(botonTexto, other.botonTexto),
      velo: mezcla(velo, other.velo),
      error: mezcla(error, other.error),
    );
  }
}

/// Acceso corto a los colores: `context.colores.tinta`.
extension ColoresDelContexto on BuildContext {
  ColoresEntrenAndo get colores =>
      Theme.of(this).extension<ColoresEntrenAndo>() ?? ColoresEntrenAndo.claro;
}
