import 'dart:io';

import 'package:entren_ando/core/db/fechas.dart';
import 'package:entren_ando/core/db/script_sql.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pruebas rápidas del proyecto base (no necesitan emulador):
///   flutter test
void main() {
  test('El divisor respeta textos con punto y coma y quita comentarios', () {
    final sentencias = ScriptSql.dividir(
      "-- comentario; con punto y coma\n"
      "INSERT INTO t VALUES ('a;b');\n"
      "/* bloque; */ INSERT INTO t VALUES ('it''s')",
    );
    expect(sentencias, [
      "INSERT INTO t VALUES ('a;b')",
      "INSERT INTO t VALUES ('it''s')",
    ]);
  });

  test('El esquema tiene las 20 tablas del modelo con sus nombres', () {
    final esquema = File('lib/core/db/esquema.sql').readAsStringSync();
    final tablas = ScriptSql.dividir(esquema)
        .where((s) => s.startsWith('CREATE TABLE'))
        .map((s) => s.split(RegExp(r'\s+'))[2])
        .toList();
    expect(tablas, [
      'plan', 'usuario', 'perfil_entrenamiento', 'medicion_biometrica',
      'equipo', 'usuario_equipo', 'ejercicio', 'usuario_ejercicio',
      'solicitud_ia', 'ciclo_rutina', 'dia_rutina', 'ejercicio_programado',
      'alternativa_ejercicio', 'sesion_entrenamiento', 'registro_ejercicio',
      'serie', 'registro_comida', 'feedback_ia', 'suscripcion', 'evento_pago',
    ]);
  });

  test('Las fechas usan el formato de la base', () {
    final fecha = DateTime.utc(2026, 11, 9, 7, 5, 3);
    expect(Fechas.fecha(fecha), '2026-11-09');
    expect(Fechas.isoDe(fecha), '2026-11-09T07:05:03-06:00');
    expect(Fechas.deTexto('2026-11-09T07:05:03-06:00'), DateTime.utc(2026, 11, 9));
    expect(RegExp(r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d-06:00$').hasMatch(Fechas.ahoraIso()), isTrue);
  });
}
