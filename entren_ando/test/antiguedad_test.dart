import 'package:entren_ando/features/calendario/override/antiguedad.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regla de los 30 días (ENT-70 / ENT-117, RF-10). Sin emulador.
void main() {
  final hoy = DateTime.utc(2026, 11, 25);

  test('Cuenta días naturales', () {
    expect(diasDeAntiguedad('2026-11-25', hoy: hoy), 0);
    expect(diasDeAntiguedad('2026-11-24', hoy: hoy), 1);
    expect(diasDeAntiguedad('2026-10-26', hoy: hoy), 30);
    expect(diasDeAntiguedad('2026-11-26', hoy: hoy), -1);
  });

  test('Hace 10 días sí se puede editar', () {
    expect(sePuedeEditar('2026-11-15', hoy: hoy), isTrue);
  });

  test('Justo 30 días sí, 31 o 35 ya no', () {
    expect(sePuedeEditar('2026-10-26', hoy: hoy), isTrue);
    expect(sePuedeEditar('2026-10-25', hoy: hoy), isFalse);
    expect(sePuedeEditar('2026-10-21', hoy: hoy), isFalse);
  });

  test('Los días futuros no tienen override', () {
    expect(sePuedeEditar('2026-11-26', hoy: hoy), isFalse);
  });

  test('Funciona al cruzar de mes y de año', () {
    expect(diasDeAntiguedad('2026-12-31', hoy: DateTime.utc(2027, 1, 1)), 1);
  });
}
