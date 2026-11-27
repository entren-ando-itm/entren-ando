import 'package:entren_ando/features/entrenamiento/bitacora/bitacora_repositorio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pruebas de la precarga de la bitácora (ENT-88). No necesitan emulador.
void main() {
  test('Si nunca lo hice, trae los objetivos de la rutina', () {
    final series = armarSeries(
      seriesObjetivo: 4,
      repsObjetivo: 8,
      pesoObjetivoKg: 60,
      hoy: const {},
      ultimaVez: const [],
    );
    expect(series, hasLength(4));
    expect(series.every((s) => s.origen == OrigenSerie.objetivo), isTrue);
    expect(series.first.pesoKg, 60);
    expect(series.first.repeticiones, 8);
    expect(series.map((s) => s.numero), [1, 2, 3, 4]);
  });

  test('Trae el peso y las repeticiones de la última vez, serie por serie', () {
    final series = armarSeries(
      seriesObjetivo: 3,
      repsObjetivo: 10,
      pesoObjetivoKg: 50,
      hoy: const {},
      ultimaVez: const [
        (pesoKg: 62.5, repeticiones: 8),
        (pesoKg: 62.5, repeticiones: 8),
        (pesoKg: 60, repeticiones: 7),
      ],
    );
    expect(series.every((s) => s.origen == OrigenSerie.ultimaVez), isTrue);
    expect(series[2].pesoKg, 60);
    expect(series[2].repeticiones, 7);
  });

  test('Si la última vez hice menos series, repite la última', () {
    final series = armarSeries(
      seriesObjetivo: 4,
      repsObjetivo: 10,
      pesoObjetivoKg: null,
      hoy: const {},
      ultimaVez: const [(pesoKg: 20, repeticiones: 12), (pesoKg: 22.5, repeticiones: 10)],
    );
    expect(series, hasLength(4));
    expect(series[3].pesoKg, 22.5);
    expect(series[3].repeticiones, 10);
  });

  test('Lo guardado hoy gana y se conservan series extra', () {
    final series = armarSeries(
      seriesObjetivo: 3,
      repsObjetivo: 10,
      pesoObjetivoKg: 40,
      hoy: const {1: (pesoKg: 45, repeticiones: 9), 4: (pesoKg: 40, repeticiones: 6)},
      ultimaVez: const [],
    );
    expect(series, hasLength(4));
    expect(series[0].guardada, isTrue);
    expect(series[0].pesoKg, 45);
    expect(series[1].origen, OrigenSerie.objetivo);
    expect(series[3].guardada, isTrue);
  });

  test('Sin peso en la rutina (peso corporal) precarga 0 kg', () {
    final series = armarSeries(
      seriesObjetivo: 2,
      repsObjetivo: 15,
      pesoObjetivoKg: null,
      hoy: const {},
      ultimaVez: const [],
    );
    expect(series.first.pesoKg, 0);
  });

  group('Estado de la sesión: 80% de las series (ENT-90 y ENT-121)', () {
    test('Completa: todas las series hechas', () {
      expect(
        estadoSesion(const [
          (completado: true, seriesHechas: 4, seriesObjetivo: 4),
          (completado: true, seriesHechas: 3, seriesObjetivo: 3),
        ]),
        'completa',
      );
    });

    test('Completa: 13 de 16 series (81%) aunque un ejercicio quedó parcial', () {
      expect(
        estadoSesion(const [
          (completado: true, seriesHechas: 4, seriesObjetivo: 4),
          (completado: true, seriesHechas: 4, seriesObjetivo: 4),
          (completado: true, seriesHechas: 4, seriesObjetivo: 4),
          (completado: true, seriesHechas: 1, seriesObjetivo: 4),
        ]),
        'completa',
      );
    });

    test('Parcial: 12 de 16 series (75%)', () {
      expect(
        estadoSesion(const [
          (completado: true, seriesHechas: 4, seriesObjetivo: 4),
          (completado: true, seriesHechas: 4, seriesObjetivo: 4),
          (completado: true, seriesHechas: 4, seriesObjetivo: 4),
          (completado: false, seriesHechas: 0, seriesObjetivo: 4),
        ]),
        'parcial',
      );
    });

    test('Exactamente 80% cuenta como completa', () {
      expect(
        estadoSesion(const [
          (completado: true, seriesHechas: 4, seriesObjetivo: 5),
        ]),
        'completa',
      );
    });

    test('Las series de más no compensan las que faltan en otro ejercicio', () {
      expect(
        estadoSesion(const [
          (completado: true, seriesHechas: 8, seriesObjetivo: 4),
          (completado: false, seriesHechas: 0, seriesObjetivo: 4),
        ]),
        'parcial',
      );
    });

    test('Parcial: un día sin ejercicios no cuenta como completo', () {
      expect(estadoSesion(const []), 'parcial');
    });

    test('El umbral es 80%', () {
      expect(umbralDiaCompleto, 0.8);
    });
  });
}
