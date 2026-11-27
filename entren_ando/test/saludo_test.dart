import 'package:entren_ando/features/entrenamiento/pantalla_hoy.dart';
import 'package:flutter_test/flutter_test.dart';

/// ENT-127: saludo de Hoy según la hora de Ciudad de México.
void main() {
  test('Buenos días de 5:00 a 11:59', () {
    expect(saludoSegunHora(5), 'Buenos días');
    expect(saludoSegunHora(11), 'Buenos días');
  });
  test('Buenas tardes de 12:00 a 18:59', () {
    expect(saludoSegunHora(12), 'Buenas tardes');
    expect(saludoSegunHora(18), 'Buenas tardes');
  });
  test('Buenas noches de 19:00 a 4:59', () {
    expect(saludoSegunHora(19), 'Buenas noches');
    expect(saludoSegunHora(0), 'Buenas noches');
    expect(saludoSegunHora(4), 'Buenas noches');
  });
}
