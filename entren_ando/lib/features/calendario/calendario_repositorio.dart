import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/base_datos.dart';
import '../../core/db/fechas.dart';
import '../../core/db/usuario_actual.dart';

/// Un día con el estado de su sesión.
class DiaCalendario {
  const DiaCalendario({required this.fecha, this.estado, this.esOverride = false});

  final DateTime fecha;

  /// 'completa', 'parcial', 'descanso' o null si no hay registro (gris).
  final String? estado;
  final bool esOverride;
}

/// Los últimos 14 días, del más reciente al más antiguo.
final ultimosDiasProvider = FutureProvider<List<DiaCalendario>>((ref) async {
  final idUsuario = ref.watch(usuarioActualIdProvider);
  if (idUsuario == null) return const [];
  final bd = await ref.watch(baseDatosProvider.future);

  final hoy = Fechas.hoyComoFecha();
  final desde = hoy.subtract(const Duration(days: 13));
  final filas = await bd.rawQuery('''
    SELECT fecha, estado, es_override
    FROM sesion_entrenamiento
    WHERE id_usuario = ? AND eliminado = 0 AND fecha BETWEEN ? AND ?
  ''', [idUsuario, Fechas.fecha(desde), Fechas.fecha(hoy)]);

  // Si hay varias sesiones el mismo día, gana la de mejor estado.
  const prioridad = {'completa': 3, 'parcial': 2, 'descanso': 1};
  final porFecha = <String, Map<String, Object?>>{};
  for (final fila in filas) {
    final fecha = fila['fecha'] as String;
    final actual = porFecha[fecha];
    if (actual == null ||
        (prioridad[fila['estado']] ?? 0) > (prioridad[actual['estado']] ?? 0)) {
      porFecha[fecha] = fila;
    }
  }

  final dias = <DiaCalendario>[];
  for (var i = 0; i < 14; i++) {
    final fecha = hoy.subtract(Duration(days: i));
    final fila = porFecha[Fechas.fecha(fecha)];
    dias.add(DiaCalendario(
      fecha: fecha,
      estado: fila?['estado'] as String?,
      esOverride: fila?['es_override'] == 1,
    ));
  }
  return dias;
});
