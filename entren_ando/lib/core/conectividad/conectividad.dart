import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ¿Hay internet de verdad? (ENT-14, RNF-02)
///
/// `true` cuando hay red y además una petición real a internet respondió.
/// Tener Wi-Fi no siempre es tener internet (Wi-Fi sin datos o con página de
/// acceso, como en el gimnasio), por eso no basta con `connectivity_plus`.
///
/// Para leerlo en una pantalla:
///   final hayRed = ref.watch(hayRedProvider);
///
/// Evento "volvió la red" (lo usa la sincronización, ENT-44):
///   ref.listen(hayRedProvider, (antes, ahora) {
///     if (antes == false && ahora) subirPendientes();
///   });
final hayRedProvider = NotifierProvider<DetectorRed, bool>(DetectorRed.new);

class DetectorRed extends Notifier<bool> {
  /// Dirección que responde 204 sin contenido; es la que usa Android para
  /// saber si una red tiene internet. Es una petición muy ligera.
  static final Uri _urlPrueba = Uri.parse('https://connectivitycheck.gstatic.com/generate_204');
  static const Duration _tiempoMaximo = Duration(seconds: 5);

  /// Si hay red pero no internet, se vuelve a probar cada vez más espaciado
  /// (10 s, 20 s, 40 s y luego cada 60 s), nunca cada segundo, para no gastar
  /// batería.
  static const Duration _primerReintento = Duration(seconds: 10);
  static const Duration _reintentoMaximo = Duration(seconds: 60);

  final Connectivity _conectividad = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _cambios;
  AppLifecycleListener? _ciclo;
  Timer? _reintento;
  Duration _espera = _primerReintento;
  bool _activo = true;

  /// Cada revisión lleva un número; si llega la respuesta de una revisión
  /// vieja, se ignora.
  int _turno = 0;

  @override
  bool build() {
    _activo = true;
    _cambios =_conectividad.onConnectivityChanged.listen(_alCambiarRed);
    // Al volver a la app (estaba en segundo plano) se revisa otra vez.
    _ciclo = AppLifecycleListener(onResume: revisar);
    ref.onDispose(() {
      _activo = false;
      _cambios?.cancel();
      _ciclo?.dispose();
      _reintento?.cancel();
    });
    revisar();
    // Mientras llega la primera revisión se supone que hay red, para que el
    // aviso no aparezca un instante al abrir la app.
    return true;
  }

  /// Revisa ahora mismo. Se puede llamar desde un botón "Reintentar".
  Future<void> revisar() async {
    try {
      _alCambiarRed(await _conectividad.checkConnectivity());
    } catch (_) {
      // Si el celular no responde, se prueba directo con internet.
      _verificarInternet();
    }
  }

  void _alCambiarRed(List<ConnectivityResult> redes) {
    final sinRed = redes.isEmpty || redes.every((red) => red == ConnectivityResult.none);
    if (sinRed) {
      // Modo avión o sin Wi-Fi ni datos: no hace falta probar internet.
      _turno++;
      _reintento?.cancel();
      _espera = _primerReintento;
      _cambiar(false);
      return;
    }
    _verificarInternet();
  }

  Future<void> _verificarInternet() async {
    _reintento?.cancel();
    final turno = ++_turno;
    final hayInternet = await _respondeInternet();
    if (!_activo || turno != _turno) return;
    _cambiar(hayInternet);
    if (hayInternet) {
      _espera = _primerReintento;
    } else {
      _reintento = Timer(_espera, _verificarInternet);
      final siguiente = _espera * 2;
      _espera = siguiente > _reintentoMaximo ? _reintentoMaximo : siguiente;
    }
  }

  void _cambiar(bool hayRed) {
    if (_activo && state != hayRed) state = hayRed;
  }

  static Future<bool> _respondeInternet() async {
    final cliente = HttpClient()..connectionTimeout = _tiempoMaximo;
    try {
      final peticion = await cliente.getUrl(_urlPrueba).timeout(_tiempoMaximo);
      final respuesta = await peticion.close().timeout(_tiempoMaximo);
      await respuesta.drain<void>();
      // Una página de acceso (portal cautivo) responde 200 o redirige: eso
      // no es internet.
      return respuesta.statusCode == HttpStatus.noContent;
    } catch (_) {
      return false;
    } finally {
      cliente.close(force: true);
    }
  }
}
