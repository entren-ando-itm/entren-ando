import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Modo de color de la app: claro, oscuro o el del sistema (hasta que el
/// usuario elija uno en Perfil → Ajustes → Tema). Se guarda en el celular.
///
///   final modo = ref.watch(modoTemaProvider);
///   ref.read(modoTemaProvider.notifier).cambiar(ThemeMode.dark);
final modoTemaProvider = NotifierProvider<ModoTema, ThemeMode>(ModoTema.new);

class ModoTema extends Notifier<ThemeMode> {
  static const String _llave = 'entren_ando_modo_tema';
  static final FlutterSecureStorage _almacen = FlutterSecureStorage();
  static ThemeMode _inicial = ThemeMode.system;

  /// Lee el modo guardado. Se llama una vez en main(), antes de abrir la app,
  /// para que no se vea un parpadeo de un modo al otro.
  static Future<void> cargar() async {
    try {
      final guardado = await _almacen.read(key: _llave).timeout(const Duration(seconds: 2));
      _inicial = _deTexto(guardado);
    } catch (_) {
      // Si no se puede leer, la app sigue el modo del sistema.
      _inicial = ThemeMode.system;
    }
  }

  @override
  ThemeMode build() => _inicial;

  Future<void> cambiar(ThemeMode modo) async {
    state = modo;
    _inicial = modo;
    try {
      await _almacen.write(key: _llave, value: modo.name);
    } catch (_) {
      // Si no se pudo guardar, el cambio dura hasta que se cierre la app.
    }
  }

  static ThemeMode _deTexto(String? texto) => switch (texto) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
}
