/// Medidas del diseño en píxeles lógicos, tomadas del lienzo de ENT-12.
///
/// Usa estas constantes en lugar de números sueltos para que todas las
/// pantallas tengan los mismos márgenes, alturas y esquinas.
class Medidas {
  Medidas._();

  /// Margen a los lados de cada pantalla.
  static const double margen = 28;

  /// Espacios entre elementos, de menor a mayor.
  static const double espacio1 = 4;
  static const double espacio2 = 8;
  static const double espacio3 = 12;
  static const double espacio4 = 16;
  static const double espacio5 = 24;
  static const double espacio6 = 32;

  /// Esquina de las filas de en medio de un grupo (Ajustes en Perfil).
  static const double radioInterno = 6;

  /// Esquina de campos de texto, filas, series y avisos.
  static const double radioCampo = 18;

  /// Esquina de tarjetas y opciones grandes.
  static const double radioTarjeta = 20;

  /// Esquina de la tarjeta destacada (temporizador) y de los diálogos.
  static const double radioGrande = 28;

  /// Esquina de arriba de la hoja inferior.
  static const double radioHoja = 32;

  /// Alto del botón principal y secundario.
  static const double altoBoton = 56;

  /// Alto del botón principal en inicio de sesión y Premium.
  static const double altoBotonGrande = 60;

  /// Alto de botones chicos y redondos (Volver, "+15 s").
  static const double altoBotonChico = 44;

  /// Alto de los campos de texto.
  static const double altoCampo = 56;

  /// Alto mínimo de una fila de ajustes.
  static const double altoFila = 52;

  /// Zona mínima que se puede tocar.
  static const double toqueMinimo = 44;

  /// Alto de la barra de navegación (píldora).
  static const double altoBarra = 72;

  /// Tamaño del círculo de cada pestaña dentro de la barra.
  static const double botonBarra = 58;
}
