import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'colores.dart';
import 'medidas.dart';
import 'tipografia.dart';

/// Tema de la app en modo claro y oscuro, armado con los colores del lienzo.
///
/// Reglas que aplica a todos los widgets de Material: sin bordes, sin sombras,
/// colores sólidos, botones en forma de píldora y la letra Barlow.
/// No crees otro ThemeData en las pantallas: si falta algo, se agrega aquí
/// con acuerdo del equipo.
class TemaEntrenAndo {
  TemaEntrenAndo._();

  static final ThemeData _claro = _crear(ColoresEntrenAndo.claro, Brightness.light);
  static final ThemeData _oscuro = _crear(ColoresEntrenAndo.oscuro, Brightness.dark);

  static ThemeData claro() => _claro;

  static ThemeData oscuro() => _oscuro;

  /// Color de los íconos de la barra de estado de Android según el modo.
  static SystemUiOverlayStyle barraDelSistema(Brightness brillo) {
    final oscuro = brillo == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarIconBrightness: oscuro ? Brightness.light : Brightness.dark,
      statusBarBrightness: oscuro ? Brightness.dark : Brightness.light,
      systemNavigationBarIconBrightness: oscuro ? Brightness.light : Brightness.dark,
    );
  }

  static ThemeData _crear(ColoresEntrenAndo c, Brightness brillo) {
    final textos = TipografiaEntrenAndo.textos(c);
    final esquema = ColorScheme(
      brightness: brillo,
      primary: c.boton,
      onPrimary: c.botonTexto,
      primaryContainer: c.sup2,
      onPrimaryContainer: c.tinta,
      secondary: c.tinta2,
      onSecondary: c.fondo,
      secondaryContainer: c.sup1,
      onSecondaryContainer: c.tinta,
      tertiary: c.medio,
      onTertiary: c.fondo,
      error: c.error,
      onError: c.fondo,
      surface: c.fondo,
      onSurface: c.tinta,
      onSurfaceVariant: c.tinta2,
      surfaceDim: c.sup1,
      surfaceBright: c.fondo,
      surfaceContainerLowest: c.fondo,
      surfaceContainerLow: c.sup1,
      surfaceContainer: c.sup1,
      surfaceContainerHigh: c.sup2,
      surfaceContainerHighest: c.sup3,
      outline: c.medio,
      outlineVariant: c.tenue,
      shadow: Colors.transparent,
      scrim: c.velo,
      inverseSurface: c.tinta,
      onInverseSurface: c.fondo,
      inversePrimary: c.fondo,
      surfaceTint: Colors.transparent,
    );

    const pildora = StadiumBorder();
    final campoSinBorde = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Medidas.radioCampo),
      borderSide: BorderSide.none,
    );

    return ThemeData(
      brightness: brillo,
      colorScheme: esquema,
      extensions: <ThemeExtension<dynamic>>[c],
      scaffoldBackgroundColor: c.fondo,
      canvasColor: c.fondo,
      fontFamily: TipografiaEntrenAndo.barlow,
      textTheme: textos,
      splashColor: c.tinta.withValues(alpha: 0.08),
      highlightColor: Colors.transparent,
      iconTheme: IconThemeData(color: c.tinta, size: 24),
      dividerTheme: DividerThemeData(color: c.tenue, thickness: 1, space: 1),
      appBarTheme: AppBarThemeData(
        backgroundColor: c.fondo,
        foregroundColor: c.tinta,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: textos.titleLarge,
        systemOverlayStyle: barraDelSistema(brillo),
      ),
      cardTheme: CardThemeData(
        color: c.sup1,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Medidas.radioTarjeta)),
        clipBehavior: Clip.antiAlias,
      ),
      // Botón principal (FilledButton) y secundario (FilledButton.tonal).
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, Medidas.altoBoton),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: pildora,
          elevation: 0,
          textStyle: TipografiaEntrenAndo.boton,
          disabledBackgroundColor: c.sup2,
          disabledForegroundColor: c.tinta2,
        ),
      ),
      // Sin borde: se ve como el botón secundario.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, Medidas.altoBoton),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: pildora,
          side: BorderSide.none,
          backgroundColor: c.sup1,
          foregroundColor: c.tinta,
          textStyle: TipografiaEntrenAndo.boton,
        ),
      ),
      // Sin sombra: se ve como el botón secundario.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(64, Medidas.altoBoton),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: pildora,
          elevation: 0,
          backgroundColor: c.sup1,
          foregroundColor: c.tinta,
          textStyle: TipografiaEntrenAndo.boton,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: pildora,
          foregroundColor: c.tinta,
          textStyle: textos.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: c.tinta),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.boton,
        foregroundColor: c.botonTexto,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: pildora,
      ),
      // Campos con fondo sólido y sin línea, como en el inicio de sesión.
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: c.sup1,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: campoSinBorde,
        enabledBorder: campoSinBorde,
        focusedBorder: campoSinBorde,
        disabledBorder: campoSinBorde,
        errorBorder: campoSinBorde,
        focusedErrorBorder: campoSinBorde,
        hintStyle: textos.bodyLarge?.copyWith(color: c.medio),
        labelStyle: textos.bodyLarge?.copyWith(color: c.tinta2),
        floatingLabelStyle: textos.labelMedium,
        errorStyle: textos.bodySmall?.copyWith(color: c.error),
        prefixIconColor: c.tinta2,
        suffixIconColor: c.tinta2,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.tinta,
        selectionColor: c.tinta.withValues(alpha: 0.22),
        selectionHandleColor: c.tinta,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.sup1,
        selectedColor: c.tinta,
        disabledColor: c.sup2,
        checkmarkColor: c.fondo,
        side: BorderSide.none,
        shape: pildora,
        labelStyle: textos.titleSmall?.copyWith(fontWeight: FontWeight.w500),
        secondaryLabelStyle: textos.titleSmall?.copyWith(color: c.fondo),
        padding: const EdgeInsets.symmetric(horizontal: 6),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (estados) => estados.contains(WidgetState.selected) ? c.fondo : c.tinta2,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (estados) => estados.contains(WidgetState.selected) ? c.tinta : c.sup2,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.tinta,
        linearTrackColor: c.sup2,
        circularTrackColor: Colors.transparent,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.tinta,
        textColor: c.tinta,
        titleTextStyle: textos.titleMedium,
        subtitleTextStyle: textos.bodySmall,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Medidas.radioCampo)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.fondo,
        modalBackgroundColor: c.fondo,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        modalBarrierColor: c.velo,
        showDragHandle: true,
        dragHandleColor: c.sup3,
        dragHandleSize: const Size(40, 5),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Medidas.radioHoja)),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.fondo,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Medidas.radioGrande)),
        titleTextStyle: textos.headlineSmall,
        contentTextStyle: textos.bodyMedium?.copyWith(color: c.tinta2),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.tinta,
        contentTextStyle: textos.bodyMedium?.copyWith(color: c.fondo),
        actionTextColor: c.fondo,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Medidas.radioCampo)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.sup1,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Medidas.radioCampo)),
        textStyle: textos.bodyLarge,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: c.fondo,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Medidas.radioGrande)),
        headerBackgroundColor: c.fondo,
        headerForegroundColor: c.tinta,
        dividerColor: Colors.transparent,
      ),
    );
  }
}
