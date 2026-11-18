import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../../core/db/base_datos.dart';
import '../../../core/db/escritura_local.dart';
import '../../../core/db/usuario_actual.dart';
import '../../perfil/catalogo/catalogo_repositorio.dart';
import '../rutinas_repositorio.dart';

/// Una alternativa de un ejercicio programado, con el nombre visible (alias).
class Alternativa {
  const Alternativa({
    required this.idAlternativa,
    required this.idProgramado,
    required this.idEjercicio,
    required this.nombre,
    required this.nombreOficial,
    required this.grupoMuscular,
    required this.prioridad,
    this.nombreEquipo,
  });

  final String idAlternativa;
  final String idProgramado;
  final int idEjercicio;

  /// Alias del usuario o nombre oficial. A la IA se manda [nombreOficial].
  final String nombre;
  final String nombreOficial;
  final String grupoMuscular;

  /// null = peso corporal.
  final String? nombreEquipo;

  /// 1 = la primera que se ofrece.
  final int prioridad;
}

/// El ejercicio programado al que se le ponen alternativas.
class EjercicioConAlternativas {
  const EjercicioConAlternativas({
    required this.idProgramado,
    required this.idEjercicio,
    required this.nombre,
    required this.nombreOficial,
    required this.grupoMuscular,
    required this.cicloActivo,
  });

  final String idProgramado;
  final int idEjercicio;
  final String nombre;
  final String nombreOficial;
  final String grupoMuscular;

  /// false = el ciclo está archivado y se ve en solo lectura.
  final bool cicloActivo;
}

/// Alternativas preconfiguradas por ejercicio (ENT-48): hasta 3, con
/// prioridad de 1 a 3 y sin repetir, para cambiar rápido si el equipo está
/// ocupado (base de RF-04).
class AlternativasRepositorio {
  AlternativasRepositorio(this._bd, this._idUsuario);

  final Database _bd;
  final String _idUsuario;

  /// Máximo de alternativas por ejercicio (criterio 1).
  static const int maximo = 3;

  /// Revisa si se puede agregar [idEjercicio] como alternativa. Devuelve el
  /// error o null si está bien. Es público para probarlo sin base.
  static String? validarNueva({
    required int idEjercicio,
    required int idEjercicioPrincipal,
    required List<int> yaElegidos,
  }) {
    if (idEjercicio == idEjercicioPrincipal) return 'Es el mismo ejercicio de la rutina.';
    if (yaElegidos.contains(idEjercicio)) return 'Ya es una de sus alternativas.';
    if (yaElegidos.length >= maximo) return 'Ya tiene $maximo alternativas. Quita una para agregar otra.';
    return null;
  }

  /// Datos del ejercicio programado y si su ciclo se puede editar.
  Future<EjercicioConAlternativas?> ejercicio(String idProgramado) async {
    final filas = await _bd.rawQuery('''
      SELECT ep.id_programado, ep.id_ejercicio, e.nombre_oficial, e.grupo_muscular,
             ${CatalogoRepositorio.nombreVisible} AS nombre, c.estado
      FROM ejercicio_programado ep
      JOIN dia_rutina d ON d.id_dia = ep.id_dia AND d.eliminado = 0
      JOIN ciclo_rutina c ON c.id_ciclo = d.id_ciclo AND c.eliminado = 0
      JOIN ejercicio e ON e.id_ejercicio = ep.id_ejercicio
      ${CatalogoRepositorio.joinAlias}
      WHERE ep.id_programado = ? AND ep.eliminado = 0 AND c.id_usuario = ?
    ''', [_idUsuario, idProgramado, _idUsuario]);
    if (filas.isEmpty) return null;
    final f = filas.first;
    return EjercicioConAlternativas(
      idProgramado: f['id_programado'] as String,
      idEjercicio: f['id_ejercicio'] as int,
      nombre: f['nombre'] as String,
      nombreOficial: f['nombre_oficial'] as String,
      grupoMuscular: f['grupo_muscular'] as String,
      cicloActivo: f['estado'] == 'activo',
    );
  }

  /// Consulta de las alternativas vigentes de un ejercicio, por prioridad.
  /// Argumentos: id del usuario (para el alias) e id del ejercicio programado.
  static const String consultaAlternativas = '''
    SELECT a.id_alternativa, a.id_programado, a.id_ejercicio, a.prioridad,
           e.nombre_oficial, e.grupo_muscular, eq.nombre AS nombre_equipo,
           ${CatalogoRepositorio.nombreVisible} AS nombre
    FROM alternativa_ejercicio a
    JOIN ejercicio e ON e.id_ejercicio = a.id_ejercicio
    LEFT JOIN equipo eq ON eq.id_equipo = e.id_equipo
    ${CatalogoRepositorio.joinAlias}
    WHERE a.id_programado = ? AND a.eliminado = 0
    ORDER BY a.prioridad, a.creado_en
  ''';

  Future<List<Alternativa>> alternativas(String idProgramado) async {
    final filas = await _bd.rawQuery(consultaAlternativas, [_idUsuario, idProgramado]);
    return filas
        .map((f) => Alternativa(
              idAlternativa: f['id_alternativa'] as String,
              idProgramado: f['id_programado'] as String,
              idEjercicio: f['id_ejercicio'] as int,
              nombre: f['nombre'] as String,
              nombreOficial: f['nombre_oficial'] as String,
              grupoMuscular: f['grupo_muscular'] as String,
              nombreEquipo: f['nombre_equipo'] as String?,
              prioridad: f['prioridad'] as int,
            ))
        .toList();
  }

  /// Agrega una alternativa al final (prioridad siguiente). Lanza
  /// [ArgumentError] si es repetida, es el mismo ejercicio o ya hay 3.
  Future<void> agregar(String idProgramado, int idEjercicio) async {
    await _bd.transaction((txn) async {
      final principal = await _exigirEditable(txn, idProgramado);
      final actuales = await _actuales(txn, idProgramado);
      final error = validarNueva(
        idEjercicio: idEjercicio,
        idEjercicioPrincipal: principal,
        yaElegidos: actuales.map((a) => a.$2).toList(),
      );
      if (error != null) throw ArgumentError(error);
      await EscrituraLocal(txn).insertar('alternativa_ejercicio', {
        'id_programado': idProgramado,
        'id_ejercicio': idEjercicio,
        'prioridad': actuales.length + 1,
      });
    });
  }

  /// Quita una alternativa (eliminado = 1, nunca DELETE) y recorre las demás.
  Future<void> quitar(String idProgramado, String idAlternativa) async {
    await _bd.transaction((txn) async {
      await _exigirEditable(txn, idProgramado);
      await EscrituraLocal(txn).marcarEliminado(
        'alternativa_ejercicio',
        where: 'id_alternativa = ? AND id_programado = ? AND eliminado = 0',
        whereArgs: [idAlternativa, idProgramado],
      );
      await _renumerar(txn, idProgramado, null);
    });
  }

  /// Mueve una alternativa a [posicion] (0 = prioridad 1).
  Future<void> mover(String idProgramado, String idAlternativa, int posicion) async {
    await _bd.transaction((txn) async {
      await _exigirEditable(txn, idProgramado);
      await _renumerar(txn, idProgramado, (idAlternativa, posicion));
    });
  }

  /// (id_alternativa, id_ejercicio, prioridad) vigentes, en orden.
  Future<List<(String, int, int)>> _actuales(DatabaseExecutor bd, String idProgramado) async {
    final filas = await bd.rawQuery(
      'SELECT id_alternativa, id_ejercicio, prioridad FROM alternativa_ejercicio '
      'WHERE id_programado = ? AND eliminado = 0 ORDER BY prioridad, creado_en',
      [idProgramado],
    );
    return [
      for (final f in filas) (f['id_alternativa'] as String, f['id_ejercicio'] as int, f['prioridad'] as int),
    ];
  }

  /// Deja las prioridades como 1, 2, 3 (después de mover o quitar).
  Future<void> _renumerar(Transaction txn, String idProgramado, (String, int)? mover) async {
    final actuales = await _actuales(txn, idProgramado);
    var ids = actuales.map((a) => a.$1).toList();
    if (mover != null) ids = RutinasRepositorio.reordenar(ids, mover.$1, mover.$2);
    final escritura = EscrituraLocal(txn);
    for (var i = 0; i < ids.length; i++) {
      final anterior = actuales.firstWhere((a) => a.$1 == ids[i]).$3;
      if (anterior == i + 1) continue; // Solo marca para sincronizar lo que cambió.
      await escritura.actualizar(
        'alternativa_ejercicio',
        {'prioridad': i + 1},
        where: 'id_alternativa = ?',
        whereArgs: [ids[i]],
      );
    }
  }

  /// Revisa que el ejercicio sea del usuario y su ciclo esté activo.
  /// Devuelve el id_ejercicio principal.
  Future<int> _exigirEditable(DatabaseExecutor bd, String idProgramado) async {
    final filas = await bd.rawQuery('''
      SELECT ep.id_ejercicio, c.estado
      FROM ejercicio_programado ep
      JOIN dia_rutina d ON d.id_dia = ep.id_dia AND d.eliminado = 0
      JOIN ciclo_rutina c ON c.id_ciclo = d.id_ciclo AND c.eliminado = 0
      WHERE ep.id_programado = ? AND ep.eliminado = 0 AND c.id_usuario = ?
    ''', [idProgramado, _idUsuario]);
    if (filas.isEmpty) throw StateError('No existe el ejercicio programado.');
    if (filas.first['estado'] != 'activo') throw const CicloSoloLectura();
    return filas.first['id_ejercicio'] as int;
  }
}

/// Repositorio de alternativas para el usuario actual (null si no hay usuario).
final alternativasRepositorioProvider = FutureProvider<AlternativasRepositorio?>((ref) async {
  final idUsuario = ref.watch(usuarioActualIdProvider);
  if (idUsuario == null) return null;
  final bd = await ref.watch(baseDatosProvider.future);
  return AlternativasRepositorio(bd, idUsuario);
});
