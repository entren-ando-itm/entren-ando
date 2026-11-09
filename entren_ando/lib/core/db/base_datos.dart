import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'datos_prueba.dart';
import 'llave_cifrado.dart';
import 'script_sql.dart';

/// Base de datos local cifrada con SQLCipher (AES-256).
///
/// Úsala siempre con `ref.watch(baseDatosProvider.future)`. No abras otra
/// conexión y no uses el paquete sqflite normal (sin cifrado), ni para probar.
class BaseDatos {
  BaseDatos._();

  static const String nombreArchivo = 'entren_ando.db';

  /// Versión del esquema. Súbela solo si cambia esquema.sql (con acuerdo
  /// del equipo) y agrega el cambio en [_migrar].
  static const int version = 1;

  static Database? _bd;
  static Future<Database>? _abriendo;

  /// La conexión única de la app.
  static Future<Database> instancia() {
    final abierta = _bd;
    if (abierta != null && abierta.isOpen) return Future.value(abierta);
    return _abriendo ??= _abrir().then((bd) {
      _bd = bd;
      return bd;
    }).whenComplete(() {
      _abriendo = null;
    });
  }

  /// Ruta del archivo en el celular:
  /// /data/data/mx.entrenando.app/databases/entren_ando.db
  static Future<String> ruta() async =>
      '${await getDatabasesPath()}/$nombreArchivo';

  static Future<Database> _abrir() async {
    final llave = await LlaveCifrado.obtener();
    final ruta = await BaseDatos.ruta();
    try {
      return await _abrirCon(ruta, llave);
    } catch (error) {
      // En modo debug, si la base quedó con otra llave (por ejemplo, porque
      // se borró solo una parte de los datos de la app), se borra y se crea
      // de nuevo. En la app final nunca se borra sola: se muestra el error.
      if (!kDebugMode) rethrow;
      debugPrint('Entren-Ando: no se pudo abrir la base ($error). Se crea de nuevo.');
      await deleteDatabase(ruta);
      return _abrirCon(ruta, llave);
    }
  }

  static Future<Database> _abrirCon(String ruta, String llave) async {
    final bd = await openDatabase(
      ruta,
      password: llave,
      version: version,
      onConfigure: (bd) => bd.execute('PRAGMA foreign_keys = ON'),
      onCreate: (bd, version) async {
        await ejecutarScript(bd, 'lib/core/db/esquema.sql');
        // El catálogo (planes, equipo y ejercicios) se carga siempre,
        // también en la app final.
        await ejecutarScript(bd, 'lib/core/db/catalogo_semilla.sql');
      },
      onUpgrade: _migrar,
    );
    if (kDebugMode) await DatosPrueba.cargarSiHaceFalta(bd);
    return bd;
  }

  static Future<void> _migrar(Database bd, int anterior, int nueva) async {
    // Aún no hay migraciones: la versión 1 es la primera.
  }

  /// Ejecuta un archivo .sql de los assets, sentencia por sentencia.
  static Future<void> ejecutarScript(DatabaseExecutor bd, String asset) async {
    final script = await rootBundle.loadString(asset);
    for (final sentencia in ScriptSql.dividir(script)) {
      await bd.execute(sentencia);
    }
  }

  /// Solo en debug: borra la base. La siguiente lectura la crea de nuevo
  /// con el catálogo y los datos de prueba (con fechas de hoy).
  static Future<void> reiniciarDatosPrueba() async {
    if (!kDebugMode) return;
    await _bd?.close();
    _bd = null;
    await deleteDatabase(await ruta());
  }
}

/// Conexión a la base local para todos los módulos.
final baseDatosProvider = FutureProvider<Database>((ref) => BaseDatos.instancia());
