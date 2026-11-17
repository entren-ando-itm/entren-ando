import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Conexión con Supabase (ENT-44).
///
/// Las llaves NO van en el código: se leen del archivo `entren_ando/.env`, que
/// no se sube a GitHub (copia `.env.example` y llénalo). Se corre así:
///
///   flutter run --dart-define-from-file=.env
///
/// Sin ese archivo la app funciona igual, pero sin respaldo en la nube.
class ClienteSupabase {
  ClienteSupabase._();

  static const String _url = String.fromEnvironment('SUPABASE_URL');
  static const String _llavePublica = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Solo modo de prueba: contraseña del usuario demo en Supabase, para probar
  /// la sincronización antes del inicio de sesión de ENT-41.
  static const String contrasenaDemo = String.fromEnvironment('DEMO_PASSWORD');

  static bool _listo = false;

  /// true si hay llaves y Supabase arrancó.
  static bool get configurado => _listo;

  /// El cliente, o null si no está configurado.
  static SupabaseClient? get cliente => _listo ? Supabase.instance.client : null;

  /// Se llama una vez en `main.dart`, antes de `runApp`.
  static Future<void> iniciar() async {
    if (_url.isEmpty || _llavePublica.isEmpty) {
      debugPrint(
        'Entren-Ando: faltan SUPABASE_URL y SUPABASE_ANON_KEY; la sincronización '
        'queda apagada. Corre con: flutter run --dart-define-from-file=.env',
      );
      return;
    }
    try {
      await Supabase.initialize(url: _url, anonKey: _llavePublica);
      _listo = true;
    } catch (e) {
      debugPrint('Entren-Ando: no se pudo iniciar Supabase: $e');
    }
  }
}
