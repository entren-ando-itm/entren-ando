import 'dart:io';

import 'package:entren_ando/features/perfil/perfil_repositorio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pruebas de las validaciones del perfil (ENT-18). No necesitan emulador.
void main() {
  test('Días por semana: de 1 a 7, como el CHECK', () {
    expect(ValidarPerfil.diasPorSemana('9'), isNotNull);
    expect(ValidarPerfil.diasPorSemana('0'), isNotNull);
    expect(ValidarPerfil.diasPorSemana(''), isNotNull);
    expect(ValidarPerfil.diasPorSemana('abc'), isNotNull);
    expect(ValidarPerfil.diasPorSemana('1'), isNull);
    expect(ValidarPerfil.diasPorSemana(' 7 '), isNull);
  });

  test('Peso y estatura mayores que 0, con punto o coma', () {
    expect(ValidarPerfil.pesoKg('0'), isNotNull);
    expect(ValidarPerfil.pesoKg('-5'), isNotNull);
    expect(ValidarPerfil.pesoKg(''), isNotNull);
    expect(ValidarPerfil.pesoKg('72,5'), isNull);
    expect(ValidarPerfil.numero('72,5'), 72.5);
    expect(ValidarPerfil.estaturaCm('0'), isNotNull);
    expect(ValidarPerfil.estaturaCm('175'), isNull);
  });

  test('La grasa es opcional y va de 0 a 100', () {
    expect(ValidarPerfil.porcentajeGrasa(''), isNull);
    expect(ValidarPerfil.porcentajeGrasa(null), isNull);
    expect(ValidarPerfil.porcentajeGrasa('18.5'), isNull);
    expect(ValidarPerfil.porcentajeGrasa('0'), isNotNull);
    expect(ValidarPerfil.porcentajeGrasa('100'), isNotNull);
    expect(ValidarPerfil.porcentajeGrasa('x'), isNotNull);
  });

  test('Objetivos y niveles son los mismos que el CHECK del esquema', () {
    final esquema = File('lib/core/db/esquema.sql').readAsStringSync();
    List<String> valoresCheck(String columna) {
      final coincidencia = RegExp('CHECK \\($columna IN \\(([^)]*)\\)\\)').firstMatch(esquema)!;
      return RegExp("'([^']+)'").allMatches(coincidencia.group(1)!).map((m) => m.group(1)!).toList();
    }

    expect(objetivosPerfil.keys.toList(), valoresCheck('objetivo'));
    expect(nivelesPerfil.keys.toList(), valoresCheck('nivel_experiencia'));
    expect(ValidarPerfil.objetivo('volumen'), isNotNull);
    expect(ValidarPerfil.nivel('experto'), isNotNull);
  });
}
