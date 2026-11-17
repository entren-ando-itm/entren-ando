import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../../core/db/base_datos.dart';
import '../../../core/db/escritura_local.dart';
import '../../../core/db/fechas.dart';
import '../../../core/db/usuario_actual.dart';

/// Bitácora rápida (ENT-49): leer y guardar las series de un ejercicio de hoy.
///
/// * ENT-87: al primer toque del día crea `sesion_entrenamiento` (una por usuario
///   y fecha, estado 'parcial'), un `registro_ejercicio` por ejercicio y cada
///   `serie`. Todo en la base local cifrada, así que funciona en modo avión.
/// * ENT-88: cada serie trae el peso y las repeticiones de la última vez que se
///   hizo ese `id_ejercicio`; si nunca se hizo, los objetivos de la rutina.
///
/// No modifica `ejercicio_programado`: la plantilla de la rutina no cambia.

/// De dónde salen los números que se muestran.
enum OrigenSerie {
  /// Ya se guardó hoy.
  hoy,

  /// Precargada de la última vez que se hizo el ejercicio.
  ultimaVez,

  /// Precargada de los objetivos de la rutina (nunca se ha hecho).
  objetivo,
}

/// Una serie de la bitácora.
class SerieBitacora {
  const SerieBitacora({
    required this.numero,
    required this.pesoKg,
    required this.repeticiones,
    required this.origen,
  });

  /// 1, 2, 3... (`serie.numero_serie`).
  final int numero;
  final double pesoKg;
  final int repeticiones;
  final OrigenSerie origen;

  /// true si ya está guardada hoy (se marcó con el ✓).
  bool get guardada => origen == OrigenSerie.hoy;

  SerieBitacora copiar({double? pesoKg, int? repeticiones, OrigenSerie? origen}) {
    return SerieBitacora(
      numero: numero,
      pesoKg: pesoKg ?? this.pesoKg,
      repeticiones: repeticiones ?? this.repeticiones,
      origen: origen ?? this.origen,
    );
  }
}

/// Un ejercicio de hoy con sus series para la pantalla del ejercicio (ENT-89).
class EjercicioBitacora {
  const EjercicioBitacora({
    required this.idProgramado,
    required this.idEjercicio,
    required this.nombre,
    required this.orden,
    required this.descansoSeg,
    required this.series,
    required this.completado,
    this.trabajoSeg,
    this.fechaUltimaVez,
  });

  final String idProgramado;
  final int idEjercicio;

  /// Alias del usuario o nombre oficial (RF-05).
  final String nombre;
  final int orden;
  final int descansoSeg;
  final int? trabajoSeg;
  final List<SerieBitacora> series;

  /// `registro_ejercicio.completado` de hoy (lo marca ENT-50 con "Terminar ejercicio").
  final bool completado;

  /// Fecha (DATE) de la última vez, para mostrar "La última vez: 4 de noviembre".
  final String? fechaUltimaVez;

  int get seriesGuardadas => series.where((s) => s.guardada).length;
}

/// Junta las series de hoy, las de la última vez y los objetivos (ENT-88).
///
/// Para cada número de serie, de 1 al mayor entre los objetivos y lo que ya se
/// guardó hoy: usa lo de hoy si existe; si no, la misma serie de la última vez;
/// si la última vez tuvo menos series, repite su última serie; y si nunca se
/// hizo, usa los objetivos. Es una función pura para poder probarla sin base.
List<SerieBitacora> armarSeries({
  required int seriesObjetivo,
  required int repsObjetivo,
  required double? pesoObjetivoKg,
  required Map<int, ({double pesoKg, int repeticiones})> hoy,
  required List<({double pesoKg, int repeticiones})> ultimaVez,
}) {
  final maxHoy = hoy.keys.fold<int>(0, (a, b) => a > b ? a : b);
  final total = seriesObjetivo > maxHoy ? seriesObjetivo : maxHoy;
  return [
    for (var numero = 1; numero <= total; numero++)
      if (hoy[numero] case final guardada?)
        SerieBitacora(
          numero: numero,
          pesoKg: guardada.pesoKg,
          repeticiones: guardada.repeticiones,
          origen: OrigenSerie.hoy,
        )
      else if (ultimaVez.isNotEmpty)
        SerieBitacora(
          numero: numero,
          pesoKg: ultimaVez[(numero <= ultimaVez.length ? numero : ultimaVez.length) - 1].pesoKg,
          repeticiones:
              ultimaVez[(numero <= ultimaVez.length ? numero : ultimaVez.length) - 1].repeticiones,
          origen: OrigenSerie.ultimaVez,
        )
      else
        SerieBitacora(
          numero: numero,
          pesoKg: pesoObjetivoKg ?? 0,
          repeticiones: repsObjetivo,
          origen: OrigenSerie.objetivo,
        ),
  ];
}

class BitacoraRepositorio {
  BitacoraRepositorio(this._bd, this._idUsuario);

  final Database _bd;
  final String _idUsuario;

  /// El ejercicio de hoy con sus series guardadas o precargadas (ENT-88).
  Future<EjercicioBitacora?> ejercicio(String idProgramado) async {
    final filas = await _bd.rawQuery('''
      SELECT ep.id_programado, ep.id_ejercicio, ep.orden, ep.series_objetivo, ep.reps_objetivo,
             ep.peso_objetivo_kg, ep.descanso_seg, ep.trabajo_seg,
             COALESCE(ue.nombre_alias, e.nombre_oficial) AS nombre
      FROM ejercicio_programado ep
      JOIN ejercicio e ON e.id_ejercicio = ep.id_ejercicio
      LEFT JOIN usuario_ejercicio ue
        ON ue.id_ejercicio = ep.id_ejercicio AND ue.id_usuario = ? AND ue.eliminado = 0
      WHERE ep.id_programado = ? AND ep.eliminado = 0
    ''', [_idUsuario, idProgramado]);
    if (filas.isEmpty) return null;
    final ep = filas.first;
    final idEjercicio = ep['id_ejercicio'] as int;
    final hoy = Fechas.hoy();

    // Lo que ya se guardó hoy para este ejercicio de la rutina.
    final registroHoy = await _registroDeHoy(_bd, idProgramado, hoy);
    final seriesHoy = <int, ({double pesoKg, int repeticiones})>{};
    if (registroHoy != null) {
      final filasHoy = await _bd.rawQuery('''
        SELECT numero_serie, peso_kg, repeticiones
        FROM serie
        WHERE id_registro = ? AND eliminado = 0
        ORDER BY numero_serie
      ''', [registroHoy.id]);
      for (final f in filasHoy) {
        seriesHoy[f['numero_serie'] as int] =
            (pesoKg: (f['peso_kg'] as num).toDouble(), repeticiones: f['repeticiones'] as int);
      }
    }

    // La última vez que se hizo el mismo id_ejercicio (antes de hoy), aunque
    // haya sido en otro día de la rutina o como sustitución.
    final ultimas = await _bd.rawQuery('''
      SELECT r.id_registro, s.fecha
      FROM registro_ejercicio r
      JOIN sesion_entrenamiento s ON s.id_sesion = r.id_sesion
      WHERE s.id_usuario = ? AND s.eliminado = 0 AND r.eliminado = 0
        AND r.id_ejercicio = ? AND s.fecha < ?
        AND EXISTS (SELECT 1 FROM serie x WHERE x.id_registro = r.id_registro AND x.eliminado = 0)
      ORDER BY s.fecha DESC, r.actualizado_en DESC
      LIMIT 1
    ''', [_idUsuario, idEjercicio, hoy]);

    var seriesUltimaVez = <({double pesoKg, int repeticiones})>[];
    String? fechaUltimaVez;
    if (ultimas.isNotEmpty) {
      fechaUltimaVez = ultimas.first['fecha'] as String;
      final filasUltima = await _bd.rawQuery('''
        SELECT peso_kg, repeticiones
        FROM serie
        WHERE id_registro = ? AND eliminado = 0
        ORDER BY numero_serie
      ''', [ultimas.first['id_registro']]);
      seriesUltimaVez = [
        for (final f in filasUltima)
          (pesoKg: (f['peso_kg'] as num).toDouble(), repeticiones: f['repeticiones'] as int),
      ];
    }

    return EjercicioBitacora(
      idProgramado: idProgramado,
      idEjercicio: idEjercicio,
      nombre: ep['nombre'] as String,
      orden: ep['orden'] as int,
      descansoSeg: ep['descanso_seg'] as int,
      trabajoSeg: ep['trabajo_seg'] as int?,
      completado: registroHoy?.completado ?? false,
      fechaUltimaVez: fechaUltimaVez,
      series: armarSeries(
        seriesObjetivo: ep['series_objetivo'] as int,
        repsObjetivo: ep['reps_objetivo'] as int,
        pesoObjetivoKg: (ep['peso_objetivo_kg'] as num?)?.toDouble(),
        hoy: seriesHoy,
        ultimaVez: seriesUltimaVez,
      ),
    );
  }

  /// Guarda una serie con 1 toque (ENT-87). Si ya estaba guardada, la actualiza.
  ///
  /// Crea la sesión de hoy y el registro del ejercicio si todavía no existen.
  Future<void> guardarSerie({
    required String idProgramado,
    required int numero,
    required double pesoKg,
    required int repeticiones,
  }) async {
    if (numero < 1) throw ArgumentError('El número de serie empieza en 1');
    if (pesoKg < 0) throw ArgumentError('El peso no puede ser negativo');
    if (repeticiones < 0) throw ArgumentError('Las repeticiones no pueden ser negativas');

    await _bd.transaction((txn) async {
      final escritura = EscrituraLocal(txn);
      final idRegistro = await _asegurarRegistro(txn, escritura, idProgramado);
      final valores = {
        'peso_kg': pesoKg,
        'repeticiones': repeticiones,
        'completada_en': Fechas.ahoraIso(),
      };
      final cambiadas = await escritura.actualizar(
        'serie',
        valores,
        where: 'id_registro = ? AND numero_serie = ? AND eliminado = 0',
        whereArgs: [idRegistro, numero],
      );
      if (cambiadas == 0) {
        await escritura.insertar('serie', {
          'id_registro': idRegistro,
          'numero_serie': numero,
          ...valores,
        });
      }
    });
  }

  /// Quita el ✓ de una serie guardada hoy (se marca eliminada, nunca DELETE).
  Future<void> quitarSerie({required String idProgramado, required int numero}) async {
    final registro = await _registroDeHoy(_bd, idProgramado, Fechas.hoy());
    if (registro == null) return;
    await EscrituraLocal(_bd).marcarEliminado(
      'serie',
      where: 'id_registro = ? AND numero_serie = ? AND eliminado = 0',
      whereArgs: [registro.id, numero],
    );
  }

  /// Registro de hoy para este ejercicio de la rutina, si ya existe.
  Future<({String id, bool completado})?> _registroDeHoy(
    DatabaseExecutor bd,
    String idProgramado,
    String hoy,
  ) async {
    final filas = await bd.rawQuery('''
      SELECT r.id_registro, r.completado
      FROM registro_ejercicio r
      JOIN sesion_entrenamiento s ON s.id_sesion = r.id_sesion
      WHERE s.id_usuario = ? AND s.fecha = ? AND s.eliminado = 0
        AND r.id_programado = ? AND r.eliminado = 0
      ORDER BY r.creado_en
      LIMIT 1
    ''', [_idUsuario, hoy, idProgramado]);
    if (filas.isEmpty) return null;
    return (id: filas.first['id_registro'] as String, completado: filas.first['completado'] == 1);
  }

  /// Devuelve el id del registro de hoy; crea la sesión y el registro si faltan.
  Future<String> _asegurarRegistro(
    Transaction txn,
    EscrituraLocal escritura,
    String idProgramado,
  ) async {
    final hoy = Fechas.hoy();
    final existente = await _registroDeHoy(txn, idProgramado, hoy);
    if (existente != null) return existente.id;

    final programados = await txn.rawQuery('''
      SELECT id_dia, id_ejercicio, orden
      FROM ejercicio_programado
      WHERE id_programado = ? AND eliminado = 0
    ''', [idProgramado]);
    if (programados.isEmpty) throw StateError('El ejercicio ya no está en la rutina');
    final ep = programados.first;

    // Una sola sesión por usuario y fecha: se reutiliza la que ya exista.
    final sesiones = await txn.rawQuery('''
      SELECT id_sesion, estado
      FROM sesion_entrenamiento
      WHERE id_usuario = ? AND fecha = ? AND eliminado = 0
      ORDER BY creado_en
      LIMIT 1
    ''', [_idUsuario, hoy]);

    String idSesion;
    if (sesiones.isEmpty) {
      idSesion = (await escritura.insertar('sesion_entrenamiento', {
        'id_usuario': _idUsuario,
        'id_dia': ep['id_dia'],
        'fecha': hoy,
        'estado': 'parcial',
        'hora_inicio': Fechas.hora(Fechas.ahoraCdmx()),
      }))!;
    } else {
      idSesion = sesiones.first['id_sesion'] as String;
      // Si el día se había marcado como descanso y ahora sí entrena, pasa a parcial.
      if (sesiones.first['estado'] == 'descanso') {
        await escritura.actualizar(
          'sesion_entrenamiento',
          {'estado': 'parcial', 'id_dia': ep['id_dia']},
          where: 'id_sesion = ?',
          whereArgs: [idSesion],
        );
      }
    }

    return (await escritura.insertar('registro_ejercicio', {
      'id_sesion': idSesion,
      'id_programado': idProgramado,
      'id_ejercicio': ep['id_ejercicio'],
      'es_sustitucion': 0,
      'orden': ep['orden'],
      'completado': 0,
    }))!;
  }
}

/// Repositorio de la bitácora para el usuario actual (null si no hay usuario).
final bitacoraRepositorioProvider = FutureProvider<BitacoraRepositorio?>((ref) async {
  final idUsuario = ref.watch(usuarioActualIdProvider);
  if (idUsuario == null) return null;
  final bd = await ref.watch(baseDatosProvider.future);
  return BitacoraRepositorio(bd, idUsuario);
});

/// Un ejercicio de hoy con sus series. Después de guardar, invalídalo:
/// `ref.invalidate(ejercicioBitacoraProvider(idProgramado))`.
final ejercicioBitacoraProvider =
    FutureProvider.family<EjercicioBitacora?, String>((ref, idProgramado) async {
  final repositorio = await ref.watch(bitacoraRepositorioProvider.future);
  return repositorio?.ejercicio(idProgramado);
});
