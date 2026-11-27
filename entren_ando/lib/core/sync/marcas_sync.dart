import 'package:shared_preferences/shared_preferences.dart';

/// Hasta dónde se sincronizó cada tabla (ENT-53).
///
/// Se guarda en shared_preferences porque no es un dato personal: solo fechas.
/// Va por usuario, para que dos cuentas en el mismo celular no se mezclen.
class MarcasSync {
  MarcasSync(this._prefs);

  final SharedPreferences _prefs;

  /// Abre las marcas y lee lo último que guardó la sincronización en segundo
  /// plano (corre en otro isolate y escribe su propia copia).
  static Future<MarcasSync> abrir() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return MarcasSync(prefs);
  }

  static String _llave(String idUsuario, String cosa) => 'entren_ando.sync.$idUsuario.$cosa';

  /// El `actualizado_en` más reciente que ya se bajó de [tabla], o null si
  /// nunca se ha bajado (celular nuevo: se baja todo).
  String? ultimaBajada(String idUsuario, String tabla) => _prefs.getString(_llave(idUsuario, 'bajada.$tabla'));

  Future<void> guardarBajada(String idUsuario, String tabla, String actualizadoEn) =>
      _prefs.setString(_llave(idUsuario, 'bajada.$tabla'), actualizadoEn);

  /// Cuándo se revisaron por última vez TODAS las filas de la nube (no solo las
  /// nuevas). Sirve para no perder cambios de otro celular que estuvo sin red
  /// y los subió con su hora vieja.
  DateTime? ultimaRevisionCompleta(String idUsuario) {
    final texto = _prefs.getString(_llave(idUsuario, 'completa'));
    return texto == null ? null : DateTime.tryParse(texto);
  }

  Future<void> guardarRevisionCompleta(String idUsuario, DateTime cuando) =>
      _prefs.setString(_llave(idUsuario, 'completa'), cuando.toUtc().toIso8601String());

  /// Cuándo terminó la última sincronización completa (subir y bajar).
  DateTime? ultimaSincronizacion(String idUsuario) {
    final texto = _prefs.getString(_llave(idUsuario, 'ultima'));
    return texto == null ? null : DateTime.tryParse(texto)?.toLocal();
  }

  /// Borra todas las marcas de [idUsuario] (ENT-51, al eliminar la cuenta).
  Future<void> borrarUsuario(String idUsuario) async {
    final prefijo = _llave(idUsuario, '');
    for (final llave in _prefs.getKeys().where((k) => k.startsWith(prefijo)).toList()) {
      await _prefs.remove(llave);
    }
  }

  Future<void> guardarSincronizacion(String idUsuario, DateTime cuando) =>
      _prefs.setString(_llave(idUsuario, 'ultima'), cuando.toUtc().toIso8601String());
}
