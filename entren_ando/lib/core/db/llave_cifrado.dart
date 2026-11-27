import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Llave de cifrado de la base local.
///
/// Se genera una sola vez al azar (32 bytes) y se guarda en el Keystore de
/// Android con flutter_secure_storage. Nunca se escribe en el código, en
/// archivos ni en la consola.
class LlaveCifrado {
  LlaveCifrado._();

  static const String _nombre = 'entren_ando_llave_bd';
  static final FlutterSecureStorage _almacen = FlutterSecureStorage();

  static Future<String> obtener() async {
    final guardada = await _almacen.read(key: _nombre);
    if (guardada != null && guardada.isNotEmpty) return guardada;

    final azar = Random.secure();
    final bytes = List<int>.generate(32, (_) => azar.nextInt(256));
    final nueva = base64Url.encode(bytes);
    await _almacen.write(key: _nombre, value: nueva);
    return nueva;
  }

  /// Borra la llave del Keystore (ENT-51, eliminar cuenta). La siguiente vez
  /// que se abra la base se genera una llave nueva.
  static Future<void> borrar() => _almacen.delete(key: _nombre);
}
