import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../core/db/base_datos.dart';
import '../../core/db/escritura_local.dart';
import '../../core/db/fechas.dart';
import '../../core/db/usuario_actual.dart';
import '../perfil/catalogo/catalogo_repositorio.dart';

/// Nombres de los días como en `dia_rutina.dia_semana` (1 = lunes ... 7 = domingo).
const List<String> nombresDiaSemana = [
  'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo',
];

/// Un ciclo de rutina (por ejemplo, un semestre).
class Ciclo {
  const Ciclo({
    required this.idCiclo,
    required this.nombre,
    required this.fechaInicio,
    required this.estado,
    required this.origen,
    this.fechaFin,
    this.diasEntrenamiento = 0,
  });

  final String idCiclo;
  final String nombre;
  final String fechaInicio;
  final String? fechaFin;

  /// 'activo' o 'archivado'.
  final String estado;

  /// 'ia' o 'manual'.
  final String origen;
  final int diasEntrenamiento;

  bool get activo => estado == 'activo';
}

/// Uno de los 7 días de un ciclo.
class DiaRutina {
  const DiaRutina({
    required this.idDia,
    required this.idCiclo,
    required this.diaSemana,
    required this.nombre,
    required this.esDescanso,
    this.ejercicios = 0,
  });

  final String idDia;
  final String idCiclo;

  /// 1 = lunes ... 7 = domingo.
  final int diaSemana;
  final String nombre;
  final bool esDescanso;
  final int ejercicios;

  String get nombreDiaSemana => nombresDiaSemana[diaSemana - 1];
}

/// Un ejercicio programado en un día, con el nombre visible (alias) del usuario.
class EjercicioProgramado {
  const EjercicioProgramado({
    required this.idProgramado,
    required this.idDia,
    required this.idEjercicio,
    required this.nombre,
    required this.nombreOficial,
    required this.grupoMuscular,
    required this.orden,
    required this.series,
    required this.repeticiones,
    required this.descansoSeg,
    this.pesoKg,
    this.trabajoSeg,
    this.alternativas = 0,
  });

  final String idProgramado;
  final String idDia;
  final int idEjercicio;

  /// Alias del usuario o nombre oficial. A la IA se manda [nombreOficial].
  final String nombre;
  final String nombreOficial;
  final String grupoMuscular;
  final int orden;
  final int series;
  final int repeticiones;
  final double? pesoKg;
  final int descansoSeg;
  final int? trabajoSeg;

  /// Cuántas alternativas tiene (ENT-48).
  final int alternativas;
}

/// Cuántos ciclos permite el plan del usuario y cuántos tiene.
///
/// RN-01 precisada por el PO (25 de noviembre): en Gratuito el límite cuenta
/// TODOS los ciclos (activos y archivados), así no se puede archivar y
/// reactivar para tener varias rutinas. Se edita el ciclo que ya se tiene.
/// Los ciclos que sobran al dejar Premium se quedan archivados solo para
/// consultarlos.
class LimiteCiclos {
  const LimiteCiclos({required this.plan, required this.activos, this.maximo, int? total})
      : total = total ?? activos;

  final String plan;
  final int activos;

  /// Ciclos sin borrar (activos y archivados).
  final int total;

  /// null = ilimitado (Premium). Sale de `plan.max_ciclos_activos`.
  final int? maximo;

  bool get puedeActivarOtro => maximo == null || activos < maximo!;

  /// Crear un ciclo nuevo: en Gratuito solo si aún no tiene ninguno.
  bool get puedeCrearOtro => maximo == null || total < maximo!;

  /// Reactivar un archivado: en Gratuito solo si es su único ciclo.
  bool get puedeReactivar => maximo == null || (total <= maximo! && activos < maximo!);
}

/// Se lanza al activar un ciclo cuando el plan ya no permite otro (RN-01).
class LimiteCiclosAlcanzado implements Exception {
  const LimiteCiclosAlcanzado(this.limite);

  final LimiteCiclos limite;

  @override
  String toString() => 'Tu plan ${limite.plan} permite ${limite.maximo} ciclo(s) activo(s).';
}

/// Se lanza al intentar editar un ciclo archivado (se ve en solo lectura).
class CicloSoloLectura implements Exception {
  const CicloSoloLectura();

  @override
  String toString() => 'El ciclo está archivado. Reactívalo para editarlo.';
}

/// Valores para un ejercicio programado. Mismas reglas que los CHECK del
/// esquema, más series y repeticiones de al menos 1.
abstract final class ValidarRutina {
  static String? nombre(String? texto) {
    final limpio = texto?.trim() ?? '';
    if (limpio.isEmpty) return 'Escribe un nombre.';
    if (limpio.length > 60) return 'Usa 60 letras o menos.';
    return null;
  }

  /// CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio). Fechas 'AAAA-MM-DD'.
  static String? fechas(String inicio, String? fin) {
    if (fin != null && fin.compareTo(inicio) < 0) {
      return 'La fecha de fin no puede ser antes del inicio.';
    }
    return null;
  }

  static String? series(String? texto) => _entero(texto, minimo: 1, maximo: 20, que: 'series');

  static String? repeticiones(String? texto) =>
      _entero(texto, minimo: 1, maximo: 100, que: 'repeticiones');

  /// CHECK (descanso_seg >= 0).
  static String? descansoSeg(String? texto) =>
      _entero(texto, minimo: 0, maximo: 900, que: 'segundos de descanso');

  /// Opcional. CHECK (trabajo_seg IS NULL OR trabajo_seg >= 0).
  static String? trabajoSeg(String? texto) {
    if ((texto ?? '').trim().isEmpty) return null;
    return _entero(texto, minimo: 0, maximo: 3600, que: 'segundos de trabajo');
  }

  /// Opcional. Peso en kg, 0 o más.
  static String? pesoKg(String? texto) {
    if ((texto ?? '').trim().isEmpty) return null;
    final peso = double.tryParse(texto!.trim().replaceAll(',', '.'));
    if (peso == null) return 'Escribe el peso en kg o déjalo vacío.';
    if (peso < 0 || peso > 500) return 'Usa de 0 a 500 kg.';
    return null;
  }

  static String? _entero(String? texto, {required int minimo, required int maximo, required String que}) {
    final valor = int.tryParse((texto ?? '').trim());
    if (valor == null) return 'Escribe un número de $que.';
    if (valor < minimo || valor > maximo) return 'Usa de $minimo a $maximo $que.';
    return null;
  }
}

/// Ciclos, días y ejercicios programados del usuario (ENT-47).
///
/// Los ciclos nunca se borran: se archivan. El límite de ciclos activos sale
/// de `plan.max_ciclos_activos` (NULL = ilimitado), no de un `if` en el código.
class RutinasRepositorio {
  RutinasRepositorio(this._bd, this._idUsuario);

  final Database _bd;
  final String _idUsuario;

  /// Ciclo que usa la pestaña Hoy: el activo con fecha_inicio más reciente
  /// (criterio 4). El primer `?` es el id del usuario.
  static const String consultaCicloParaHoy = '''
    SELECT id_ciclo, nombre
    FROM ciclo_rutina
    WHERE id_usuario = ? AND estado = 'activo' AND eliminado = 0
    ORDER BY fecha_inicio DESC, creado_en DESC
    LIMIT 1
  ''';

  // ---------- Ciclos ----------

  Future<List<Ciclo>> ciclos() async {
    final filas = await _bd.rawQuery('''
      SELECT c.id_ciclo, c.nombre, c.fecha_inicio, c.fecha_fin, c.estado, c.origen,
             (SELECT COUNT(*) FROM dia_rutina d
              WHERE d.id_ciclo = c.id_ciclo AND d.eliminado = 0 AND d.es_descanso = 0) AS dias
      FROM ciclo_rutina c
      WHERE c.id_usuario = ? AND c.eliminado = 0
      ORDER BY CASE c.estado WHEN 'activo' THEN 0 ELSE 1 END, c.fecha_inicio DESC, c.creado_en DESC
    ''', [_idUsuario]);
    return filas.map(_ciclo).toList();
  }

  Future<Ciclo?> ciclo(String idCiclo) async {
    final filas = await _bd.rawQuery('''
      SELECT c.id_ciclo, c.nombre, c.fecha_inicio, c.fecha_fin, c.estado, c.origen,
             (SELECT COUNT(*) FROM dia_rutina d
              WHERE d.id_ciclo = c.id_ciclo AND d.eliminado = 0 AND d.es_descanso = 0) AS dias
      FROM ciclo_rutina c
      WHERE c.id_ciclo = ? AND c.id_usuario = ? AND c.eliminado = 0
    ''', [idCiclo, _idUsuario]);
    return filas.isEmpty ? null : _ciclo(filas.first);
  }

  /// Límite del plan del usuario y cuántos ciclos activos tiene ahora.
  Future<LimiteCiclos> limite() => _limite(_bd);

  Future<LimiteCiclos> _limite(DatabaseExecutor bd) async {
    final filas = await bd.rawQuery('''
      SELECT p.nombre, p.max_ciclos_activos,
             (SELECT COUNT(*) FROM ciclo_rutina c
              WHERE c.id_usuario = u.id_usuario AND c.estado = 'activo' AND c.eliminado = 0) AS activos,
             (SELECT COUNT(*) FROM ciclo_rutina c
              WHERE c.id_usuario = u.id_usuario AND c.eliminado = 0) AS total
      FROM usuario u
      JOIN plan p ON p.id_plan = u.id_plan
      WHERE u.id_usuario = ? AND u.eliminado = 0
    ''', [_idUsuario]);
    if (filas.isEmpty) throw StateError('No existe el usuario.');
    final f = filas.first;
    return LimiteCiclos(
      plan: f['nombre'] as String,
      activos: f['activos'] as int,
      total: f['total'] as int,
      maximo: f['max_ciclos_activos'] as int?,
    );
  }

  /// Crea un ciclo con sus 7 días (todos de descanso para empezar).
  ///
  /// Si [activar] es true y el plan ya no permite otro activo, lanza
  /// [LimiteCiclosAlcanzado] y no guarda nada.
  Future<String> crearCiclo({
    required String nombre,
    required String fechaInicio,
    String? fechaFin,
    bool activar = true,
  }) async {
    final error = ValidarRutina.nombre(nombre) ?? ValidarRutina.fechas(fechaInicio, fechaFin);
    if (error != null) throw ArgumentError(error);

    return _bd.transaction((txn) async {
      final limite = await _limite(txn);
      if (!limite.puedeCrearOtro) throw LimiteCiclosAlcanzado(limite);
      if (activar && !limite.puedeActivarOtro) throw LimiteCiclosAlcanzado(limite);
      final escritura = EscrituraLocal(txn);
      final idCiclo = (await escritura.insertar('ciclo_rutina', {
        'id_usuario': _idUsuario,
        'nombre': nombre.trim(),
        'fecha_inicio': fechaInicio,
        'fecha_fin': fechaFin,
        'estado': activar ? 'activo' : 'archivado',
        'origen': 'manual',
      }))!;
      for (var dia = 1; dia <= 7; dia++) {
        await escritura.insertar('dia_rutina', {
          'id_ciclo': idCiclo,
          'dia_semana': dia,
          'nombre': 'Descanso',
          'es_descanso': 1,
        });
      }
      return idCiclo;
    });
  }

  /// Cambia nombre y fechas de un ciclo activo.
  Future<void> actualizarCiclo(String idCiclo, {
    required String nombre,
    required String fechaInicio,
    String? fechaFin,
  }) async {
    final error = ValidarRutina.nombre(nombre) ?? ValidarRutina.fechas(fechaInicio, fechaFin);
    if (error != null) throw ArgumentError(error);
    await _bd.transaction((txn) async {
      await _exigirEditable(txn, idCiclo);
      await EscrituraLocal(txn).actualizar(
        'ciclo_rutina',
        {'nombre': nombre.trim(), 'fecha_inicio': fechaInicio, 'fecha_fin': fechaFin},
        where: 'id_ciclo = ? AND id_usuario = ? AND eliminado = 0',
        whereArgs: [idCiclo, _idUsuario],
      );
    });
  }

  /// Archiva un ciclo (nunca se borra). Deja de verse en Hoy.
  Future<void> archivarCiclo(String idCiclo) async {
    await EscrituraLocal(_bd).actualizar(
      'ciclo_rutina',
      {'estado': 'archivado'},
      where: 'id_ciclo = ? AND id_usuario = ? AND eliminado = 0',
      whereArgs: [idCiclo, _idUsuario],
    );
  }

  /// Activa (o reactiva) un ciclo respetando el límite del plan.
  ///
  /// Si pasas [archivarAntes], esos ciclos se archivan en la misma
  /// transacción, así el usuario cambia de ciclo en un solo paso.
  Future<void> activarCiclo(String idCiclo, {List<String> archivarAntes = const []}) async {
    await _bd.transaction((txn) async {
      final escritura = EscrituraLocal(txn);
      for (final otro in archivarAntes) {
        if (otro == idCiclo) continue;
        await escritura.actualizar(
          'ciclo_rutina',
          {'estado': 'archivado'},
          where: 'id_ciclo = ? AND id_usuario = ? AND eliminado = 0',
          whereArgs: [otro, _idUsuario],
        );
      }
      final actual = await txn.rawQuery(
        'SELECT estado FROM ciclo_rutina WHERE id_ciclo = ? AND id_usuario = ? AND eliminado = 0',
        [idCiclo, _idUsuario],
      );
      if (actual.isEmpty) throw StateError('No existe el ciclo.');
      if (actual.first['estado'] == 'activo') return;
      final limite = await _limite(txn);
      if (!limite.puedeReactivar) throw LimiteCiclosAlcanzado(limite);
      await escritura.actualizar(
        'ciclo_rutina',
        {'estado': 'activo'},
        where: 'id_ciclo = ? AND id_usuario = ? AND eliminado = 0',
        whereArgs: [idCiclo, _idUsuario],
      );
    });
  }

  // ---------- Días ----------

  /// Los 7 días del ciclo, de lunes a domingo, con cuántos ejercicios tiene cada uno.
  Future<List<DiaRutina>> dias(String idCiclo) async {
    final filas = await _bd.rawQuery('''
      SELECT d.id_dia, d.id_ciclo, d.dia_semana, d.nombre, d.es_descanso,
             (SELECT COUNT(*) FROM ejercicio_programado ep
              WHERE ep.id_dia = d.id_dia AND ep.eliminado = 0) AS ejercicios
      FROM dia_rutina d
      JOIN ciclo_rutina c ON c.id_ciclo = d.id_ciclo
      WHERE d.id_ciclo = ? AND c.id_usuario = ? AND d.eliminado = 0
      ORDER BY d.dia_semana
    ''', [idCiclo, _idUsuario]);
    return filas.map(_dia).toList();
  }

  Future<DiaRutina?> dia(String idDia) async {
    final filas = await _bd.rawQuery('''
      SELECT d.id_dia, d.id_ciclo, d.dia_semana, d.nombre, d.es_descanso,
             (SELECT COUNT(*) FROM ejercicio_programado ep
              WHERE ep.id_dia = d.id_dia AND ep.eliminado = 0) AS ejercicios
      FROM dia_rutina d
      JOIN ciclo_rutina c ON c.id_ciclo = d.id_ciclo
      WHERE d.id_dia = ? AND c.id_usuario = ? AND d.eliminado = 0
    ''', [idDia, _idUsuario]);
    return filas.isEmpty ? null : _dia(filas.first);
  }

  /// Cambia el nombre del día y si es de descanso. Al marcarlo como descanso
  /// los ejercicios se conservan (por si el usuario se arrepiente).
  Future<void> actualizarDia(String idDia, {required String nombre, required bool esDescanso}) async {
    final error = ValidarRutina.nombre(nombre);
    if (error != null) throw ArgumentError(error);
    await _bd.transaction((txn) async {
      await _exigirEditable(txn, await _cicloDeDia(txn, idDia));
      await EscrituraLocal(txn).actualizar(
        'dia_rutina',
        {'nombre': nombre.trim(), 'es_descanso': esDescanso ? 1 : 0},
        where: 'id_dia = ? AND eliminado = 0',
        whereArgs: [idDia],
      );
    });
  }

  // ---------- Ejercicios programados ----------

  /// Consulta de los ejercicios de un día con el alias del usuario.
  /// Argumentos: id del usuario (para el alias) y id del día.
  static const String consultaEjerciciosDelDia = '''
    SELECT ep.id_programado, ep.id_dia, ep.id_ejercicio, ep.orden, ep.series_objetivo,
           ep.reps_objetivo, ep.peso_objetivo_kg, ep.descanso_seg, ep.trabajo_seg,
           e.nombre_oficial, e.grupo_muscular,
           ${CatalogoRepositorio.nombreVisible} AS nombre,
           (SELECT COUNT(*) FROM alternativa_ejercicio a
            WHERE a.id_programado = ep.id_programado AND a.eliminado = 0) AS alternativas
    FROM ejercicio_programado ep
    JOIN ejercicio e ON e.id_ejercicio = ep.id_ejercicio
    ${CatalogoRepositorio.joinAlias}
    WHERE ep.id_dia = ? AND ep.eliminado = 0
    ORDER BY ep.orden, ep.creado_en
  ''';

  Future<List<EjercicioProgramado>> ejerciciosDelDia(String idDia) async {
    final filas = await _bd.rawQuery(consultaEjerciciosDelDia, [_idUsuario, idDia]);
    return filas
        .map((f) => EjercicioProgramado(
              idProgramado: f['id_programado'] as String,
              idDia: f['id_dia'] as String,
              idEjercicio: f['id_ejercicio'] as int,
              nombre: f['nombre'] as String,
              nombreOficial: f['nombre_oficial'] as String,
              grupoMuscular: f['grupo_muscular'] as String,
              orden: f['orden'] as int,
              series: f['series_objetivo'] as int,
              repeticiones: f['reps_objetivo'] as int,
              pesoKg: (f['peso_objetivo_kg'] as num?)?.toDouble(),
              descansoSeg: f['descanso_seg'] as int,
              trabajoSeg: f['trabajo_seg'] as int?,
              alternativas: f['alternativas'] as int,
            ))
        .toList();
  }

  /// Agrega un ejercicio del catálogo al final del día (3 × 10, 90 s de descanso).
  Future<String> agregarEjercicio(String idDia, int idEjercicio) async {
    return _bd.transaction((txn) async {
      await _exigirEditable(txn, await _cicloDeDia(txn, idDia));
      final maximo = await txn.rawQuery(
        'SELECT COALESCE(MAX(orden), -1) AS orden FROM ejercicio_programado WHERE id_dia = ? AND eliminado = 0',
        [idDia],
      );
      final escritura = EscrituraLocal(txn);
      final id = (await escritura.insertar('ejercicio_programado', {
        'id_dia': idDia,
        'id_ejercicio': idEjercicio,
        'orden': (maximo.first['orden'] as int) + 1,
        'series_objetivo': 3,
        'reps_objetivo': 10,
        'descanso_seg': 90,
      }))!;
      // Un día con ejercicios ya no es de descanso.
      await escritura.actualizar(
        'dia_rutina',
        {'es_descanso': 0},
        where: 'id_dia = ? AND es_descanso = 1 AND eliminado = 0',
        whereArgs: [idDia],
      );
      return id;
    });
  }

  /// Cambia series, repeticiones, peso, descanso y trabajo.
  Future<void> actualizarEjercicio(
    String idProgramado, {
    required int series,
    required int repeticiones,
    required int descansoSeg,
    double? pesoKg,
    int? trabajoSeg,
  }) async {
    final error = ValidarRutina.series('$series') ??
        ValidarRutina.repeticiones('$repeticiones') ??
        ValidarRutina.descansoSeg('$descansoSeg') ??
        (pesoKg == null ? null : ValidarRutina.pesoKg('$pesoKg')) ??
        (trabajoSeg == null ? null : ValidarRutina.trabajoSeg('$trabajoSeg'));
    if (error != null) throw ArgumentError(error);
    await _bd.transaction((txn) async {
      await _exigirEditable(txn, await _cicloDeProgramado(txn, idProgramado));
      await EscrituraLocal(txn).actualizar(
        'ejercicio_programado',
        {
          'series_objetivo': series,
          'reps_objetivo': repeticiones,
          'peso_objetivo_kg': pesoKg,
          'descanso_seg': descansoSeg,
          'trabajo_seg': trabajoSeg,
        },
        where: 'id_programado = ? AND eliminado = 0',
        whereArgs: [idProgramado],
      );
    });
  }

  /// Quita un ejercicio del día y sus alternativas (eliminado = 1, nunca DELETE).
  Future<void> quitarEjercicio(String idProgramado) async {
    await _bd.transaction((txn) async {
      final idDia = await _diaDeProgramado(txn, idProgramado);
      await _exigirEditable(txn, await _cicloDeDia(txn, idDia));
      final escritura = EscrituraLocal(txn);
      await escritura.marcarEliminado(
        'alternativa_ejercicio',
        where: 'id_programado = ? AND eliminado = 0',
        whereArgs: [idProgramado],
      );
      await escritura.marcarEliminado(
        'ejercicio_programado',
        where: 'id_programado = ? AND eliminado = 0',
        whereArgs: [idProgramado],
      );
      await _renumerar(txn, idDia, null);
    });
  }

  /// Mueve un ejercicio a [posicion] (0 = primero) y renumera el orden del día.
  Future<void> moverEjercicio(String idProgramado, int posicion) async {
    await _bd.transaction((txn) async {
      final idDia = await _diaDeProgramado(txn, idProgramado);
      await _exigirEditable(txn, await _cicloDeDia(txn, idDia));
      await _renumerar(txn, idDia, (idProgramado, posicion));
    });
  }

  /// Nuevo orden de ids después de mover [id] a [posicion]. Es público para probarlo.
  static List<String> reordenar(List<String> ids, String id, int posicion) {
    final lista = List.of(ids)..remove(id);
    lista.insert(posicion.clamp(0, lista.length), id);
    return lista;
  }

  Future<void> _renumerar(Transaction txn, String idDia, (String, int)? mover) async {
    final filas = await txn.rawQuery(
      'SELECT id_programado, orden FROM ejercicio_programado WHERE id_dia = ? AND eliminado = 0 '
      'ORDER BY orden, creado_en',
      [idDia],
    );
    var ids = filas.map((f) => f['id_programado'] as String).toList();
    if (mover != null) ids = reordenar(ids, mover.$1, mover.$2);
    final escritura = EscrituraLocal(txn);
    for (var i = 0; i < ids.length; i++) {
      final anterior = filas.firstWhere((f) => f['id_programado'] == ids[i])['orden'];
      if (anterior == i) continue; // Solo marca para sincronizar lo que cambió.
      await escritura.actualizar(
        'ejercicio_programado',
        {'orden': i},
        where: 'id_programado = ?',
        whereArgs: [ids[i]],
      );
    }
  }

  // ---------- Ayudantes ----------

  Future<void> _exigirEditable(DatabaseExecutor bd, String idCiclo) async {
    final filas = await bd.rawQuery(
      'SELECT estado FROM ciclo_rutina WHERE id_ciclo = ? AND id_usuario = ? AND eliminado = 0',
      [idCiclo, _idUsuario],
    );
    if (filas.isEmpty) throw StateError('No existe el ciclo.');
    if (filas.first['estado'] != 'activo') throw const CicloSoloLectura();
  }

  Future<String> _cicloDeDia(DatabaseExecutor bd, String idDia) async {
    final filas = await bd.rawQuery(
      'SELECT id_ciclo FROM dia_rutina WHERE id_dia = ? AND eliminado = 0',
      [idDia],
    );
    if (filas.isEmpty) throw StateError('No existe el día.');
    return filas.first['id_ciclo'] as String;
  }

  Future<String> _diaDeProgramado(DatabaseExecutor bd, String idProgramado) async {
    final filas = await bd.rawQuery(
      'SELECT id_dia FROM ejercicio_programado WHERE id_programado = ? AND eliminado = 0',
      [idProgramado],
    );
    if (filas.isEmpty) throw StateError('No existe el ejercicio programado.');
    return filas.first['id_dia'] as String;
  }

  Future<String> _cicloDeProgramado(DatabaseExecutor bd, String idProgramado) async =>
      _cicloDeDia(bd, await _diaDeProgramado(bd, idProgramado));

  static Ciclo _ciclo(Map<String, Object?> f) => Ciclo(
        idCiclo: f['id_ciclo'] as String,
        nombre: f['nombre'] as String,
        fechaInicio: f['fecha_inicio'] as String,
        fechaFin: f['fecha_fin'] as String?,
        estado: f['estado'] as String,
        origen: f['origen'] as String,
        diasEntrenamiento: f['dias'] as int,
      );

  static DiaRutina _dia(Map<String, Object?> f) => DiaRutina(
        idDia: f['id_dia'] as String,
        idCiclo: f['id_ciclo'] as String,
        diaSemana: f['dia_semana'] as int,
        nombre: f['nombre'] as String,
        esDescanso: f['es_descanso'] == 1,
        ejercicios: f['ejercicios'] as int,
      );

  /// Fecha de hoy para el formulario de un ciclo nuevo.
  static String hoy() => Fechas.hoy();
}

/// Repositorio de rutinas para el usuario actual (null si no hay usuario).
final rutinasRepositorioProvider = FutureProvider<RutinasRepositorio?>((ref) async {
  final idUsuario = ref.watch(usuarioActualIdProvider);
  if (idUsuario == null) return null;
  final bd = await ref.watch(baseDatosProvider.future);
  return RutinasRepositorio(bd, idUsuario);
});
