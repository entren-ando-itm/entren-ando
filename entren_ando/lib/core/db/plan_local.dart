import 'package:sqflite_sqlcipher/sqflite.dart';

import 'escritura_local.dart';

/// Copia local del plan del usuario (ENT-52). El servidor decide el plan
/// (`usuario.id_plan`); aquí solo se ajusta lo que depende de él en el celular.
class PlanLocal {
  PlanLocal._();

  /// Si el plan ya no permite tantos ciclos activos (por ejemplo, al volver a
  /// Gratuito), archiva los que sobran y conserva los más recientes. El límite
  /// sale de `plan.max_ciclos_activos` (NULL = ilimitado). Devuelve cuántos archivó.
  static Future<int> ajustarCiclosAlPlan(DatabaseExecutor bd, String idUsuario) async {
    final plan = await bd.rawQuery(
      'SELECT p.max_ciclos_activos FROM usuario u JOIN plan p ON p.id_plan = u.id_plan '
      'WHERE u.id_usuario = ? AND u.eliminado = 0',
      [idUsuario],
    );
    if (plan.isEmpty) return 0;
    final maximo = plan.first['max_ciclos_activos'] as int?;
    if (maximo == null) return 0;
    final activos = await bd.rawQuery(
      "SELECT id_ciclo FROM ciclo_rutina WHERE id_usuario = ? AND estado = 'activo' AND eliminado = 0 "
      'ORDER BY fecha_inicio DESC, creado_en DESC',
      [idUsuario],
    );
    final sobran = activos.skip(maximo).map((f) => f['id_ciclo']).toList();
    final escritura = EscrituraLocal(bd);
    for (final id in sobran) {
      await escritura.actualizar('ciclo_rutina', {'estado': 'archivado'}, where: 'id_ciclo = ?', whereArgs: [id]);
    }
    return sobran.length;
  }

  /// Vencimiento sin red: si la prueba de Premium que bajó del servidor ya
  /// expiró, el celular vuelve a Gratuito sin esperar a sincronizar. El
  /// servidor hace lo mismo cada día (`vencer_premium_prueba`), así que no hace
  /// falta subir nada: `id_plan` nunca se sube.
  static Future<bool> revisarVencimiento(DatabaseExecutor bd, String idUsuario, {DateTime? ahora}) async {
    final usuario = await bd.rawQuery(
      'SELECT id_plan FROM usuario WHERE id_usuario = ? AND eliminado = 0',
      [idUsuario],
    );
    if (usuario.isEmpty || usuario.first['id_plan'] != 2) return false;
    final compras = await bd.rawQuery(
      "SELECT fecha_expiracion FROM suscripcion WHERE id_usuario = ? AND id_plan = 2 AND estado = 'activa' AND eliminado = 0",
      [idUsuario],
    );
    // Recién activada: la suscripción todavía no baja al celular.
    if (compras.isEmpty) return false;
    final momento = (ahora ?? DateTime.now()).toUtc();
    final sigue = compras.any((f) {
      final vence = DateTime.tryParse(f['fecha_expiracion'] as String? ?? '');
      return vence == null || vence.isAfter(momento);
    });
    if (sigue) return false;
    await bd.rawUpdate('UPDATE usuario SET id_plan = 1 WHERE id_usuario = ? AND id_plan = 2', [idUsuario]);
    await ajustarCiclosAlPlan(bd, idUsuario);
    return true;
  }
}
