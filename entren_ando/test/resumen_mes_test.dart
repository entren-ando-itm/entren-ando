import 'package:entren_ando/core/diseno.dart';
import 'package:entren_ando/features/calendario/resumen_mes.dart';
import 'package:flutter_test/flutter_test.dart';

/// Resumen del mes (ENT-71 / ENT-119). Sin emulador.
void main() {
  test('Cumplimiento: completos + mitad de parciales entre los días que tocaba entrenar', () {
    final r = calcularResumen(
      conteo: const {
        EstadoDia.completo: 4,
        EstadoDia.parcial: 2,
        EstadoDia.sinActividad: 4,
        EstadoDia.descanso: 10,
      },
      series: const [],
    );
    expect(r.porcentaje, 50); // (4 + 1) / 10
  });

  test('Sin días de entrenamiento todavía no hay porcentaje', () {
    final r = calcularResumen(conteo: const {EstadoDia.descanso: 3}, series: const []);
    expect(r.porcentaje, isNull);
  });

  test('Volumen = suma de peso × repeticiones', () {
    final r = calcularResumen(conteo: const {}, series: const [
      (idEjercicio: 1, nombre: 'Sentadilla', pesoKg: 60, repeticiones: 10),
      (idEjercicio: 1, nombre: 'Sentadilla', pesoKg: 62.5, repeticiones: 8),
      (idEjercicio: 2, nombre: 'Plancha', pesoKg: 0, repeticiones: 45),
    ]);
    expect(r.volumenKg, 1100);
  });

  test('Top 3 de progreso: última contra primera serie, solo los que subieron', () {
    final r = calcularResumen(conteo: const {}, series: const [
      (idEjercicio: 1, nombre: 'Sentadilla', pesoKg: 60, repeticiones: 10),
      (idEjercicio: 2, nombre: 'Press de banca', pesoKg: 40, repeticiones: 8),
      (idEjercicio: 3, nombre: 'Remo', pesoKg: 30, repeticiones: 10),
      (idEjercicio: 4, nombre: 'Curl', pesoKg: 12, repeticiones: 10),
      (idEjercicio: 5, nombre: 'Dominadas', pesoKg: 0, repeticiones: 8),
      (idEjercicio: 1, nombre: 'Sentadilla', pesoKg: 70, repeticiones: 8),
      (idEjercicio: 2, nombre: 'Press de banca', pesoKg: 42.5, repeticiones: 8),
      (idEjercicio: 3, nombre: 'Remo', pesoKg: 35, repeticiones: 10),
      (idEjercicio: 4, nombre: 'Curl', pesoKg: 10, repeticiones: 10),
    ]);
    expect(r.top.map((p) => p.nombre), ['Sentadilla', 'Remo', 'Press de banca']);
    expect(r.top.first.diferenciaKg, 10);
  });
}
