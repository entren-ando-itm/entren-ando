import 'package:flutter/foundation.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Una tabla del usuario que se sube a Supabase.
class TablaSync {
  const TablaSync(
    this.nombre,
    this.llaves, {
    this.booleanas = const [],
    this.dueno = porIdUsuario,
  });

  /// Filtro para las tablas que tienen id_usuario.
  static const String porIdUsuario = 'id_usuario = ?';

  final String nombre;

  /// Columnas de la llave primaria (para el upsert y para marcar la fila).
  final List<String> llaves;

  /// Columnas que en el celular son 0/1 y en Supabase son boolean, además de
  /// eliminado y pendiente_sync.
  final List<String> booleanas;

  /// Condición SQL (con un solo `?`, el id del usuario) que deja solo las filas
  /// de ese usuario. Las tablas hijas sin id_usuario llegan a él por su padre,
  /// así que si hay varias cuentas en el mismo celular no se mezclan.
  final String dueno;

  /// true si la tabla tiene la columna id_usuario.
  bool get porUsuario => dueno == porIdUsuario;
}

/// Lo que pasó en una sincronización.
class ResultadoSync {
  const ResultadoSync({this.subidas = 0, this.rechazadas = 0, this.errores = const []});

  /// Filas que Supabase confirmó.
  final int subidas;

  /// Filas que Supabase rechazó (siguen pendientes y se reintentan después).
  final int rechazadas;

  /// Mensajes de Supabase de las filas rechazadas, sin repetir.
  final List<String> errores;
}

/// Sube a Supabase lo que se guardó en el celular (ENT-44, RNF-01).
///
/// * Lee las filas con `pendiente_sync = 1` de cada tabla del usuario, en orden
///   de llaves foráneas (padres antes que hijos).
/// * Hace upsert por id en lotes de [tamanoLote]: si se corta la red a la mitad
///   y se reintenta, no se duplica nada.
/// * Cuando Supabase confirma, pone `pendiente_sync = 0` (es el único lugar de
///   la app que lo hace). Si la fila cambió mientras subía, se queda pendiente.
/// * Los borrados viajan como `eliminado = true`. Nunca borra filas locales.
/// * Solo sube las filas del usuario: las tablas hijas se filtran por su padre.
/// * Los catálogos no se suben. `solicitud_ia` y `evento_pago` los crea el
///   servidor (Edge Functions) y el celular guarda el mismo id; de
///   `feedback_ia` solo se sube `leido`.
/// * Usa la sesión del usuario: la seguridad la da RLS (nunca la service_role).
class MotorSync {
  MotorSync(this._bd, this._nube);

  final Database _bd;
  final SupabaseClient _nube;

  static const int tamanoLote = 100;

  /// En orden: cada tabla va después de las tablas a las que apunta.
  static const List<TablaSync> tablas = [
    TablaSync('usuario', ['id_usuario']),
    TablaSync('perfil_entrenamiento', ['id_perfil']),
    TablaSync('medicion_biometrica', ['id_medicion']),
    TablaSync('usuario_equipo', ['id_usuario', 'id_equipo']),
    TablaSync('usuario_ejercicio', ['id_usuario', 'id_ejercicio']),
    TablaSync('suscripcion', ['id_suscripcion'], booleanas: ['renovacion_automatica']),
    TablaSync('ciclo_rutina', ['id_ciclo']),
    TablaSync(
      'dia_rutina',
      ['id_dia'],
      booleanas: ['es_descanso'],
      dueno: 'id_ciclo IN (SELECT id_ciclo FROM ciclo_rutina WHERE id_usuario = ?)',
    ),
    TablaSync(
      'ejercicio_programado',
      ['id_programado'],
      dueno: 'id_dia IN (SELECT d.id_dia FROM dia_rutina d '
          'JOIN ciclo_rutina c ON c.id_ciclo = d.id_ciclo WHERE c.id_usuario = ?)',
    ),
    TablaSync(
      'alternativa_ejercicio',
      ['id_alternativa'],
      dueno: 'id_programado IN (SELECT p.id_programado FROM ejercicio_programado p '
          'JOIN dia_rutina d ON d.id_dia = p.id_dia '
          'JOIN ciclo_rutina c ON c.id_ciclo = d.id_ciclo WHERE c.id_usuario = ?)',
    ),
    TablaSync('sesion_entrenamiento', ['id_sesion'], booleanas: ['es_override']),
    TablaSync(
      'registro_ejercicio',
      ['id_registro'],
      booleanas: ['es_sustitucion', 'completado'],
      dueno: 'id_sesion IN (SELECT id_sesion FROM sesion_entrenamiento WHERE id_usuario = ?)',
    ),
    TablaSync(
      'serie',
      ['id_serie'],
      dueno: 'id_registro IN (SELECT r.id_registro FROM registro_ejercicio r '
          'JOIN sesion_entrenamiento s ON s.id_sesion = r.id_sesion WHERE s.id_usuario = ?)',
    ),
    TablaSync('registro_comida', ['id_comida']),
  ];

  /// Sube lo pendiente del usuario [idUsuario].
  ///
  /// Con [todo] = true sube también lo que ya estaba sincronizado (sirve para
  /// subir los datos de prueba, que vienen con pendiente_sync = 0).
  ///
  /// Si se pierde la conexión, lanza la excepción y lo que no alcanzó a subir
  /// sigue pendiente para la próxima vez.
  Future<ResultadoSync> subirPendientes(String idUsuario, {bool todo = false}) async {
    final porTabla = <TablaSync, List<Map<String, Object?>>>{};
    for (final tabla in tablas) {
      porTabla[tabla] = await _leer(tabla, idUsuario, todo: todo);
    }
    final feedback = await _bd.rawQuery(
      'SELECT id_feedback, leido, actualizado_en FROM feedback_ia '
      'WHERE id_usuario = ?${todo ? '' : ' AND pendiente_sync = 1'}',
      [idUsuario],
    );

    final hayAlgo = porTabla.values.any((filas) => filas.isNotEmpty) || feedback.isNotEmpty;
    if (!hayAlgo) return const ResultadoSync();

    // Todas las tablas apuntan al usuario: se sube primero aunque no haya
    // cambiado, por si es la primera vez que este usuario sincroniza.
    if (porTabla[tablas.first]!.isEmpty) {
      porTabla[tablas.first] = await _bd.rawQuery(
        'SELECT * FROM usuario WHERE id_usuario = ?',
        [idUsuario],
      );
    }

    var subidas = 0;
    var rechazadas = 0;
    final errores = <String>{};

    for (final tabla in tablas) {
      final filas = porTabla[tabla]!;
      for (var i = 0; i < filas.length; i += tamanoLote) {
        final lote = filas.sublist(i, i + tamanoLote > filas.length ? filas.length : i + tamanoLote);
        try {
          await _subir(tabla, lote);
          await _marcarSincronizadas(tabla, lote);
          subidas += lote.length;
        } on PostgrestException catch (e) {
          // Supabase rechazó el lote (una fila mala no debe frenar las demás):
          // se intenta una por una.
          if (lote.length == 1) {
            rechazadas++;
            errores.add('${tabla.nombre}: ${e.message}');
            continue;
          }
          for (final fila in lote) {
            try {
              await _subir(tabla, [fila]);
              await _marcarSincronizadas(tabla, [fila]);
              subidas++;
            } on PostgrestException catch (e) {
              rechazadas++;
              errores.add('${tabla.nombre}: ${e.message}');
            }
          }
        }
      }
    }

    // feedback_ia lo crea el servidor; la app solo cambia "leido".
    for (final fila in feedback) {
      try {
        await _nube
            .from('feedback_ia')
            .update({'leido': fila['leido'] == 1})
            .eq('id_feedback', fila['id_feedback'] as String);
        await _bd.rawUpdate(
          'UPDATE feedback_ia SET pendiente_sync = 0 WHERE id_feedback = ? AND actualizado_en = ?',
          [fila['id_feedback'], fila['actualizado_en']],
        );
        subidas++;
      } on PostgrestException catch (e) {
        rechazadas++;
        errores.add('feedback_ia: ${e.message}');
      }
    }

    if (errores.isNotEmpty) debugPrint('Entren-Ando sync: ${errores.join(' | ')}');
    return ResultadoSync(subidas: subidas, rechazadas: rechazadas, errores: errores.toList());
  }

  /// Cuántas filas del usuario faltan por subir (para mostrarlo en pantalla).
  Future<int> contarPendientes(String idUsuario) async {
    var total = 0;
    for (final tabla in [...tablas, const TablaSync('feedback_ia', ['id_feedback'])]) {
      final filas = await _bd.rawQuery(
        'SELECT COUNT(*) AS n FROM ${tabla.nombre} WHERE pendiente_sync = 1 AND ${tabla.dueno}',
        [idUsuario],
      );
      total += filas.first['n'] as int? ?? 0;
    }
    return total;
  }

  Future<List<Map<String, Object?>>> _leer(TablaSync tabla, String idUsuario, {required bool todo}) {
    return _bd.rawQuery(
      'SELECT * FROM ${tabla.nombre} '
      'WHERE ${todo ? '' : 'pendiente_sync = 1 AND '}${tabla.dueno} '
      'ORDER BY actualizado_en',
      [idUsuario],
    );
  }

  Future<void> _subir(TablaSync tabla, List<Map<String, Object?>> lote) async {
    await _nube.from(tabla.nombre).upsert(
          [for (final fila in lote) aNube(tabla, fila)],
          onConflict: tabla.llaves.join(','),
        );
  }

  /// Pone pendiente_sync = 0 solo si la fila no cambió desde que se leyó.
  Future<void> _marcarSincronizadas(TablaSync tabla, List<Map<String, Object?>> lote) async {
    final donde = tabla.llaves.map((c) => '$c = ?').join(' AND ');
    final lotes = _bd.batch();
    for (final fila in lote) {
      lotes.rawUpdate(
        'UPDATE ${tabla.nombre} SET pendiente_sync = 0 WHERE $donde AND actualizado_en = ?',
        [for (final c in tabla.llaves) fila[c], fila['actualizado_en']],
      );
    }
    await lotes.commit(noResult: true);
  }

  /// Convierte una fila del celular al formato de Supabase: los 0/1 pasan a
  /// boolean y pendiente_sync siempre va en false (en la nube no se usa).
  @visibleForTesting
  static Map<String, Object?> aNube(TablaSync tabla, Map<String, Object?> fila) {
    final resultado = Map<String, Object?>.of(fila);
    for (final columna in ['eliminado', ...tabla.booleanas]) {
      final valor = resultado[columna];
      if (valor is num) resultado[columna] = valor != 0;
    }
    resultado['pendiente_sync'] = false;
    return resultado;
  }
}
