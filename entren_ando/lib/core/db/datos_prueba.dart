import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'script_sql.dart';

/// Datos de prueba (solo en modo debug).
///
/// Si la base no tiene al usuario demo, ejecuta datos_prueba.sql: perfil,
/// 2 mediciones, un ciclo activo de 4 días con alternativas, sesiones de los
/// últimos 45 días, 2 alias, 3 comidas de hoy y 1 feedback. Las fechas se
/// calculan a partir del día en que se crea la base. Para tener fechas
/// nuevas usa "Reiniciar datos de prueba" en la pestaña Perfil.
class DatosPrueba {
  DatosPrueba._();

  static const String idUsuarioDemo = '00000000-0000-0000-0000-000000000001';
  static const String correoDemo = 'demo@entrenando.test';

  static Future<void> cargarSiHaceFalta(Database bd) async {
    if (!kDebugMode) return;

    final filas = await bd.rawQuery(
      'SELECT COUNT(*) AS total FROM usuario WHERE id_usuario = ?',
      [idUsuarioDemo],
    );
    final total = filas.first['total'] as int? ?? 0;
    if (total > 0) return;

    final script = await rootBundle.loadString('lib/core/db/datos_prueba.sql');
    await bd.transaction((txn) async {
      for (final sentencia in ScriptSql.dividir(script)) {
        await txn.execute(sentencia);
      }
    });
    debugPrint('Entren-Ando: datos de prueba cargados para $correoDemo.');
  }
}
