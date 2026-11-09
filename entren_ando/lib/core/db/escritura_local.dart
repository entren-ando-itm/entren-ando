import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'fechas.dart';

/// La única forma de escribir en las tablas del usuario.
///
/// Llena creado_en y actualizado_en, marca pendiente_sync = 1 para que el
/// motor de sincronización suba el cambio, y nunca borra con DELETE.
///
/// Ejemplo:
/// ```dart
/// final bd = await ref.read(baseDatosProvider.future);
/// await bd.transaction((txn) async {
///   final escritura = EscrituraLocal(txn);
///   final idSesion = await escritura.insertar('sesion_entrenamiento', {
///     'id_usuario': idUsuario,
///     'fecha': Fechas.hoy(),
///     'estado': 'parcial',
///   });
///   await escritura.actualizar('sesion_entrenamiento', {'estado': 'completa'},
///       where: 'id_sesion = ?', whereArgs: [idSesion]);
/// });
/// ```
class EscrituraLocal {
  EscrituraLocal(this._bd);

  /// Puede ser la base (Database) o una transacción (Transaction).
  final DatabaseExecutor _bd;

  static final Uuid _uuid = Uuid();

  /// Tablas del usuario con id UUID y el nombre de su columna id.
  static const Map<String, String> llavePrimaria = {
    'usuario': 'id_usuario',
    'perfil_entrenamiento': 'id_perfil',
    'medicion_biometrica': 'id_medicion',
    'solicitud_ia': 'id_solicitud',
    'ciclo_rutina': 'id_ciclo',
    'dia_rutina': 'id_dia',
    'ejercicio_programado': 'id_programado',
    'alternativa_ejercicio': 'id_alternativa',
    'sesion_entrenamiento': 'id_sesion',
    'registro_ejercicio': 'id_registro',
    'serie': 'id_serie',
    'registro_comida': 'id_comida',
    'feedback_ia': 'id_feedback',
    'suscripcion': 'id_suscripcion',
    'evento_pago': 'id_evento',
  };

  /// Tablas del usuario con llave compuesta.
  static const Map<String, List<String>> llaveCompuesta = {
    'usuario_equipo': ['id_usuario', 'id_equipo'],
    'usuario_ejercicio': ['id_usuario', 'id_ejercicio'],
  };

  /// Inserta una fila y devuelve su id.
  ///
  /// Si no mandas el id, se genera un UUID. En usuario_equipo y
  /// usuario_ejercicio devuelve null y, si la relación ya existía (aunque
  /// estuviera eliminada), la reactiva con los valores nuevos.
  Future<String?> insertar(String tabla, Map<String, Object?> valores) async {
    _validarTabla(tabla);
    final ahora = Fechas.ahoraIso();
    final fila = <String, Object?>{
      ...valores,
      'creado_en': valores['creado_en'] ?? ahora,
      'actualizado_en': ahora,
      'eliminado': 0,
      'pendiente_sync': 1,
    };

    final columnaId = llavePrimaria[tabla];
    if (columnaId != null) {
      fila[columnaId] ??= _uuid.v4();
      await _bd.insert(tabla, fila);
      return fila[columnaId] as String;
    }

    final llaves = llaveCompuesta[tabla]!;
    final columnas = fila.keys.toList();
    final cambios = columnas
        .where((c) => !llaves.contains(c) && c != 'creado_en')
        .map((c) => '$c = excluded.$c')
        .join(', ');
    await _bd.rawInsert(
      'INSERT INTO $tabla (${columnas.join(', ')}) '
      'VALUES (${List.filled(columnas.length, '?').join(', ')}) '
      'ON CONFLICT (${llaves.join(', ')}) DO UPDATE SET $cambios',
      fila.values.toList(),
    );
    return null;
  }

  /// Actualiza las filas que cumplen [where]. Devuelve cuántas cambiaron.
  Future<int> actualizar(
    String tabla,
    Map<String, Object?> cambios, {
    required String where,
    List<Object?>? whereArgs,
  }) {
    _validarTabla(tabla);
    return _bd.update(
      tabla,
      {...cambios, 'actualizado_en': Fechas.ahoraIso(), 'pendiente_sync': 1},
      where: where,
      whereArgs: whereArgs,
    );
  }

  /// Marca como eliminadas las filas que cumplen [where] (nunca usa DELETE).
  ///
  /// Si la fila tiene hijos (por ejemplo, un ciclo con sus días), márcalos
  /// también en la misma transacción.
  Future<int> marcarEliminado(
    String tabla, {
    required String where,
    List<Object?>? whereArgs,
  }) {
    return actualizar(tabla, {'eliminado': 1}, where: where, whereArgs: whereArgs);
  }

  void _validarTabla(String tabla) {
    if (!llavePrimaria.containsKey(tabla) && !llaveCompuesta.containsKey(tabla)) {
      throw ArgumentError.value(
        tabla,
        'tabla',
        'No es una tabla del usuario. Los catálogos (plan, equipo y ejercicio) '
            'no se modifican desde la app.',
      );
    }
  }
}
