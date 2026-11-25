import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../../core/db/base_datos.dart';
import '../../../core/db/escritura_local.dart';
import '../../../core/db/fechas.dart';
import '../../../core/db/usuario_actual.dart';
import 'antiguedad.dart';

/// "Forzar a completado" un día gris que se olvidó registrar (ENT-70 / ENT-118,
/// RF-09, CU-07).
///
/// Crea la sesión de ese día con `es_override = 1` y estado 'completa', y copia
/// los ejercicios y series de la última sesión del mismo día de la rutina; si no
/// hay ninguna, usa los objetivos de la plantilla. Todo en una transacción y en
/// la base local, así que funciona sin internet.
class OverrideRepositorio {
  OverrideRepositorio(this._bd, this._idUsuario);

  final Database _bd;
  final String _idUsuario;

  /// Marca [fecha] ('AAAA-MM-DD') como completada.
  ///
  /// Lanza [StateError] con un mensaje para mostrar si no se puede: día de más
  /// de 30 días o futuro (RF-10), día que ya tiene sesión, o sin rutina ese día.
  Future<void> forzarCompletado(String fecha) async {
    if (!sePuedeEditar(fecha)) {
      throw StateError('Ese día ya no se puede cambiar: solo los últimos $diasEditables días.');
    }

    await _bd.transaction((txn) async {
      final escritura = EscrituraLocal(txn);

      final existentes = await txn.rawQuery('''
        SELECT 1 FROM sesion_entrenamiento
        WHERE id_usuario = ? AND fecha = ? AND eliminado = 0
        LIMIT 1
      ''', [_idUsuario, fecha]);
      if (existentes.isNotEmpty) throw StateError('Ese día ya tiene un registro.');

      // El día de la rutina que tocaba (ciclo activo, mismo día de la semana).
      final diaSemana = Fechas.deTexto(fecha).weekday;
      final dias = await txn.rawQuery('''
        SELECT d.id_dia
        FROM dia_rutina d
        JOIN ciclo_rutina c ON c.id_ciclo = d.id_ciclo
        WHERE c.id_usuario = ? AND c.estado = 'activo' AND c.eliminado = 0
          AND d.eliminado = 0 AND d.dia_semana = ? AND d.es_descanso = 0
        LIMIT 1
      ''', [_idUsuario, diaSemana]);
      if (dias.isEmpty) throw StateError('Ese día no tenía entrenamiento en tu rutina.');
      final idDia = dias.first['id_dia'] as String;

      final idSesion = (await escritura.insertar('sesion_entrenamiento', {
        'id_usuario': _idUsuario,
        'id_dia': idDia,
        'fecha': fecha,
        'estado': 'completa',
        'es_override': 1,
        'comentario': 'Marcado después',
      }))!;

      // 1. La última sesión del mismo día de la rutina (antes de esa fecha) con ejercicios.
      final ultimas = await txn.rawQuery('''
        SELECT s.id_sesion
        FROM sesion_entrenamiento s
        WHERE s.id_usuario = ? AND s.id_dia = ? AND s.fecha < ? AND s.eliminado = 0
          AND EXISTS (SELECT 1 FROM registro_ejercicio r
                      WHERE r.id_sesion = s.id_sesion AND r.eliminado = 0)
        ORDER BY s.fecha DESC
        LIMIT 1
      ''', [_idUsuario, idDia, fecha]);

      if (ultimas.isNotEmpty) {
        await _copiarSesion(txn, escritura, ultimas.first['id_sesion'] as String, idSesion);
      } else {
        await _desdeObjetivos(txn, escritura, idDia, idSesion);
      }
    });
  }

  /// Copia registros y series de [origen] a [destino]; todos quedan completados.
  Future<void> _copiarSesion(
    Transaction txn,
    EscrituraLocal escritura,
    String origen,
    String destino,
  ) async {
    final registros = await txn.rawQuery('''
      SELECT id_registro, id_programado, id_ejercicio, es_sustitucion, orden
      FROM registro_ejercicio
      WHERE id_sesion = ? AND eliminado = 0
      ORDER BY orden
    ''', [origen]);
    for (final r in registros) {
      final idRegistro = (await escritura.insertar('registro_ejercicio', {
        'id_sesion': destino,
        'id_programado': r['id_programado'],
        'id_ejercicio': r['id_ejercicio'],
        'es_sustitucion': r['es_sustitucion'],
        'orden': r['orden'],
        'completado': 1,
      }))!;
      final series = await txn.rawQuery('''
        SELECT numero_serie, peso_kg, repeticiones
        FROM serie
        WHERE id_registro = ? AND eliminado = 0
        ORDER BY numero_serie
      ''', [r['id_registro']]);
      for (final s in series) {
        await escritura.insertar('serie', {
          'id_registro': idRegistro,
          'numero_serie': s['numero_serie'],
          'peso_kg': s['peso_kg'],
          'repeticiones': s['repeticiones'],
        });
      }
    }
  }

  /// Sin sesión previa: un registro por ejercicio con sus series objetivo.
  Future<void> _desdeObjetivos(
    Transaction txn,
    EscrituraLocal escritura,
    String idDia,
    String destino,
  ) async {
    final programados = await txn.rawQuery('''
      SELECT id_programado, id_ejercicio, orden, series_objetivo, reps_objetivo, peso_objetivo_kg
      FROM ejercicio_programado
      WHERE id_dia = ? AND eliminado = 0
      ORDER BY orden
    ''', [idDia]);
    for (final p in programados) {
      final idRegistro = (await escritura.insertar('registro_ejercicio', {
        'id_sesion': destino,
        'id_programado': p['id_programado'],
        'id_ejercicio': p['id_ejercicio'],
        'es_sustitucion': 0,
        'orden': p['orden'],
        'completado': 1,
      }))!;
      for (var n = 1; n <= (p['series_objetivo'] as int); n++) {
        await escritura.insertar('serie', {
          'id_registro': idRegistro,
          'numero_serie': n,
          'peso_kg': p['peso_objetivo_kg'] ?? 0,
          'repeticiones': p['reps_objetivo'],
        });
      }
    }
  }
}

/// Repositorio del override para el usuario actual (null si no hay usuario).
final overrideRepositorioProvider = FutureProvider<OverrideRepositorio?>((ref) async {
  final idUsuario = ref.watch(usuarioActualIdProvider);
  if (idUsuario == null) return null;
  final bd = await ref.watch(baseDatosProvider.future);
  return OverrideRepositorio(bd, idUsuario);
});
