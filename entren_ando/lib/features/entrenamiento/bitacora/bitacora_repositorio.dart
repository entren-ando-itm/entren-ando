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
/// * ENT-50 / ENT-90: "Terminar ejercicio", el estado de la sesión (completa o
///   parcial), hora_inicio, hora_fin y el comentario del día.
/// * ENT-59: "Cambiar solo hoy" por una alternativa. La precarga usa el
///   historial de la alternativa y la plantilla no cambia.
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
    this.ultimaVez = const [],
    this.grupoMuscular = '',
    this.tipoMovimiento = '',
    this.equipo,
    this.idEjercicioOriginal,
    this.nombreOriginal,
    this.esSustitucion = false,
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

  /// Series de la última vez (peso y repeticiones), para "La vez pasada: 4 × 12 con 120 kg".
  final List<({double pesoKg, int repeticiones})> ultimaVez;

  /// Del catálogo: "Pierna", "compuesto" y el equipo (null = peso corporal).
  final String grupoMuscular;
  final String tipoMovimiento;
  final String? equipo;

  /// ENT-59: el ejercicio de la rutina cuando hoy se cambió por una alternativa.
  final int? idEjercicioOriginal;
  final String? nombreOriginal;

  /// true si hoy se está haciendo una alternativa en lugar del original.
  final bool esSustitucion;

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

/// Una alternativa para "Cambiar solo hoy" (ENT-104).
class AlternativaEjercicio {
  const AlternativaEjercicio({required this.idEjercicio, required this.nombre, this.equipo});

  final int idEjercicio;

  /// Alias del usuario o nombre oficial.
  final String nombre;

  /// Nombre del equipo; null = peso corporal.
  final String? equipo;
}

/// La sesión de hoy: estado, comentario y horas.
class SesionDeHoy {
  const SesionDeHoy({required this.estado, this.comentario, this.horaInicio, this.horaFin});

  /// 'completa', 'parcial' o 'descanso'.
  final String estado;
  final String? comentario;
  final String? horaInicio;
  final String? horaFin;
}

/// Porcentaje de las series del día que hace falta para que el día cuente como
/// completo (verde). Decisión del PO del 26 de noviembre (ENT-121).
const double umbralDiaCompleto = 0.8;

/// Regla del estado de la sesión (ENT-90, actualizada en ENT-121): 'completa'
/// si se hizo al menos el 80% de las series objetivo del día; si no, 'parcial'.
/// Las series de más en un ejercicio no compensan las que faltan en otro.
/// Función pura para poder probarla.
String estadoSesion(List<({bool completado, int seriesHechas, int seriesObjetivo})> ejercicios) {
  final objetivo = ejercicios.fold<int>(0, (suma, e) => suma + e.seriesObjetivo);
  if (objetivo <= 0) return 'parcial';
  final hechas = ejercicios.fold<int>(
    0,
    (suma, e) => suma + (e.seriesHechas < e.seriesObjetivo ? e.seriesHechas : e.seriesObjetivo),
  );
  return hechas >= objetivo * umbralDiaCompleto ? 'completa' : 'parcial';
}

/// Se lanza al marcar o quitar una serie fuera de orden (ENT-121): se marcan
/// de la primera a la última y solo se puede quitar la última marcada.
class SerieFueraDeOrden implements Exception {
  const SerieFueraDeOrden(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

class BitacoraRepositorio {
  BitacoraRepositorio(this._bd, this._idUsuario);

  final Database _bd;
  final String _idUsuario;

  /// El ejercicio de hoy con sus series guardadas o precargadas (ENT-88).
  Future<EjercicioBitacora?> ejercicio(String idProgramado) async {
    // La plantilla (series, repeticiones y peso objetivo) nunca cambia.
    final filas = await _bd.rawQuery('''
      SELECT ep.id_programado, ep.id_ejercicio, ep.orden, ep.series_objetivo, ep.reps_objetivo,
             ep.peso_objetivo_kg, ep.descanso_seg, ep.trabajo_seg
      FROM ejercicio_programado ep
      WHERE ep.id_programado = ? AND ep.eliminado = 0
    ''', [idProgramado]);
    if (filas.isEmpty) return null;
    final ep = filas.first;
    final idOriginal = ep['id_ejercicio'] as int;
    final hoy = Fechas.hoy();

    // Lo que ya se guardó hoy. Si hoy se cambió por una alternativa (ENT-59),
    // el registro trae el id_ejercicio de la alternativa.
    final registroHoy = await _registroDeHoy(_bd, idProgramado, hoy);
    final idEjercicio = registroHoy?.idEjercicio ?? idOriginal;
    final catalogo = await _datosEjercicio(_bd, idEjercicio);
    final nombreOriginal = idEjercicio == idOriginal
        ? catalogo['nombre'] as String
        : (await _datosEjercicio(_bd, idOriginal))['nombre'] as String;
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
      nombre: catalogo['nombre'] as String,
      idEjercicioOriginal: idOriginal,
      nombreOriginal: nombreOriginal,
      esSustitucion: idEjercicio != idOriginal,
      orden: ep['orden'] as int,
      descansoSeg: ep['descanso_seg'] as int,
      trabajoSeg: ep['trabajo_seg'] as int?,
      completado: registroHoy?.completado ?? false,
      fechaUltimaVez: fechaUltimaVez,
      ultimaVez: seriesUltimaVez,
      grupoMuscular: catalogo['grupo_muscular'] as String,
      tipoMovimiento: catalogo['tipo_movimiento'] as String,
      equipo: catalogo['equipo'] as String?,
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
      // ENT-121: en orden. Se puede actualizar una ya guardada o marcar la que sigue.
      final guardadas = await _numerosGuardados(txn, idRegistro);
      if (!guardadas.contains(numero) && numero != _ultima(guardadas) + 1) {
        throw const SerieFueraDeOrden('Marca las series en orden, de la primera a la última.');
      }
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
      await _recalcularSesion(txn, escritura);
    });
  }

  /// Quita el ✓ de una serie guardada hoy (se marca eliminada, nunca DELETE).
  Future<void> quitarSerie({required String idProgramado, required int numero}) async {
    await _bd.transaction((txn) async {
      final registro = await _registroDeHoy(txn, idProgramado, Fechas.hoy());
      if (registro == null) return;
      if (registro.completado) {
        throw const SerieFueraDeOrden('Vuelve a abrir el ejercicio para quitar series.');
      }
      // ENT-121: solo la última marcada, para no dejar huecos.
      final guardadas = await _numerosGuardados(txn, registro.id);
      if (guardadas.isEmpty) return;
      if (numero != _ultima(guardadas)) {
        throw const SerieFueraDeOrden('Solo puedes quitar la última serie que marcaste.');
      }
      final escritura = EscrituraLocal(txn);
      await escritura.marcarEliminado(
        'serie',
        where: 'id_registro = ? AND numero_serie = ? AND eliminado = 0',
        whereArgs: [registro.id, numero],
      );
      await _recalcularSesion(txn, escritura);
    });
  }

  /// "Terminar ejercicio" con un toque (ENT-121): guarda las series que faltan
  /// con el peso y las repeticiones que muestra la pantalla (precarga u
  /// objetivo; [ajustes] son los cambios con + y − aún sin guardar) y lo marca
  /// completado. Todo en una transacción. Lo usan la pantalla del ejercicio y
  /// el círculo de la lista de Hoy.
  Future<void> terminarCompleto(String idProgramado, {Map<int, SerieBitacora> ajustes = const {}}) async {
    final datos = await ejercicio(idProgramado);
    if (datos == null) return;
    await _bd.transaction((txn) async {
      final escritura = EscrituraLocal(txn);
      final idRegistro = await _asegurarRegistro(txn, escritura, idProgramado);
      final guardadas = await _numerosGuardados(txn, idRegistro);
      for (final serie in datos.series) {
        if (guardadas.contains(serie.numero)) continue;
        final valores = ajustes[serie.numero] ?? serie;
        await escritura.insertar('serie', {
          'id_registro': idRegistro,
          'numero_serie': serie.numero,
          'peso_kg': valores.pesoKg,
          'repeticiones': valores.repeticiones,
          'completada_en': Fechas.ahoraIso(),
        });
      }
      await escritura.actualizar(
        'registro_ejercicio',
        {'completado': 1},
        where: 'id_registro = ?',
        whereArgs: [idRegistro],
      );
      await _recalcularSesion(txn, escritura);
    });
  }

  /// "Terminar la sesión de hoy así como está" (mantener presionado "Seguir
  /// entrenando", ENT-121): marca como terminados los ejercicios que faltan,
  /// solo con las series que ya tenían. El día queda completo o parcial según
  /// la regla del 80% ([estadoSesion]). Todo en una transacción.
  Future<void> terminarDia(List<String> idsProgramados) async {
    if (idsProgramados.isEmpty) return;
    await _bd.transaction((txn) async {
      final escritura = EscrituraLocal(txn);
      for (final idProgramado in idsProgramados) {
        final idRegistro = await _asegurarRegistro(txn, escritura, idProgramado);
        await escritura.actualizar(
          'registro_ejercicio',
          {'completado': 1},
          where: 'id_registro = ? AND completado = 0',
          whereArgs: [idRegistro],
        );
      }
      await _recalcularSesion(txn, escritura);
    });
  }

  Future<List<int>> _numerosGuardados(DatabaseExecutor bd, String idRegistro) async {
    final filas = await bd.rawQuery(
      'SELECT numero_serie FROM serie WHERE id_registro = ? AND eliminado = 0 ORDER BY numero_serie',
      [idRegistro],
    );
    return [for (final f in filas) f['numero_serie'] as int];
  }

  static int _ultima(List<int> guardadas) => guardadas.isEmpty ? 0 : guardadas.last;

  /// "Terminar ejercicio" parcial (ENT-50; mantener presionado en ENT-121):
  /// `registro_ejercicio.completado = 1` solo con las series que se hicieron.
  /// Con [completado] en false se vuelve a abrir.
  Future<void> completarEjercicio(String idProgramado, {bool completado = true}) async {
    await _bd.transaction((txn) async {
      final escritura = EscrituraLocal(txn);
      final idRegistro = await _asegurarRegistro(txn, escritura, idProgramado);
      await escritura.actualizar(
        'registro_ejercicio',
        {'completado': completado ? 1 : 0},
        where: 'id_registro = ?',
        whereArgs: [idRegistro],
      );
      await _recalcularSesion(txn, escritura);
    });
  }

  /// La sesión de hoy (null si todavía no se entrena).
  Future<SesionDeHoy?> sesionDeHoy() async {
    final filas = await _bd.rawQuery('''
      SELECT id_sesion, estado, comentario, hora_inicio, hora_fin
      FROM sesion_entrenamiento
      WHERE id_usuario = ? AND fecha = ? AND eliminado = 0
      ORDER BY creado_en
      LIMIT 1
    ''', [_idUsuario, Fechas.hoy()]);
    if (filas.isEmpty) return null;
    final f = filas.first;
    return SesionDeHoy(
      estado: f['estado'] as String,
      comentario: f['comentario'] as String?,
      horaInicio: f['hora_inicio'] as String?,
      horaFin: f['hora_fin'] as String?,
    );
  }

  /// Comentario libre de la sesión de hoy ("me dolió el hombro"). Lo usa la IA
  /// en el feedback (ENT-68). Vacío = sin comentario.
  Future<void> guardarComentario(String texto) async {
    final limpio = texto.trim();
    await EscrituraLocal(_bd).actualizar(
      'sesion_entrenamiento',
      {'comentario': limpio.isEmpty ? null : limpio},
      where: 'id_usuario = ? AND fecha = ? AND eliminado = 0',
      whereArgs: [_idUsuario, Fechas.hoy()],
    );
  }

  /// Regla del estado de la sesión de hoy (ENT-90), cada vez que cambia una
  /// serie o un ejercicio:
  /// * **completa** (verde): al menos el 80% de las series objetivo del día
  ///   están guardadas ([estadoSesion], ENT-121).
  /// * **parcial** (naranja): cualquier otro caso con la sesión ya empezada.
  /// También guarda hora_fin (la hora del último cambio).
  Future<void> _recalcularSesion(Transaction txn, EscrituraLocal escritura) async {
    final sesiones = await txn.rawQuery('''
      SELECT id_sesion, id_dia, hora_inicio
      FROM sesion_entrenamiento
      WHERE id_usuario = ? AND fecha = ? AND eliminado = 0
      ORDER BY creado_en
      LIMIT 1
    ''', [_idUsuario, Fechas.hoy()]);
    if (sesiones.isEmpty) return;
    final sesion = sesiones.first;

    // Por cada ejercicio de la plantilla del día: ¿completado y con sus series?
    final avance = await txn.rawQuery('''
      SELECT ep.series_objetivo,
             COALESCE(MAX(r.completado), 0) AS completado,
             (SELECT COUNT(*) FROM serie x
              JOIN registro_ejercicio rx ON rx.id_registro = x.id_registro
              WHERE rx.id_sesion = ? AND rx.id_programado = ep.id_programado
                AND rx.eliminado = 0 AND x.eliminado = 0) AS series_hechas
      FROM ejercicio_programado ep
      LEFT JOIN registro_ejercicio r
        ON r.id_programado = ep.id_programado AND r.id_sesion = ? AND r.eliminado = 0
      WHERE ep.id_dia = ? AND ep.eliminado = 0
      GROUP BY ep.id_programado
    ''', [sesion['id_sesion'], sesion['id_sesion'], sesion['id_dia']]);

    final completa = estadoSesion([
      for (final f in avance)
        (
          completado: f['completado'] == 1,
          seriesHechas: f['series_hechas'] as int,
          seriesObjetivo: f['series_objetivo'] as int,
        ),
    ]);

    final ahora = Fechas.hora(Fechas.ahoraCdmx());
    await escritura.actualizar(
      'sesion_entrenamiento',
      {
        'estado': completa,
        'hora_inicio': sesion['hora_inicio'] ?? ahora,
        'hora_fin': ahora,
      },
      where: 'id_sesion = ?',
      whereArgs: [sesion['id_sesion']],
    );
  }


  /// Alternativas de un ejercicio de la rutina, ordenadas por prioridad (ENT-104).
  /// Lista vacía = no hay alternativas y el botón "Cambiar solo hoy" no aparece.
  Future<List<AlternativaEjercicio>> alternativas(String idProgramado) async {
    final filas = await _bd.rawQuery('''
      SELECT a.id_ejercicio, a.prioridad,
             COALESCE(ue.nombre_alias, e.nombre_oficial) AS nombre,
             eq.nombre AS equipo
      FROM alternativa_ejercicio a
      JOIN ejercicio e ON e.id_ejercicio = a.id_ejercicio
      LEFT JOIN equipo eq ON eq.id_equipo = e.id_equipo
      LEFT JOIN usuario_ejercicio ue
        ON ue.id_ejercicio = a.id_ejercicio AND ue.id_usuario = ? AND ue.eliminado = 0
      WHERE a.id_programado = ? AND a.eliminado = 0
      ORDER BY a.prioridad, nombre
    ''', [_idUsuario, idProgramado]);
    return [
      for (final f in filas)
        AlternativaEjercicio(
          idEjercicio: f['id_ejercicio'] as int,
          nombre: f['nombre'] as String,
          equipo: f['equipo'] as String?,
        ),
    ];
  }

  /// Cambia el ejercicio **solo por hoy** (ENT-105). Guarda en el registro de hoy
  /// el id_ejercicio de la alternativa con es_sustitucion = 1 y el id_programado
  /// del original. Con el id del original, vuelve al ejercicio de la rutina.
  ///
  /// Nunca modifica ejercicio_programado: mañana y la plantilla siguen igual.
  /// Si ya hay series guardadas hoy, no se cambia (son de otro ejercicio).
  Future<void> sustituir({required String idProgramado, required int idEjercicio}) async {
    await _bd.transaction((txn) async {
      final programados = await txn.rawQuery('''
        SELECT id_ejercicio FROM ejercicio_programado
        WHERE id_programado = ? AND eliminado = 0
      ''', [idProgramado]);
      if (programados.isEmpty) throw StateError('El ejercicio ya no está en la rutina');
      final idOriginal = programados.first['id_ejercicio'] as int;

      if (idEjercicio != idOriginal) {
        final valida = await txn.rawQuery('''
          SELECT 1 FROM alternativa_ejercicio
          WHERE id_programado = ? AND id_ejercicio = ? AND eliminado = 0
        ''', [idProgramado, idEjercicio]);
        if (valida.isEmpty) throw ArgumentError('No es una alternativa de este ejercicio');
      }

      final escritura = EscrituraLocal(txn);
      final idRegistro = await _asegurarRegistro(txn, escritura, idProgramado);
      final series = await txn.rawQuery(
        'SELECT COUNT(*) AS n FROM serie WHERE id_registro = ? AND eliminado = 0',
        [idRegistro],
      );
      if ((series.first['n'] as int) > 0) {
        throw StateError('Quita las series guardadas antes de cambiar el ejercicio');
      }
      await escritura.actualizar(
        'registro_ejercicio',
        {
          'id_ejercicio': idEjercicio,
          'es_sustitucion': idEjercicio == idOriginal ? 0 : 1,
        },
        where: 'id_registro = ?',
        whereArgs: [idRegistro],
      );
    });
  }

  /// Nombre (alias), grupo, tipo y equipo de un ejercicio del catálogo.
  Future<Map<String, Object?>> _datosEjercicio(DatabaseExecutor bd, int idEjercicio) async {
    final filas = await bd.rawQuery('''
      SELECT COALESCE(ue.nombre_alias, e.nombre_oficial) AS nombre,
             e.grupo_muscular, e.tipo_movimiento, eq.nombre AS equipo
      FROM ejercicio e
      LEFT JOIN equipo eq ON eq.id_equipo = e.id_equipo
      LEFT JOIN usuario_ejercicio ue
        ON ue.id_ejercicio = e.id_ejercicio AND ue.id_usuario = ? AND ue.eliminado = 0
      WHERE e.id_ejercicio = ?
    ''', [_idUsuario, idEjercicio]);
    if (filas.isEmpty) throw StateError('El ejercicio $idEjercicio no está en el catálogo');
    return filas.first;
  }

  /// Registro de hoy para este ejercicio de la rutina, si ya existe.
  Future<({String id, bool completado, int idEjercicio, bool esSustitucion})?> _registroDeHoy(
    DatabaseExecutor bd,
    String idProgramado,
    String hoy,
  ) async {
    final filas = await bd.rawQuery('''
      SELECT r.id_registro, r.completado, r.id_ejercicio, r.es_sustitucion
      FROM registro_ejercicio r
      JOIN sesion_entrenamiento s ON s.id_sesion = r.id_sesion
      WHERE s.id_usuario = ? AND s.fecha = ? AND s.eliminado = 0
        AND r.id_programado = ? AND r.eliminado = 0
      ORDER BY r.creado_en
      LIMIT 1
    ''', [_idUsuario, hoy, idProgramado]);
    if (filas.isEmpty) return null;
    final f = filas.first;
    return (
      id: f['id_registro'] as String,
      completado: f['completado'] == 1,
      idEjercicio: f['id_ejercicio'] as int,
      esSustitucion: f['es_sustitucion'] == 1,
    );
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
/// La sesión de hoy (estado y comentario). Invalídalo después de guardar.
final sesionDeHoyProvider = FutureProvider<SesionDeHoy?>((ref) async {
  final repositorio = await ref.watch(bitacoraRepositorioProvider.future);
  return repositorio?.sesionDeHoy();
});

/// Alternativas de un ejercicio de la rutina (vacía = sin botón "Cambiar solo hoy").
final alternativasProvider =
    FutureProvider.family<List<AlternativaEjercicio>, String>((ref, idProgramado) async {
  final repositorio = await ref.watch(bitacoraRepositorioProvider.future);
  return repositorio?.alternativas(idProgramado) ?? const [];
});

final ejercicioBitacoraProvider =
    FutureProvider.family<EjercicioBitacora?, String>((ref, idProgramado) async {
  final repositorio = await ref.watch(bitacoraRepositorioProvider.future);
  return repositorio?.ejercicio(idProgramado);
});
