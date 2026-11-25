import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/base_datos.dart';
import '../../core/db/fechas.dart';
import '../../core/db/usuario_actual.dart';
import '../../core/diseno.dart';
import 'calendario_repositorio.dart';

/// Resumen de progreso del mes (ENT-71 / ENT-119, RNF-04).
///
/// Días por color, porcentaje de cumplimiento, volumen total (peso ×
/// repeticiones) y los 3 ejercicios con más progreso (primera contra última
/// serie del mes). Usa los colores que ya calculó el calendario y **una sola**
/// consulta de series del mes; todo lo demás se calcula en memoria con
/// [calcularResumen]. Sin internet.

/// Un ejercicio que subió de peso en el mes.
class ProgresoEjercicio {
  const ProgresoEjercicio({required this.nombre, required this.primeroKg, required this.ultimoKg});

  final String nombre;
  final double primeroKg;
  final double ultimoKg;

  double get diferenciaKg => ultimoKg - primeroKg;
}

class ResumenMes {
  const ResumenMes({
    required this.conteo,
    required this.porcentaje,
    required this.volumenKg,
    required this.top,
  });

  /// Días por color (los mismos de la leyenda del calendario).
  final Map<EstadoDia, int> conteo;

  /// Cumplimiento de 0 a 100. null si en el mes todavía no tocaba entrenar.
  final int? porcentaje;

  /// Suma de peso × repeticiones de todas las series del mes.
  final double volumenKg;

  /// Hasta 3 ejercicios con más kilos ganados, de mayor a menor.
  final List<ProgresoEjercicio> top;
}

/// Una serie del mes para el cálculo, en orden de fecha y número de serie.
typedef SerieDelMes = ({int idEjercicio, String nombre, double pesoKg, int repeticiones});

/// Calcula el resumen (función pura, se prueba sin base).
///
/// * Cumplimiento = (completos + ½ parciales) ÷ días que tocaba entrenar
///   (completos + parciales + grises). Los descansos no cuentan.
/// * Progreso por ejercicio = peso de su última serie del mes − peso de la
///   primera. Solo cuentan los que subieron; los de peso corporal (0 kg), no.
ResumenMes calcularResumen({
  required Map<EstadoDia, int> conteo,
  required List<SerieDelMes> series,
}) {
  final completos = conteo[EstadoDia.completo] ?? 0;
  final parciales = conteo[EstadoDia.parcial] ?? 0;
  final grises = conteo[EstadoDia.sinActividad] ?? 0;
  final tocaba = completos + parciales + grises;
  final porcentaje = tocaba == 0 ? null : ((completos + parciales * 0.5) / tocaba * 100).round();

  var volumen = 0.0;
  final primera = <int, SerieDelMes>{};
  final ultima = <int, SerieDelMes>{};
  for (final s in series) {
    volumen += s.pesoKg * s.repeticiones;
    if (s.pesoKg <= 0) continue;
    primera.putIfAbsent(s.idEjercicio, () => s);
    ultima[s.idEjercicio] = s;
  }

  final progresos = [
    for (final id in primera.keys)
      ProgresoEjercicio(
        nombre: ultima[id]!.nombre,
        primeroKg: primera[id]!.pesoKg,
        ultimoKg: ultima[id]!.pesoKg,
      ),
  ].where((p) => p.diferenciaKg > 0).toList()
    ..sort((a, b) => b.diferenciaKg.compareTo(a.diferenciaKg));

  return ResumenMes(
    conteo: conteo,
    porcentaje: porcentaje,
    volumenKg: volumen,
    top: progresos.take(3).toList(),
  );
}

/// Resumen del mes visible (ENT-71). La llave es el 1.er día del mes.
final resumenMesProvider = FutureProvider.family<ResumenMes?, DateTime>((ref, primerDia) async {
  final idUsuario = ref.watch(usuarioActualIdProvider);
  if (idUsuario == null) return null;
  final mes = await ref.watch(mesCalendarioProvider(primerDia).future);
  if (mes == null) return null;
  final bd = await ref.watch(baseDatosProvider.future);
  final ultimoDia = DateTime.utc(primerDia.year, primerDia.month + 1, 0);

  // Una sola consulta: todas las series del mes, en orden.
  final filas = await bd.rawQuery('''
    SELECT r.id_ejercicio,
           COALESCE(ue.nombre_alias, e.nombre_oficial) AS nombre,
           x.peso_kg, x.repeticiones
    FROM sesion_entrenamiento s
    JOIN registro_ejercicio r ON r.id_sesion = s.id_sesion AND r.eliminado = 0
    JOIN serie x ON x.id_registro = r.id_registro AND x.eliminado = 0
    JOIN ejercicio e ON e.id_ejercicio = r.id_ejercicio
    LEFT JOIN usuario_ejercicio ue
      ON ue.id_ejercicio = r.id_ejercicio AND ue.id_usuario = ? AND ue.eliminado = 0
    WHERE s.id_usuario = ? AND s.fecha BETWEEN ? AND ? AND s.eliminado = 0
    ORDER BY s.fecha, r.orden, x.numero_serie
  ''', [idUsuario, idUsuario, Fechas.fecha(primerDia), Fechas.fecha(ultimoDia)]);

  return calcularResumen(
    conteo: mes.conteo,
    series: [
      for (final f in filas)
        (
          idEjercicio: f['id_ejercicio'] as int,
          nombre: f['nombre'] as String,
          pesoKg: (f['peso_kg'] as num).toDouble(),
          repeticiones: f['repeticiones'] as int,
        ),
    ],
  );
});
