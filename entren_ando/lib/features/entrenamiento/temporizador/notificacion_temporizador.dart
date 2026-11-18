import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

/// Notificación local con sonido y vibración cuando termina el temporizador
/// (ENT-19 / ENT-38, RF-06).
///
/// Se programa a la **hora de fin**, así suena aunque la pantalla esté bloqueada
/// o la app en segundo plano. No necesita internet (RNF-01).
///
/// Permisos de Android que usa (están en `android/app/src/main/AndroidManifest.xml`):
/// * `POST_NOTIFICATIONS`: mostrar notificaciones; en Android 13 o más se pide al usuario.
/// * `SCHEDULE_EXACT_ALARM`: que suene en el segundo exacto y no minutos después.
///   En Android 14 o más viene apagado: la tarjeta del temporizador muestra un
///   aviso con "Activar" y el usuario decide; si no lo activa, la notificación
///   se programa "aproximada" (puede llegar unos segundos tarde).
/// * `VIBRATE`: vibrar.
/// * `RECEIVE_BOOT_COMPLETED`: lo pide el paquete para reprogramar tras reiniciar el celular.
final notificacionTemporizadorProvider =
    Provider<NotificacionTemporizador>((ref) => NotificacionTemporizador());

class NotificacionTemporizador {
  NotificacionTemporizador({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Siempre la misma: solo hay un temporizador a la vez.
  static const int _id = 19;

  /// Canal de Android con sonido y vibración. El id no se cambia: Android guarda
  /// la configuración del canal la primera vez que se crea.
  static const AndroidNotificationDetails _canal = AndroidNotificationDetails(
    'temporizador_entrenamiento',
    'Temporizador de entrenamiento',
    channelDescription: 'Avisa cuando termina el descanso o el trabajo',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    category: AndroidNotificationCategory.alarm,
    visibility: NotificationVisibility.public,
  );

  bool _listo = false;
  bool _puedeExacta = false;

  /// Las órdenes (programar / cancelar) se hacen una tras otra, en el orden en
  /// que llegan. Así, si se pausa o se salta justo al empezar, el "cancelar"
  /// nunca se adelanta al "programar" y el aviso no suena de más.
  Future<void> _cola = Future<void>.value();

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  Future<void> _enCola(Future<void> Function() orden) {
    final siguiente = _cola.then((_) => orden()).catchError((Object error) {
      // El temporizador en pantalla sigue funcionando aunque falle el aviso.
      debugPrint('Aviso del temporizador: $error');
    });
    _cola = siguiente;
    return siguiente;
  }

  /// Prepara el paquete y pide el permiso de notificaciones la primera vez.
  ///
  /// El permiso de alarmas exactas ya **no** se pide solo: la tarjeta del
  /// temporizador muestra un aviso con "Activar" (ver [pedirAlarmasExactas]).
  Future<void> _preparar() async {
    if (_listo) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    final android = _android;
    if (android != null) {
      await android.requestNotificationsPermission();
      _puedeExacta = await android.canScheduleExactNotifications() ?? false;
    }
    _listo = true;
  }

  /// true si el aviso puede sonar en el segundo exacto (Android 14+ lo pide aparte).
  Future<bool> puedeSonarExacto() async {
    try {
      await _cola;
      await _preparar();
      final android = _android;
      if (android == null) return true;
      _puedeExacta = await android.canScheduleExactNotifications() ?? false;
      return _puedeExacta;
    } catch (_) {
      return true; // Si no se puede saber, no molestamos al usuario.
    }
  }

  /// Abre Ajustes → "Alarmas y recordatorios". Solo cuando el usuario toca "Activar".
  Future<void> pedirAlarmasExactas() async {
    try {
      await _preparar();
      await _android?.requestExactAlarmsPermission();
      _puedeExacta = await _android?.canScheduleExactNotifications() ?? _puedeExacta;
    } catch (error) {
      debugPrint('No se pudo pedir el permiso de alarmas exactas: $error');
    }
  }

  /// Programa (o reprograma) el aviso para la hora [fin].
  Future<void> programar({required DateTime fin, required String titulo}) {
    return _enCola(() async {
      await _preparar();
      await _plugin.cancel(id: _id);
      if (!fin.isAfter(DateTime.now())) return;
      await _plugin.zonedSchedule(
        id: _id,
        title: '¡Tiempo!',
        body: '$titulo terminó',
        // La hora de fin es un instante exacto: en UTC no hace falta la base de
        // zonas horarias ni saber la zona del celular.
        scheduledDate: tz.TZDateTime.from(fin.toUtc(), tz.UTC),
        notificationDetails: const NotificationDetails(android: _canal),
        androidScheduleMode: _puedeExacta
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    });
  }

  /// Quita el aviso pendiente ("Saltar", pausa o temporizador cerrado).
  /// Espera a que termine lo anterior (por ejemplo, la preparación).
  Future<void> cancelar() {
    return _enCola(() async {
      if (!_listo) return;
      await _plugin.cancel(id: _id);
    });
  }
}

/// ¿Puede sonar en el segundo exacto? La tarjeta lo usa para mostrar el aviso.
final alarmasExactasProvider = FutureProvider<bool>((ref) {
  return ref.watch(notificacionTemporizadorProvider).puedeSonarExacto();
});
