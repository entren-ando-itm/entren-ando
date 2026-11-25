import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/db/base_datos.dart';
import '../../core/db/usuario_actual.dart';
import '../../core/diseno.dart';
import '../../core/sync/motor_sync.dart';
import '../../core/sync/sincronizacion.dart';

/// Los 4 estados del indicador (ENT-54, criterio 1).
enum EstadoRespaldo { sincronizado, pendiente, sincronizando, error }

/// Cuántos cambios del celular faltan por subir. Se recalcula cada vez que
/// cambia la sincronización y cada vez que se abre una pantalla que lo usa.
final pendientesSyncProvider = FutureProvider.autoDispose<int>((ref) async {
  ref.watch(sincronizacionProvider);
  final idUsuario = ref.watch(usuarioActualIdProvider);
  if (idUsuario == null) return 0;
  try {
    final bd = await ref.watch(baseDatosProvider.future);
    return await MotorSync.contarPendientesEn(bd, idUsuario);
  } catch (_) {
    // Si la base no abre, el icono no debe romper la pantalla de Perfil:
    // se muestra sin número y el estado lo da la sincronización.
    return 0;
  }
});

/// El estado que se muestra, a partir de la sincronización y los pendientes.
EstadoRespaldo estadoRespaldo(FaseSync fase, int pendientes) => switch (fase) {
      FaseSync.subiendo => EstadoRespaldo.sincronizando,
      // Sin llaves o sin sesión no hay respaldo, aunque no haya pendientes.
      FaseSync.error || FaseSync.apagada || FaseSync.sinSesion => EstadoRespaldo.error,
      // Sin red o ya terminada: depende de si quedó algo por subir.
      FaseSync.sinRed || FaseSync.lista =>
        pendientes > 0 ? EstadoRespaldo.pendiente : EstadoRespaldo.sincronizado,
    };

/// Texto corto del estado: "Todo respaldado", "3 cambios por subir"...
String textoRespaldo(EstadoRespaldo estado, int pendientes) => switch (estado) {
      EstadoRespaldo.sincronizado => 'Todo respaldado',
      EstadoRespaldo.pendiente => pendientes == 1 ? '1 cambio por subir' : '$pendientes cambios por subir',
      EstadoRespaldo.sincronizando => 'Sincronizando…',
      EstadoRespaldo.error => 'Sin respaldo',
    };

/// "hoy a las 20:15", "ayer a las 9:05" o "lunes 16 de noviembre a las 20:15"
/// (ENT-54, criterio 3).
String textoUltimaVez(DateTime? cuando, {DateTime? ahora}) {
  if (cuando == null) return 'Todavía no se sincroniza';
  final hoy = ahora ?? DateTime.now();
  final dias = DateTime(hoy.year, hoy.month, hoy.day).difference(DateTime(cuando.year, cuando.month, cuando.day)).inDays;
  final hora = DateFormat('H:mm', 'es').format(cuando);
  final dia = switch (dias) {
    0 => 'hoy',
    1 => 'ayer',
    _ => DateFormat("EEEE d 'de' MMMM", 'es').format(cuando),
  };
  return 'Última sincronización: $dia a las $hora';
}

/// Icono pequeño con el estado del respaldo (ENT-54). Con [conNumero] muestra
/// al lado cuántos cambios faltan por subir.
class IconoSincronizacion extends ConsumerWidget {
  const IconoSincronizacion({super.key, this.conNumero = true});

  final bool conNumero;

  static IconData icono(EstadoRespaldo estado) => switch (estado) {
        EstadoRespaldo.sincronizado => Icons.cloud_done_outlined,
        EstadoRespaldo.pendiente => Icons.cloud_upload_outlined,
        EstadoRespaldo.sincronizando => Icons.sync_rounded,
        EstadoRespaldo.error => Icons.cloud_off_outlined,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fase = ref.watch(sincronizacionProvider).fase;
    final pendientes = ref.watch(pendientesSyncProvider).value ?? 0;
    final estado = estadoRespaldo(fase, pendientes);
    final colores = context.colores;
    return Semantics(
      label: 'Respaldo: ${textoRespaldo(estado, pendientes)}',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icono(estado),
            size: 20,
            color: estado == EstadoRespaldo.error ? colores.error : colores.tinta2,
          ),
          if (conNumero && estado == EstadoRespaldo.pendiente) ...[
            const SizedBox(width: Medidas.espacio1),
            Text(
              '$pendientes',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colores.tinta2,
                    fontFeatures: TipografiaEntrenAndo.numerosTabulares,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
