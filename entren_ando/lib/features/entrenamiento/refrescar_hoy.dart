import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../calendario/calendario_repositorio.dart';
import 'bitacora/bitacora_repositorio.dart';
import 'hoy_repositorio.dart';

/// Vuelve a leer todo lo que cambia al registrar algo de hoy: la lista de Hoy,
/// la sesión, los ejercicios tocados y el calendario (colores del mes y el
/// detalle de los días), para que el calendario no se quede con el estado viejo.
void refrescarSesionDeHoy(WidgetRef ref, {Iterable<String> idsProgramados = const []}) {
  for (final id in idsProgramados) {
    ref.invalidate(ejercicioBitacoraProvider(id));
  }
  ref.invalidate(diaDeHoyProvider);
  ref.invalidate(sesionDeHoyProvider);
  ref.invalidate(mesCalendarioProvider);
  ref.invalidate(detalleDiaProvider);
}
