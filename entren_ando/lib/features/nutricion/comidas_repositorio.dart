import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/base_datos.dart';
import '../../core/db/fechas.dart';
import '../../core/db/usuario_actual.dart';

/// Una comida registrada.
class Comida {
  const Comida({
    required this.hora,
    required this.descripcion,
    required this.calorias,
    required this.porIa,
  });

  /// 'HH:MM'
  final String hora;
  final String descripcion;
  final int calorias;

  /// true si vino de un escaneo con IA; false si se capturó a mano.
  final bool porIa;
}

/// Comidas de hoy y el total de calorías.
class ComidasDeHoy {
  const ComidasDeHoy(this.comidas);

  final List<Comida> comidas;

  int get totalCalorias => comidas.fold(0, (suma, c) => suma + c.calorias);
}

final comidasDeHoyProvider = FutureProvider<ComidasDeHoy>((ref) async {
  final idUsuario = ref.watch(usuarioActualIdProvider);
  if (idUsuario == null) return const ComidasDeHoy([]);
  final bd = await ref.watch(baseDatosProvider.future);

  final filas = await bd.rawQuery('''
    SELECT substr(fecha_hora, 12, 5) AS hora, descripcion, calorias, origen
    FROM registro_comida
    WHERE id_usuario = ? AND eliminado = 0 AND substr(fecha_hora, 1, 10) = ?
    ORDER BY fecha_hora
  ''', [idUsuario, Fechas.hoy()]);

  return ComidasDeHoy([
    for (final f in filas)
      Comida(
        hora: f['hora'] as String,
        descripcion: f['descripcion'] as String,
        calorias: f['calorias'] as int,
        porIa: f['origen'] == 'ia',
      ),
  ]);
});
