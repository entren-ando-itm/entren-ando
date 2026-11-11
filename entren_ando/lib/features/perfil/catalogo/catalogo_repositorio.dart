import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../../core/db/base_datos.dart';
import '../../../core/db/escritura_local.dart';
import '../../../core/db/usuario_actual.dart';

/// Un ejercicio del catálogo con el alias del usuario (si tiene).
class EjercicioCatalogo {
  const EjercicioCatalogo({
    required this.idEjercicio,
    required this.nombreOficial,
    required this.grupoMuscular,
    required this.tipoMovimiento,
    this.idEquipo,
    this.nombreEquipo,
    this.alias,
  });

  final int idEjercicio;
  final String nombreOficial;
  final String grupoMuscular;
  final String tipoMovimiento;

  /// null = peso corporal.
  final int? idEquipo;
  final String? nombreEquipo;
  final String? alias;

  /// Lo que se muestra en la app: el alias si existe, si no el nombre oficial.
  String get nombreVisible => alias ?? nombreOficial;

  bool get tieneAlias => alias != null;
}

/// Un equipo del catálogo para el filtro.
class EquipoCatalogo {
  const EquipoCatalogo({required this.idEquipo, required this.nombre});

  final int idEquipo;
  final String nombre;
}

/// Filtro de equipo: todos, solo peso corporal o un equipo en particular.
class FiltroEquipo {
  const FiltroEquipo._(this.idEquipo, this.pesoCorporal);

  static const FiltroEquipo todos = FiltroEquipo._(null, false);
  static const FiltroEquipo soloPesoCorporal = FiltroEquipo._(null, true);
  const FiltroEquipo.equipo(int id) : this._(id, false);

  final int? idEquipo;
  final bool pesoCorporal;

  bool get esTodos => idEquipo == null && !pesoCorporal;

  @override
  bool operator ==(Object other) =>
      other is FiltroEquipo && other.idEquipo == idEquipo && other.pesoCorporal == pesoCorporal;

  @override
  int get hashCode => Object.hash(idEquipo, pesoCorporal);
}

/// Consulta del nombre visible de un ejercicio para el usuario.
///
/// Otros módulos pueden copiarla: hace LEFT JOIN de ejercicio (alias `e`) con
/// usuario_ejercicio (alias `ue`) y el primer `?` es el id del usuario.
///
///   SELECT e.id_ejercicio, ${CatalogoRepositorio.nombreVisible} AS nombre
///   FROM ejercicio e ${CatalogoRepositorio.joinAlias}
///   WHERE ...
///
/// Ojo (criterio 4 de ENT-17): a la IA se manda id_ejercicio y
/// nombre_oficial, nunca el alias.
class CatalogoRepositorio {
  CatalogoRepositorio(this._bd, this._idUsuario);

  final DatabaseExecutor _bd;
  final String _idUsuario;

  /// Nombre que ve el usuario: alias si existe, si no el nombre oficial.
  static const String nombreVisible = 'COALESCE(ue.nombre_alias, e.nombre_oficial)';

  /// Une el alias vigente del usuario. El primer argumento es el id del usuario.
  static const String joinAlias =
      'LEFT JOIN usuario_ejercicio ue ON ue.id_ejercicio = e.id_ejercicio '
      'AND ue.id_usuario = ? AND ue.eliminado = 0';

  /// Arma el SQL de [buscar]. Es público para poder probarlo sin base.
  static ({String sql, List<Object?> argumentos}) consultaBusqueda({
    required String idUsuario,
    String texto = '',
    String? grupo,
    FiltroEquipo equipo = FiltroEquipo.todos,
  }) {
    final condiciones = <String>[];
    final argumentos = <Object?>[idUsuario];

    final limpio = texto.trim().toLowerCase();
    if (limpio.isNotEmpty) {
      // Busca en el nombre oficial y en el alias, sin importar mayúsculas.
      condiciones.add("(lower(e.nombre_oficial) LIKE ? ESCAPE '\\' "
          "OR lower(ue.nombre_alias) LIKE ? ESCAPE '\\')");
      final patron = '%${_escaparLike(limpio)}%';
      argumentos
        ..add(patron)
        ..add(patron);
    }
    if (grupo != null) {
      condiciones.add('e.grupo_muscular = ?');
      argumentos.add(grupo);
    }
    if (equipo.pesoCorporal) {
      condiciones.add('e.id_equipo IS NULL');
    } else if (equipo.idEquipo != null) {
      condiciones.add('e.id_equipo = ?');
      argumentos.add(equipo.idEquipo);
    }

    final where = condiciones.isEmpty ? '' : 'WHERE ${condiciones.join(' AND ')}';
    final sql = '''
      SELECT e.id_ejercicio, e.nombre_oficial, e.grupo_muscular, e.tipo_movimiento,
             e.id_equipo, eq.nombre AS nombre_equipo, ue.nombre_alias
      FROM ejercicio e
      $joinAlias
      LEFT JOIN equipo eq ON eq.id_equipo = e.id_equipo
      $where
      ORDER BY $nombreVisible COLLATE NOCASE
    ''';
    return (sql: sql, argumentos: argumentos);
  }

  /// Ejercicios del catálogo que cumplen el texto y los filtros (sin internet).
  Future<List<EjercicioCatalogo>> buscar({
    String texto = '',
    String? grupo,
    FiltroEquipo equipo = FiltroEquipo.todos,
  }) async {
    final consulta = consultaBusqueda(
      idUsuario: _idUsuario,
      texto: texto,
      grupo: grupo,
      equipo: equipo,
    );
    final filas = await _bd.rawQuery(consulta.sql, consulta.argumentos);
    return filas
        .map((f) => EjercicioCatalogo(
              idEjercicio: f['id_ejercicio'] as int,
              nombreOficial: f['nombre_oficial'] as String,
              grupoMuscular: f['grupo_muscular'] as String,
              tipoMovimiento: f['tipo_movimiento'] as String,
              idEquipo: f['id_equipo'] as int?,
              nombreEquipo: f['nombre_equipo'] as String?,
              alias: f['nombre_alias'] as String?,
            ))
        .toList();
  }

  /// Grupos musculares que existen en el catálogo, para el filtro.
  Future<List<String>> gruposMusculares() async {
    final filas = await _bd.rawQuery(
      'SELECT DISTINCT grupo_muscular FROM ejercicio ORDER BY grupo_muscular COLLATE NOCASE',
    );
    return filas.map((f) => f['grupo_muscular'] as String).toList();
  }

  /// Equipos que usa al menos un ejercicio, para el filtro.
  Future<List<EquipoCatalogo>> equipos() async {
    final filas = await _bd.rawQuery('''
      SELECT DISTINCT eq.id_equipo, eq.nombre
      FROM equipo eq
      JOIN ejercicio e ON e.id_equipo = eq.id_equipo
      ORDER BY eq.nombre COLLATE NOCASE
    ''');
    return filas
        .map((f) => EquipoCatalogo(idEquipo: f['id_equipo'] as int, nombre: f['nombre'] as String))
        .toList();
  }

  /// Revisa un alias antes de guardarlo. Devuelve el error o null si está bien.
  static String? validarAlias(String? alias) {
    final limpio = alias?.trim() ?? '';
    if (limpio.isEmpty) return 'Escribe un nombre.';
    if (limpio.length > 60) return 'Usa 60 letras o menos.';
    return null;
  }

  /// Pone o cambia el alias de un ejercicio. Si existía uno borrado, lo reactiva.
  Future<void> guardarAlias(int idEjercicio, String alias) async {
    final error = validarAlias(alias);
    if (error != null) throw ArgumentError.value(alias, 'alias', error);
    await EscrituraLocal(_bd).insertar('usuario_ejercicio', {
      'id_usuario': _idUsuario,
      'id_ejercicio': idEjercicio,
      'nombre_alias': alias.trim(),
    });
  }

  /// Quita el alias: marca eliminado = 1 (nunca DELETE) y vuelve el nombre oficial.
  Future<void> quitarAlias(int idEjercicio) async {
    await EscrituraLocal(_bd).marcarEliminado(
      'usuario_ejercicio',
      where: 'id_usuario = ? AND id_ejercicio = ? AND eliminado = 0',
      whereArgs: [_idUsuario, idEjercicio],
    );
  }

  static String _escaparLike(String texto) =>
      texto.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
}

/// Repositorio del catálogo para el usuario actual (null si no hay usuario).
final catalogoRepositorioProvider = FutureProvider<CatalogoRepositorio?>((ref) async {
  final idUsuario = ref.watch(usuarioActualIdProvider);
  if (idUsuario == null) return null;
  final bd = await ref.watch(baseDatosProvider.future);
  return CatalogoRepositorio(bd, idUsuario);
});
