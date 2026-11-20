import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Quién usa la app ahora (ENT-41).
class SesionActual {
  const SesionActual({required this.idUsuario, required this.correo, this.esDemo = false});

  /// El mismo id que en Supabase Auth (y en la tabla usuario).
  final String idUsuario;
  final String correo;

  /// true si se entró con "Entrar como demo" (solo en modo de prueba).
  final bool esDemo;
}

/// La sesión de la app. La llena `lib/features/cuenta` al iniciar sesión, al
/// registrarse, al entrar como demo o al abrir la app con una sesión guardada,
/// y la vacía al cerrar sesión. null = nadie ha iniciado sesión.
///
/// Es un ValueNotifier para que go_router mande al inicio de sesión cuando
/// cambia (lib/app.dart); en las pantallas se lee con [sesionActualProvider].
final ValueNotifier<SesionActual?> sesionActual = ValueNotifier<SesionActual?>(null);

/// La sesión para Riverpod: cambia cuando cambia [sesionActual].
class SesionNotifier extends Notifier<SesionActual?> {
  @override
  SesionActual? build() {
    void oir() => state = sesionActual.value;
    sesionActual.addListener(oir);
    ref.onDispose(() => sesionActual.removeListener(oir));
    return sesionActual.value;
  }
}

final sesionActualProvider = NotifierProvider<SesionNotifier, SesionActual?>(SesionNotifier.new);

/// id del usuario que usa la app, o null si nadie ha iniciado sesión.
///
/// Las pantallas y repositorios lo usan igual que antes: ahora devuelve el
/// usuario que inició sesión (ENT-41) en vez del demo fijo.
final usuarioActualIdProvider = Provider<String?>((ref) => ref.watch(sesionActualProvider)?.idUsuario);
