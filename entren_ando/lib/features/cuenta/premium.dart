import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/db/base_datos.dart';
import '../../core/db/plan_local.dart';
import '../../core/db/usuario_actual.dart';
import '../../core/sync/motor_sync.dart';
import '../nube/cliente_supabase.dart';

typedef PlanPremium = ({int? ciclos, int? escaneos, String frecuencia, num precio});
typedef ComparacionPlanes = ({PlanPremium gratuito, PlanPremium premium, bool activo});

final comparacionPlanesProvider = FutureProvider<ComparacionPlanes>((ref) async {
  final usuario = ref.watch(usuarioActualIdProvider);
  final bd = await ref.watch(baseDatosProvider.future);
  final filas = await bd.rawQuery(
    'SELECT p.*, u.id_plan AS plan_actual FROM plan p CROSS JOIN usuario u '
    'WHERE u.id_usuario = ? AND u.eliminado = 0 AND p.id_plan IN (1, 2) ORDER BY p.id_plan',
    [usuario],
  );
  PlanPremium leer(Map<String, Object?> fila) => (
    ciclos: fila['max_ciclos_activos'] as int?,
    escaneos: fila['max_escaneos_dia'] as int?,
    frecuencia: fila['frecuencia_feedback'] as String,
    precio: fila['precio'] as num,
  );
  if (filas.length != 2) throw StateError('Falta la cuenta o el catálogo local.');
  return (gratuito: leer(filas.first), premium: leer(filas.last), activo: filas.first['plan_actual'] == 2);
});

class ErrorPremium implements Exception {
  const ErrorPremium(this.mensaje);
  final String mensaje;
}

/// Llama a la función `premium-prueba` del servidor (compra simulada, ENT-52)
/// y devuelve su respuesta. [accion] es 'activar' o 'cancelar'.
Future<Map<Object?, Object?>> _llamarPremium(Ref ref, String accion) async {
  final cliente = ClienteSupabase.cliente;
  final usuario = ref.read(usuarioActualIdProvider);
  final sesion = cliente?.auth.currentSession;
  final verbo = accion == 'cancelar' ? 'cancelar' : 'activar';
  if (cliente == null || sesion == null || usuario == null || sesion.user.id != usuario) {
    throw ErrorPremium('Inicia sesión en la nube con esta cuenta para $verbo Premium.');
  }
  try {
    final respuesta = await cliente.functions.invoke(
      'premium-prueba',
      headers: {'Authorization': 'Bearer ${sesion.accessToken}'},
      body: {'accion': accion},
    );
    final datos = respuesta.data;
    if (respuesta.status != 200 || datos is! Map) {
      throw const ErrorPremium('No se pudo confirmar el plan. Intenta de nuevo.');
    }
    return datos;
  } on FunctionException catch (e) {
    throw ErrorPremium(switch (e.status) {
      401 => 'Vuelve a iniciar sesión para $verbo Premium.',
      403 => 'La compra de prueba está desactivada en el servidor.',
      409 => 'Sincroniza tu cuenta desde Respaldo en la nube y vuelve a intentarlo.',
      _ => 'No se pudo $verbo Premium. Intenta de nuevo.',
    });
  }
}

/// Activa la prueba de Premium de 30 días (compra simulada, sin cobro).
final activarPremiumProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    final datos = await _llamarPremium(ref, 'activar');
    if (datos['id_plan'] != 2) throw const ErrorPremium('No se pudo confirmar el plan. Intenta de nuevo.');
    final usuario = ref.read(usuarioActualIdProvider)!;
    final bd = await ref.read(baseDatosProvider.future);
    await MotorSync.aplicarPlanConfirmado(bd, usuario, 2);
    ref.invalidate(baseDatosProvider);
  },
);

/// Cancela Premium de inmediato (ENT-95): vuelve a Gratuito y archiva los
/// ciclos que sobran, conservando el más reciente.
final cancelarPremiumProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    final datos = await _llamarPremium(ref, 'cancelar');
    if (datos['id_plan'] != 1) throw const ErrorPremium('No se pudo confirmar el plan. Intenta de nuevo.');
    final usuario = ref.read(usuarioActualIdProvider)!;
    final bd = await ref.read(baseDatosProvider.future);
    await bd.transaction((txn) async {
      await MotorSync.aplicarPlanConfirmado(txn, usuario, 1);
      await PlanLocal.ajustarCiclosAlPlan(txn, usuario);
    });
    ref.invalidate(baseDatosProvider);
  },
);
