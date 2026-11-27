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
  const delServidor = {'suscripcion', 'solicitud_ia', 'evento_pago', 'feedback_ia'};

  test('Una edición sin red sube el nombre y conserva el plan del servidor', () {
    final usuario = MotorSync.aNube(MotorSync.tablas.first, {
      'id_plan': 1, 'nombre': 'Nombre editado', 'pendiente_sync': 1,
    });
    expect(usuario.containsKey('id_plan'), isFalse);
    expect(usuario['nombre'], 'Nombre editado');
  });

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

  test('Las tablas sin id_usuario llegan al usuario por su padre', () {
    final foraneas = llavesForaneas();
    for (final tabla in MotorSync.tablas) {
      expect('?'.allMatches(tabla.dueno).length, 1, reason: tabla.nombre);
      expect(tabla.dueno, contains('id_usuario = ?'), reason: tabla.nombre);
      if (tabla.porUsuario) continue;
      // El filtro empieza por la columna que apunta a su padre.
      final padres = foraneas[tabla.nombre]!.difference(catalogos);
      expect(
        padres.any((padre) => tabla.dueno.contains('FROM $padre')),
        isTrue,
        reason: '${tabla.nombre} se filtra por ${tabla.dueno}',
      );
    }
  });

  // Revisión de Pablo en el PR #11: el ciclo demo y la comida escaneada apuntan
  // a solicitudes de IA que la app no puede crear en la nube (RLS). Si no
  // existen en Supabase, se rechaza el ciclo y todo lo que cuelga de él.
  test('Las solicitudes de IA del demo se crean en supabase/ajustes_ent44.sql', () {
    final datos = File('lib/core/db/datos_prueba.sql').readAsStringSync();
    final ajustes = File('../supabase/ajustes_ent44.sql').readAsStringSync();
    final insert = RegExp(r'INSERT INTO solicitud_ia[\s\S]*?;').firstMatch(datos)!.group(0)!;
    final ids = RegExp(r"'(0000000\d-0000-4000-8000-\d{12})'").allMatches(insert).map((m) => m.group(1)!).toSet();
    expect(ids, isNotEmpty);
    final enAjustes = RegExp(r'INSERT INTO solicitud_ia[\s\S]*?;').firstMatch(ajustes)!.group(0)!;
    for (final id in ids) {
      expect(enAjustes, contains(id), reason: 'Falta la solicitud $id en ajustes_ent44.sql');
    }
  });

  test('Se bajan todas las tablas del usuario, incluidas las que crea el servidor', () {
    final todas = llavesForaneas().keys.toSet();
    final bajadas = MotorSync.tablasBajar.map((t) => t.nombre).toSet();
    expect(bajadas, todas.difference(catalogos));
    expect(MotorSync.tablasBajar.length, bajadas.length, reason: 'sin tablas repetidas');
  });

  test('Al bajar, cada tabla llega después de las tablas a las que apunta', () {
    final foraneas = llavesForaneas();
    final orden = MotorSync.tablasBajar.map((t) => t.nombre).toList();
    for (final (i, tabla) in orden.indexed) {
      for (final padre in foraneas[tabla]!) {
        if (catalogos.contains(padre) || padre == tabla) continue;
        expect(orden.indexOf(padre), lessThan(i), reason: '$tabla apunta a $padre');
      }
      final cuerpo = RegExp('CREATE TABLE $tabla \\(([\\s\\S]*?)\\n\\);').firstMatch(esquema)!.group(1)!;
      final llaves = MotorSync.tablasBajar[i].llaves;
      expect(cuerpo, contains('PRIMARY KEY (${llaves.join(', ')})'), reason: tabla);
    }
  });

  test('Lo que baja de la nube pasa a 0/1, JSON a texto y llega sin pendiente', () {
    final fila = MotorSync.aLocal(
      {
        'id_feedback': 'abc',
        'leido': true,
        'detecto_estancamiento': false,
        'eliminado': false,
        'pendiente_sync': false,
        'datos': {'volumen': 1200},
        'peso_kg': 60.5,
        'columna_que_no_hay': 'x',
      },
      {'id_feedback', 'leido', 'detecto_estancamiento', 'eliminado', 'pendiente_sync', 'datos', 'peso_kg'},
    );
    expect(fila['leido'], 1);
    expect(fila['detecto_estancamiento'], 0);
    expect(fila['eliminado'], 0);
    expect(fila['pendiente_sync'], 0);
    expect(fila['datos'], '{"volumen":1200}');
    expect(fila['peso_kg'], 60.5);
    expect(fila.containsKey('columna_que_no_hay'), isFalse);
  });

  test('La regla de los 30 días usa el mismo código en la nube y en el celular', () {
    final ajustes = File('../supabase/ajustes_ent53.sql').readAsStringSync();
    expect(ajustes, contains("ERRCODE = '${MotorSync.codigoRegla30Dias}'"));
    for (final tabla in ['sesion_entrenamiento', 'registro_ejercicio', 'serie']) {
      expect(ajustes, contains('BEFORE UPDATE ON public.$tabla'), reason: tabla);
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
