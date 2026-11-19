import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/nube/cliente_supabase.dart';
import '../conectividad/conectividad.dart';
import '../db/base_datos.dart';
import '../db/usuario_actual.dart';
import 'motor_sync.dart';

enum FaseSync {
  /// Faltan las llaves de Supabase (.env).
  apagada,

  /// No hay sesión de Supabase del usuario de la app.
  sinSesion,

  /// Sin internet: se intenta cuando vuelva la red.
  sinRed,

  subiendo,

  /// Todo arriba (o se subió lo que se pudo).
  lista,

  error,
}

/// Estado de la sincronización, para mostrarlo en pantalla (ENT-54).
class EstadoSync {
  const EstadoSync({
    this.fase = FaseSync.sinSesion,
    this.mensaje,
    this.ultimaVez,
    this.subidas = 0,
    this.rechazadas = 0,
  });

  final FaseSync fase;
  final String? mensaje;

  /// Cuándo terminó la última sincronización sin errores de conexión.
  final DateTime? ultimaVez;

  /// Filas subidas y rechazadas en la última sincronización.
  final int subidas;
  final int rechazadas;
}

/// Sincronización automática (ENT-44, subtarea ENT-80).
///
/// Sube los pendientes:
/// * al abrir la app,
/// * cuando `hayRedProvider` pasa de false a true (volvió la red),
/// * cuando el usuario inicia sesión en Supabase,
/// * y cuando se llama a mano: `ref.read(sincronizacionProvider.notifier).sincronizar()`.
///
/// Se activa con [SincronizacionAutomatica], que ya está en `lib/app.dart`.
final sincronizacionProvider = NotifierProvider<Sincronizacion, EstadoSync>(Sincronizacion.new);

class Sincronizacion extends Notifier<EstadoSync> {
  StreamSubscription<AuthState>? _sesion;
  bool _activo = true;
  bool _corriendo = false;
  bool _otraVez = false;

  @override
  EstadoSync build() {
    _activo = true;
    final cliente = ClienteSupabase.cliente;
    if (cliente == null) {
      return const EstadoSync(
        fase: FaseSync.apagada,
        mensaje: 'Falta configurar Supabase (archivo .env).',
      );
    }

    ref.listen<bool>(hayRedProvider, (antes, ahora) {
      if (ahora && antes == false) sincronizar();
      if (!ahora) _poner(const EstadoSync(fase: FaseSync.sinRed, mensaje: 'Sin conexión: se sube al volver la red.'));
    });
    _sesion = cliente.auth.onAuthStateChange.listen((cambio) {
      if (cambio.event == AuthChangeEvent.signedIn) sincronizar();
      if (cambio.event == AuthChangeEvent.signedOut) {
        _poner(const EstadoSync(fase: FaseSync.sinSesion, mensaje: 'Sin sesión en la nube.'));
      }
    });
    ref.onDispose(() {
      _activo = false;
      _sesion?.cancel();
    });

    // Al abrir la app.
    Future.microtask(sincronizar);
    return const EstadoSync(fase: FaseSync.subiendo);
  }

  /// Sube los pendientes ahora. Con [todo] sube también lo que ya estaba
  /// sincronizado (los datos de prueba).
  Future<void> sincronizar({bool todo = false}) async {
    final cliente = ClienteSupabase.cliente;
    if (cliente == null || !_activo) return;
    if (_corriendo) {
      _otraVez = true;
      return;
    }

    final idUsuario = ref.read(usuarioActualIdProvider);
    final sesion = cliente.auth.currentSession;
    if (idUsuario == null || sesion == null) {
      _poner(const EstadoSync(fase: FaseSync.sinSesion, mensaje: 'Inicia sesión para respaldar tus datos.'));
      return;
    }
    if (sesion.user.id != idUsuario) {
      _poner(EstadoSync(
        fase: FaseSync.error,
        mensaje: 'La sesión de la nube (${sesion.user.email}) no es la del usuario de la app.',
      ));
      return;
    }
    if (!ref.read(hayRedProvider)) {
      _poner(const EstadoSync(fase: FaseSync.sinRed, mensaje: 'Sin conexión: se sube al volver la red.'));
      return;
    }

    _corriendo = true;
    _poner(EstadoSync(fase: FaseSync.subiendo, ultimaVez: state.ultimaVez));
    try {
      final bd = await ref.read(baseDatosProvider.future);
      final resultado = await MotorSync(bd, cliente).subirPendientes(idUsuario, todo: todo);
      _poner(EstadoSync(
        fase: FaseSync.lista,
        ultimaVez: DateTime.now(),
        subidas: resultado.subidas,
        rechazadas: resultado.rechazadas,
        mensaje: resultado.rechazadas == 0
            ? null
            : 'Supabase rechazó ${resultado.rechazadas} '
                '${resultado.rechazadas == 1 ? 'fila' : 'filas'}: ${resultado.errores.first}',
      ));
    } catch (e) {
      debugPrint('Entren-Ando sync: $e');
      _poner(EstadoSync(
        fase: FaseSync.error,
        ultimaVez: state.ultimaVez,
        mensaje: 'No se pudo conectar con la nube. Se reintenta al volver la red.',
      ));
    } finally {
      _corriendo = false;
      if (_otraVez) {
        _otraVez = false;
        unawaited(sincronizar());
      }
    }
  }

  void _poner(EstadoSync nuevo) {
    if (_activo) state = nuevo;
  }
}

/// Enciende la sincronización automática. Se pone una sola vez en
/// `lib/app.dart`, envolviendo a todas las pantallas.
class SincronizacionAutomatica extends ConsumerWidget {
  const SincronizacionAutomatica({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Solo la mantiene viva; las pantallas no se redibujan porque [child] es
    // el mismo widget.
    ref.watch(sincronizacionProvider);
    return child;
  }
}
