import 'package:entren_ando/features/rutinas/alternativas/alternativas_repositorio.dart';
import 'package:entren_ando/features/rutinas/rutinas_repositorio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pruebas de alternativas por ejercicio (ENT-48). No necesitan emulador.
void main() {
  test('Se permiten hasta 3 alternativas (criterio 1)', () {
    expect(AlternativasRepositorio.maximo, 3);
    expect(
      AlternativasRepositorio.validarNueva(idEjercicio: 9, idEjercicioPrincipal: 1, yaElegidos: [2, 3]),
      isNull,
    );
    expect(
      AlternativasRepositorio.validarNueva(idEjercicio: 9, idEjercicioPrincipal: 1, yaElegidos: [2, 3, 4]),
      isNotNull,
    );
  });

  test('No se repite una alternativa ni el mismo ejercicio (criterio 2)', () {
    expect(
      AlternativasRepositorio.validarNueva(idEjercicio: 2, idEjercicioPrincipal: 1, yaElegidos: [2]),
      'Ya es una de sus alternativas.',
    );
    expect(
      AlternativasRepositorio.validarNueva(idEjercicio: 1, idEjercicioPrincipal: 1, yaElegidos: []),
      'Es el mismo ejercicio de la rutina.',
    );
  });

  test('Las alternativas usan el alias y se ordenan por prioridad', () {
    final sql = AlternativasRepositorio.consultaAlternativas;
    expect(sql, contains('COALESCE(ue.nombre_alias, e.nombre_oficial)'));
    expect(sql, contains('a.eliminado = 0'));
    expect(sql, contains('ORDER BY a.prioridad'));
  });

  test('Los ejercicios del día cuentan sus alternativas vigentes', () {
    expect(RutinasRepositorio.consultaEjerciciosDelDia, contains('FROM alternativa_ejercicio a'));
    expect(RutinasRepositorio.consultaEjerciciosDelDia, contains('a.eliminado = 0'));
  });
}
