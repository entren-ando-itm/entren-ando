import 'dart:io';

import 'package:entren_ando/features/nutricion/comidas_repositorio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pruebas del registro de comidas (ENT-45). No necesitan emulador.
void main() {
  test('La descripción es obligatoria y corta', () {
    expect(ValidarComida.descripcion(''), isNotNull);
    expect(ValidarComida.descripcion('   '), isNotNull);
    expect(ValidarComida.descripcion(null), isNotNull);
    expect(ValidarComida.descripcion('x' * 121), isNotNull);
    expect(ValidarComida.descripcion('Avena con plátano y leche'), isNull);
  });

  test('Calorías enteras y mayores o iguales a 0, como el CHECK', () {
    expect(ValidarComida.calorias(''), isNotNull);
    expect(ValidarComida.calorias('-1'), isNotNull);
    expect(ValidarComida.calorias('420.5'), isNotNull);
    expect(ValidarComida.calorias('abc'), isNotNull);
    expect(ValidarComida.calorias('20000'), isNotNull);
    expect(ValidarComida.calorias('0'), isNull);
    expect(ValidarComida.calorias(' 420 '), isNull);
  });

  test('Macros opcionales, con punto o coma, y no negativas', () {
    expect(ValidarComida.gramos(''), isNull);
    expect(ValidarComida.gramos(null), isNull);
    expect(ValidarComida.gramos('12,5'), isNull);
    expect(ValidarComida.gramos('-3'), isNotNull);
    expect(ValidarComida.gramos('x'), isNotNull);
    expect(ValidarComida.numero('12,56'), 12.6);
    expect(ValidarComida.numero(''), isNull);
  });

  test('Los totales sin macros no dibujan la barra', () {
    expect(const TotalesDia(calorias: 500).tieneMacros, isFalse);
    expect(const TotalesDia(calorias: 500, proteinas: 20).tieneMacros, isTrue);
  });

  test('Los datos capturados usan las columnas de registro_comida', () {
    final esquema = File('lib/core/db/esquema.sql').readAsStringSync();
    final tabla = RegExp(r'CREATE TABLE registro_comida \(([\s\S]*?)\n\);').firstMatch(esquema)!.group(1)!;
    const datos = DatosComida(descripcion: 'Avena', calorias: 420, proteinas: 12);
    for (final columna in datos.aFila().keys) {
      expect(tabla, contains(RegExp('\\b$columna\\b')), reason: columna);
    }
  });
}
