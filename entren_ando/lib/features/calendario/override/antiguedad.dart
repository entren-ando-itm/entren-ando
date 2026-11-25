import '../../../core/db/fechas.dart';

/// Regla de los 30 días (RF-10, ENT-70 / ENT-117).
///
/// Es la **única** función que decide si un día todavía se puede cambiar. La
/// usan el calendario (override) y la bitácora, y el servidor valida lo mismo
/// (ENT-53, código EA010). Cuenta días naturales con la hora de Ciudad de México.

/// Días máximos hacia atrás que se pueden editar.
const int diasEditables = 30;

/// Cuántos días naturales tiene [fecha] ('AAAA-MM-DD') respecto a hoy.
/// 0 = hoy, 1 = ayer, negativo = un día que todavía no llega.
int diasDeAntiguedad(String fecha, {DateTime? hoy}) {
  final referencia = hoy ?? Fechas.hoyComoFecha();
  return referencia.difference(Fechas.deTexto(fecha)).inDays;
}

/// true si el día se puede cambiar: de hoy hasta hace [diasEditables] días.
/// Los días futuros y los de más de 30 días no se editan.
bool sePuedeEditar(String fecha, {DateTime? hoy}) {
  final dias = diasDeAntiguedad(fecha, hoy: hoy);
  return dias >= 0 && dias <= diasEditables;
}
