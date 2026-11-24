import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../../features/nube/cliente_supabase.dart';
import '../db/base_datos.dart';
import 'marcas_sync.dart';
import 'motor_sync.dart';

/// Sincronización en segundo plano (ENT-97, historia ENT-53).
///
/// Android (WorkManager) corre [despachadorSegundoPlano] cada 15 minutos cuando
/// hay red, aunque la app esté cerrada. Sube lo pendiente y baja lo nuevo con
/// el mismo [MotorSync] de la app. Se programa una vez en `main.dart` con
/// [SegundoPlano.programar].
class SegundoPlano {
  SegundoPlano._();

  static const String nombreTarea = 'entren-ando-sincronizar';

  /// 15 minutos es lo mínimo que permite Android para una tarea periódica.
  static const Duration cada = Duration(minutes: 15);

  /// Programa la tarea. Si ya estaba programada, la deja como estaba (`keep`).
  static Future<void> programar() async {
    if (!ClienteSupabase.configurado) return;
    try {
      await Workmanager().initialize(despachadorSegundoPlano);
      await Workmanager().registerPeriodicTask(
        nombreTarea,
        nombreTarea,
        frequency: cada,
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } catch (e) {
      // Sin segundo plano la app sigue sincronizando al abrirla y al volver la red.
      debugPrint('Entren-Ando: no se pudo programar la sincronización en segundo plano: $e');
    }
  }

  /// Lo que hace la tarea. Devuelve true si terminó (o no había nada que
  /// hacer) y false si falló la conexión, para que Android la reintente.
  static Future<bool> sincronizar() async {
    WidgetsFlutterBinding.ensureInitialized();
    await ClienteSupabase.iniciar(segundoPlano: true);
    final cliente = ClienteSupabase.cliente;
    // Sin llaves o sin sesión: no hay a quién respaldar.
    final sesion = cliente?.auth.currentSession;
    if (cliente == null || sesion == null) return true;
    try {
      final bd = await BaseDatos.instancia();
      final resultado = await MotorSync(bd, cliente).sincronizar(sesion.user.id, await MarcasSync.abrir());
      debugPrint(
        'Entren-Ando (segundo plano): ${resultado.subidas} subidas, ${resultado.bajadas} bajadas, '
        '${resultado.rechazadas} rechazadas',
      );
      return true;
    } catch (e) {
      debugPrint('Entren-Ando (segundo plano): $e');
      return false;
    }
  }
}

/// Punto de entrada de Android para la tarea. Tiene que ser una función de
/// primer nivel con `vm:entry-point` para que no se elimine al compilar.
@pragma('vm:entry-point')
void despachadorSegundoPlano() {
  Workmanager().executeTask((tarea, datos) => SegundoPlano.sincronizar());
}
