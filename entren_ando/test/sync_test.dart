import 'dart:io';

import 'package:entren_ando/core/sync/motor_sync.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pruebas del motor de sincronización (ENT-44). No necesitan emulador ni red.
void main() {
  final esquema = File('lib/core/db/esquema.sql').readAsStringSync();

  /// Tabla → tablas a las que apunta con FOREIGN KEY.
  Map<String, Set<String>> llavesForaneas() {
    final resultado = <String, Set<String>>{};
    for (final m in RegExp(r'CREATE TABLE (\w+) \(([\s\S]*?)\n\);').allMatches(esquema)) {
      resultado[m.group(1)!] = {
        for (final r in RegExp(r'REFERENCES (\w+)').allMatches(m.group(2)!)) r.group(1)!,
      };
    }
    return resultado;
  }

  const catalogos = {'plan', 'equipo', 'ejercicio'};
  // Las crea el servidor (Edge Functions); feedback_ia se sube aparte (solo leido).
  const delServidor = {'solicitud_ia', 'evento_pago', 'feedback_ia'};

  test('Se suben todas las tablas del usuario, sin catálogos ni las del servidor', () {
    final todas = llavesForaneas().keys.toSet();
    final subidas = MotorSync.tablas.map((t) => t.nombre).toSet();
    expect(subidas, todas.difference(catalogos).difference(delServidor));
  });

  test('Cada tabla se sube después de las tablas a las que apunta', () {
    final foraneas = llavesForaneas();
    final orden = MotorSync.tablas.map((t) => t.nombre).toList();
    for (final (i, tabla) in orden.indexed) {
      for (final padre in foraneas[tabla]!) {
        if (catalogos.contains(padre) || delServidor.contains(padre) || padre == tabla) continue;
        expect(orden.indexOf(padre), lessThan(i), reason: '$tabla apunta a $padre');
      }
    }
  });

  test('Las llaves y la columna id_usuario coinciden con el esquema', () {
    for (final tabla in MotorSync.tablas) {
      final cuerpo = RegExp('CREATE TABLE ${tabla.nombre} \\(([\\s\\S]*?)\\n\\);').firstMatch(esquema)!.group(1)!;
      expect(cuerpo, contains('PRIMARY KEY (${tabla.llaves.join(', ')})'), reason: tabla.nombre);
      expect(RegExp(r'^\s+id_usuario\s', multiLine: true).hasMatch(cuerpo), tabla.porUsuario, reason: tabla.nombre);
    }
  });

  test('Los 0/1 pasan a boolean y pendiente_sync va en false', () {
    const tabla = TablaSync('registro_ejercicio', ['id_registro'], booleanas: ['completado']);
    final fila = MotorSync.aNube(tabla, {
      'id_registro': 'abc',
      'completado': 1,
      'eliminado': 0,
      'pendiente_sync': 1,
      'peso_kg': 60.5,
    });
    expect(fila['completado'], isTrue);
    expect(fila['eliminado'], isFalse);
    expect(fila['pendiente_sync'], isFalse);
    expect(fila['peso_kg'], 60.5);
  });
}
