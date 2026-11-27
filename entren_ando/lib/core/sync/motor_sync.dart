import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../db/plan_local.dart';
import 'marcas_sync.dart';

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
  const ResultadoSync({
    this.subidas = 0,
    this.rechazadas = 0,
    this.descartadas = 0,
    this.bajadas = 0,
    this.errores = const [],
  });

  /// Filas que Supabase confirmó.
  final int subidas;

  /// Filas que Supabase rechazó (siguen pendientes y se reintentan después).
  final int rechazadas;

  /// Cambios a días de más de 30 días que la nube rechazó (RF-10): el celular
  /// los descartó y se quedó con la versión de la nube.
  final int descartadas;

  /// Filas que llegaron de la nube y se guardaron en el celular (ENT-53).
  final int bajadas;

  /// Mensajes de Supabase de las filas rechazadas, sin repetir.
  final List<String> errores;

  ResultadoSync conBajadas(int bajadas, List<String> masErrores) => ResultadoSync(
        subidas: subidas,
        rechazadas: rechazadas,
        descartadas: descartadas,
        bajadas: bajadas,
        errores: [...errores, ...masErrores],
      );
}

/// Sincroniza el celular con Supabase (ENT-44 y ENT-53, RNF-01).
///
/// [sincronizar] sube lo pendiente y luego baja lo que cambió en la nube.
///
/// Subir ([subirPendientes], ENT-44):
/// * Lee las filas con `pendiente_sync = 1` de cada tabla del usuario, en orden
///   de llaves foráneas (padres antes que hijos).
/// * Hace upsert por id en lotes de [tamanoLote]: si se corta la red a la mitad
///   y se reintenta, no se duplica nada.
/// * Cuando Supabase confirma, pone `pendiente_sync = 0` (es el único lugar de
///   la app que lo hace). Si la fila cambió mientras subía, se queda pendiente.
/// * Los borrados viajan como `eliminado = true`. Nunca borra filas locales.
/// * Solo sube las filas del usuario: las tablas hijas se filtran por su padre.
/// * Los catálogos no se suben. `suscripcion`, `solicitud_ia` y `evento_pago` los crea el
///   servidor (Edge Functions) y el celular guarda el mismo id; de
///   `feedback_ia` solo se sube `leido`.
/// * Si la nube rechaza un cambio por la regla de los 30 días (RF-10, código
///   EA010), el celular descarta su cambio y se queda con la versión de la nube.
///
/// Bajar ([bajarCambios], ENT-53):
/// * Por tabla, trae las filas con `actualizado_en` desde la última vez que se
///   bajó esa tabla (se guarda en [MarcasSync]). Celular nuevo: baja todo.
///   Una vez al día revisa todas, por los cambios que otro celular hizo sin
///   red y subió después con su hora vieja.
/// * Conflictos: si la fila tiene un cambio pendiente en el celular, gana el
///   `actualizado_en` más reciente. Si gana el celular, se sube la próxima vez.
///
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

  /// Lo que se baja: las tablas que se suben más las que crea el servidor
  /// (solicitudes de IA, feedback y pagos), también en orden de llaves foráneas.
  /// No hace falta filtrar por dueño: RLS solo entrega las del usuario.
  static const List<TablaSync> tablasBajar = [
    TablaSync('usuario', ['id_usuario']),
    TablaSync('perfil_entrenamiento', ['id_perfil']),
    TablaSync('medicion_biometrica', ['id_medicion']),
    TablaSync('usuario_equipo', ['id_usuario', 'id_equipo']),
    TablaSync('usuario_ejercicio', ['id_usuario', 'id_ejercicio']),
    TablaSync('suscripcion', ['id_suscripcion']),
    TablaSync('evento_pago', ['id_evento']),
    TablaSync('solicitud_ia', ['id_solicitud']),
    TablaSync('ciclo_rutina', ['id_ciclo']),
    TablaSync('dia_rutina', ['id_dia']),
    TablaSync('ejercicio_programado', ['id_programado']),
    TablaSync('alternativa_ejercicio', ['id_alternativa']),
    TablaSync('sesion_entrenamiento', ['id_sesion']),
    TablaSync('registro_ejercicio', ['id_registro']),
    TablaSync('serie', ['id_serie']),
    TablaSync('registro_comida', ['id_comida']),
    TablaSync('feedback_ia', ['id_feedback']),
  ];

  /// Código con el que la nube rechaza cambios a días de más de 30 días
  /// (`supabase/ajustes_ent53.sql`).
  static const String codigoRegla30Dias = 'EA010';

  /// Filas que se piden a Supabase por página (su máximo por consulta).
  static const int tamanoPagina = 1000;

  /// Cada cuánto se revisan todas las filas de la nube, no solo las nuevas.
  static const Duration revisionCompleta = Duration(hours: 24);

  /// Sube lo pendiente, baja lo nuevo de la nube y guarda la hora. Es lo que
  /// corre al abrir la app, al volver la red, con "Sincronizar ahora" y en
  /// segundo plano.
  Future<ResultadoSync> sincronizar(String idUsuario, MarcasSync marcas) async {
    final subida = await subirPendientes(idUsuario);
    final errores = <String>[];
    final bajadas = await bajarCambios(idUsuario, marcas, errores: errores);
    await marcas.guardarSincronizacion(idUsuario, DateTime.now());
    return subida.conBajadas(bajadas, errores);
  }

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
    var descartadas = 0;
    final errores = <String>{};

    /// Una fila que Supabase rechazó sola.
    Future<void> rechazo(TablaSync tabla, Map<String, Object?> fila, PostgrestException e) async {
      if (e.code == codigoRegla30Dias) {
        // RF-10: el día tiene más de 30 días. Se descarta el cambio del celular.
        descartadas++;
        await _quedarseConLaNube(tabla, fila);
      } else {
        rechazadas++;
        errores.add('${tabla.nombre}: ${e.message}');
      }
    }

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
            await rechazo(tabla, lote.first, e);
            continue;
          }
          for (final fila in lote) {
            try {
              await _subir(tabla, [fila]);
              await _marcarSincronizadas(tabla, [fila]);
              subidas++;
            } on PostgrestException catch (e) {
              await rechazo(tabla, fila, e);
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
    return ResultadoSync(
      subidas: subidas,
      rechazadas: rechazadas,
      descartadas: descartadas,
      errores: errores.toList(),
    );
  }

  /// Baja de Supabase lo que cambió desde la última vez (ENT-53) y devuelve
  /// cuántas filas cambiaron en el celular. Los problemas de filas sueltas se
  /// agregan a [errores]; si se pierde la conexión, lanza la excepción.
  Future<int> bajarCambios(String idUsuario, MarcasSync marcas, {List<String>? errores}) async {
    // Una vez al día se revisa todo: un cambio de otro celular que estuvo sin
    // red llega con su hora vieja (anterior a la marca) y si no, se perdería.
    final ultimaCompleta = marcas.ultimaRevisionCompleta(idUsuario);
    final completa = ultimaCompleta == null || DateTime.now().difference(ultimaCompleta) > revisionCompleta;
    var bajadas = 0;
    for (final tabla in tablasBajar) {
      final desde = completa ? null : marcas.ultimaBajada(idUsuario, tabla.nombre);
      String? masReciente = desde;
      for (var inicio = 0;; inicio += tamanoPagina) {
        var consulta = _nube.from(tabla.nombre).select();
        // gte y no gt: si dos filas tienen la misma hora no se pierde ninguna;
        // las que ya estaban se reconocen y no se vuelven a escribir.
        // La única fila de la cuenta trae el plan incluso si la subida de una
        // edición sin red acaba de devolver actualizado_en a una fecha anterior.
        if (desde != null && tabla.nombre != 'usuario') {
          consulta = consulta.gte('actualizado_en', desde);
        }
        var ordenada = consulta.order('actualizado_en', ascending: true);
        for (final llave in tabla.llaves) {
          ordenada = ordenada.order(llave, ascending: true);
        }
        final filas = await ordenada.range(inicio, inicio + tamanoPagina - 1);
        for (final fila in filas) {
          try {
            if (await _guardarDeNube(tabla, fila)) bajadas++;
          } on DatabaseException catch (e) {
            errores?.add('${tabla.nombre} (bajar): $e');
          }
          masReciente = _masReciente(masReciente, fila['actualizado_en'] as String?);
        }
        if (filas.length < tamanoPagina) break;
      }
      final anterior = marcas.ultimaBajada(idUsuario, tabla.nombre);
      final nueva = _masReciente(anterior, masReciente);
      if (nueva != null && nueva != anterior) {
        await marcas.guardarBajada(idUsuario, tabla.nombre, nueva);
      }
    }
    if (completa) await marcas.guardarRevisionCompleta(idUsuario, DateTime.now());
    // ENT-52: si el plan bajó a Gratuito (cancelación o vencimiento en el
    // servidor), archiva los ciclos que sobran.
    await PlanLocal.revisarVencimiento(_bd, idUsuario);
    bajadas += await PlanLocal.ajustarCiclosAlPlan(_bd, idUsuario);
    return bajadas;
  }

  /// Cuántas filas del usuario faltan por subir (para mostrarlo en pantalla).
  Future<int> contarPendientes(String idUsuario) => contarPendientesEn(_bd, idUsuario);

  /// Igual que [contarPendientes], sin necesitar la conexión con Supabase
  /// (el indicador de ENT-54 lo muestra aunque no haya red ni llaves).
  static Future<int> contarPendientesEn(DatabaseExecutor bd, String idUsuario) async {
    var total = 0;
    for (final tabla in [...tablas, const TablaSync('feedback_ia', ['id_feedback'])]) {
      final filas = await bd.rawQuery(
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

  /// RF-10: la nube rechazó el cambio. Se trae su versión y se guarda en el
  /// celular encima del cambio; si la nube no la tiene, se deja de intentar.
  Future<void> _quedarseConLaNube(TablaSync tabla, Map<String, Object?> fila) async {
    var consulta = _nube.from(tabla.nombre).select();
    for (final llave in tabla.llaves) {
      consulta = consulta.eq(llave, fila[llave] as Object);
    }
    final enNube = await consulta.maybeSingle();
    if (enNube != null) {
      await _guardarDeNube(tabla, enNube, forzar: true);
    } else {
      await _bd.rawUpdate(
        'UPDATE ${tabla.nombre} SET pendiente_sync = 0 WHERE ${tabla.llaves.map((c) => '$c = ?').join(' AND ')}',
        [for (final c in tabla.llaves) fila[c]],
      );
    }
  }

  /// Guarda en el celular una fila que llegó de la nube. Devuelve true si
  /// cambió algo. Si el celular tiene un cambio pendiente más reciente, gana el
  /// celular y no se toca (con [forzar] siempre gana la nube).
  Future<bool> _guardarDeNube(TablaSync tabla, Map<String, dynamic> enNube, {bool forzar = false}) async {
    final donde = tabla.llaves.map((c) => '$c = ?').join(' AND ');
    final llaves = [for (final c in tabla.llaves) enNube[c]];
    final local = await _bd.rawQuery(
      'SELECT actualizado_en, pendiente_sync FROM ${tabla.nombre} WHERE $donde',
      llaves,
    );
    if (local.isNotEmpty && !forzar) {
      final enCelular = DateTime.tryParse('${local.first['actualizado_en']}');
      final deNube = DateTime.tryParse('${enNube['actualizado_en']}');
      if (enCelular != null && deNube != null) {
        final pendiente = local.first['pendiente_sync'] == 1;
        // Gana el más reciente: el cambio del celular se sube la próxima vez.
        final conservarLocal = pendiente && enCelular.isAfter(deNube);
        // Ya la tenía igual (por ejemplo, la acaba de subir este celular).
        if (conservarLocal || (!pendiente && enCelular.isAtSameMomentAs(deNube))) {
          if (tabla.nombre != 'usuario') return false;
          final cambios = await aplicarPlanConfirmado(_bd, enNube['id_usuario'] as String, enNube['id_plan'] as int);
          return cambios > 0;
        }
      }
    }
    final fila = aLocal(enNube, await _columnas(tabla.nombre));
    final columnas = fila.keys.toList();
    final cambiar = columnas.where((c) => !tabla.llaves.contains(c)).map((c) => '$c = excluded.$c').join(', ');
    // ON CONFLICT ... DO UPDATE (no REPLACE): REPLACE borra y vuelve a insertar,
    // y eso dispararía los ON DELETE CASCADE de las tablas hijas.
    await _bd.rawInsert(
      'INSERT INTO ${tabla.nombre} (${columnas.join(', ')}) '
      'VALUES (${List.filled(columnas.length, '?').join(', ')}) '
      'ON CONFLICT (${tabla.llaves.join(', ')}) DO UPDATE SET $cambiar',
      [for (final c in columnas) fila[c]],
    );
    return true;
  }

  final Map<String, Set<String>> _columnasPorTabla = {};

  /// Copia un plan confirmado por el servidor sin alterar cambios pendientes del perfil.
  static Future<int> aplicarPlanConfirmado(DatabaseExecutor bd, String usuario, int plan) =>
      bd.rawUpdate('UPDATE usuario SET id_plan = ? WHERE id_usuario = ? AND id_plan <> ?',
          [plan, usuario, plan]);

  Future<Set<String>> _columnas(String tabla) async {
    final conocidas = _columnasPorTabla[tabla];
    if (conocidas != null) return conocidas;
    final info = await _bd.rawQuery('PRAGMA table_info($tabla)');
    return _columnasPorTabla[tabla] = {for (final c in info) c['name'] as String};
  }

  static String? _masReciente(String? a, String? b) {
    if (a == null) return b;
    if (b == null) return a;
    final fechaA = DateTime.tryParse(a);
    final fechaB = DateTime.tryParse(b);
    if (fechaA == null || fechaB == null) return b;
    return fechaB.isAfter(fechaA) ? b : a;
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
    if (tabla.nombre == 'usuario') resultado.remove('id_plan');
    for (final columna in ['eliminado', ...tabla.booleanas]) {
      final valor = resultado[columna];
      if (valor is num) resultado[columna] = valor != 0;
    }
    resultado['pendiente_sync'] = false;
    return resultado;
  }

  /// Convierte una fila de Supabase al formato del celular: boolean a 0/1,
  /// JSON a texto, sin columnas que el celular no tenga, y pendiente_sync = 0
  /// (lo que viene de la nube ya está respaldado).
  @visibleForTesting
  static Map<String, Object?> aLocal(Map<String, dynamic> enNube, Set<String> columnasLocales) {
    final fila = <String, Object?>{};
    enNube.forEach((columna, valor) {
      if (!columnasLocales.contains(columna)) return;
      fila[columna] = switch (valor) {
        bool b => b ? 1 : 0,
        Map() || List() => jsonEncode(valor),
        _ => valor,
      };
    });
    fila['pendiente_sync'] = 0;
    return fila;
  }
}
