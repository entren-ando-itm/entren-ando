/// Fechas con la hora de Ciudad de México.
///
/// Desde octubre de 2022 Ciudad de México ya no cambia de horario: es UTC-6
/// todo el año. Por eso se calcula con un desfase fijo y no depende de la
/// zona horaria del celular o del emulador.
///
/// Formatos que usa la base:
///   * Fecha (columnas DATE): '2026-11-09'
///   * Fecha y hora: '2026-11-09T07:30:00-06:00'
///   * Hora (columnas TIME): '07:30:00'
class Fechas {
  Fechas._();

  static const Duration _desfase = Duration(hours: -6);
  static const String _sufijo = '-06:00';

  /// Fecha y hora actuales de Ciudad de México.
  ///
  /// Es un DateTime en modo UTC con la hora ya ajustada: úsalo para leer el
  /// día, la hora o el día de la semana, y para sumar o restar días sin que
  /// afecten los cambios de horario.
  static DateTime ahoraCdmx() => DateTime.now().toUtc().add(_desfase);

  /// Fecha y hora actual en ISO 8601, por ejemplo '2026-11-09T07:30:00-06:00'.
  static String ahoraIso() => isoDe(ahoraCdmx());

  /// Fecha de hoy, por ejemplo '2026-11-09'.
  static String hoy() => fecha(ahoraCdmx());

  /// Hoy a medianoche (modo UTC), para calcular rangos de días.
  static DateTime hoyComoFecha() {
    final ahora = ahoraCdmx();
    return DateTime.utc(ahora.year, ahora.month, ahora.day);
  }

  /// 'AAAA-MM-DD' de una fecha.
  static String fecha(DateTime f) =>
      '${f.year.toString().padLeft(4, '0')}-${_dos(f.month)}-${_dos(f.day)}';

  /// 'HH:MM:SS' de una hora.
  static String hora(DateTime f) =>
      '${_dos(f.hour)}:${_dos(f.minute)}:${_dos(f.second)}';

  /// 'AAAA-MM-DDTHH:MM:SS-06:00' de una fecha y hora de Ciudad de México.
  static String isoDe(DateTime f) => '${fecha(f)}T${hora(f)}$_sufijo';

  /// Convierte 'AAAA-MM-DD' en una fecha a medianoche (modo UTC).
  static DateTime deTexto(String texto) {
    final partes = texto.substring(0, 10).split('-');
    return DateTime.utc(
      int.parse(partes[0]),
      int.parse(partes[1]),
      int.parse(partes[2]),
    );
  }

  static String _dos(int n) => n.toString().padLeft(2, '0');
}
