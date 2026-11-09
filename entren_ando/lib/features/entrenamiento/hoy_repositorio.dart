import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/base_datos.dart';
import '../../core/db/fechas.dart';
import '../../core/db/usuario_actual.dart';

/// Un ejercicio de la plantilla del día.
class EjercicioDelDia {
  const EjercicioDelDia({
    required this.orden,
    required this.nombre,
    required this.series,
    required this.repeticiones,
    this.pesoKg,
    this.trabajoSeg,
  });

  final int orden;

  /// Alias del usuario si tiene uno; si no, el nombre oficial (RF-05).
  final String nombre;
  final int series;
  final int repeticiones;
  final double? pesoKg;
  final int? trabajoSeg;
}

/// Lo que toca hoy según el ciclo activo.
class DiaDeHoy {
  const DiaDeHoy({
    required this.nombreCiclo,
    required this.nombreDia,
    required this.esDescanso,
    required this.ejercicios,
  });

  final String nombreCiclo;
  final String nombreDia;
  final bool esDescanso;
  final List<EjercicioDelDia> ejercicios;
}

/// Día de la rutina que toca hoy (null si no hay usuario o ciclo activo).
final diaDeHoyProvider = FutureProvider<DiaDeHoy?>((ref) async {
  final idUsuario = ref.watch(usuarioActualIdProvider);
  if (idUsuario == null) return null;
  final bd = await ref.watch(baseDatosProvider.future);
  final diaSemana = Fechas.ahoraCdmx().weekday; // 1 = lunes ... 7 = domingo

  final dias = await bd.rawQuery('''
    SELECT c.nombre AS ciclo, d.id_dia, d.nombre AS dia, d.es_descanso
    FROM ciclo_rutina c
    JOIN dia_rutina d ON d.id_ciclo = c.id_ciclo AND d.eliminado = 0
    WHERE c.id_usuario = ? AND c.estado = 'activo' AND c.eliminado = 0
      AND d.dia_semana = ?
    LIMIT 1
  ''', [idUsuario, diaSemana]);
  if (dias.isEmpty) return null;
  final dia = dias.first;

  final filas = await bd.rawQuery('''
    SELECT ep.orden, COALESCE(ue.nombre_alias, e.nombre_oficial) AS nombre,
           ep.series_objetivo, ep.reps_objetivo, ep.peso_objetivo_kg, ep.trabajo_seg
    FROM ejercicio_programado ep
    JOIN ejercicio e ON e.id_ejercicio = ep.id_ejercicio
    LEFT JOIN usuario_ejercicio ue
      ON ue.id_ejercicio = ep.id_ejercicio AND ue.id_usuario = ? AND ue.eliminado = 0
    WHERE ep.id_dia = ? AND ep.eliminado = 0
    ORDER BY ep.orden
  ''', [idUsuario, dia['id_dia']]);

  return DiaDeHoy(
    nombreCiclo: dia['ciclo'] as String,
    nombreDia: dia['dia'] as String,
    esDescanso: dia['es_descanso'] == 1,
    ejercicios: [
      for (final f in filas)
        EjercicioDelDia(
          orden: f['orden'] as int,
          nombre: f['nombre'] as String,
          series: f['series_objetivo'] as int,
          repeticiones: f['reps_objetivo'] as int,
          pesoKg: (f['peso_objetivo_kg'] as num?)?.toDouble(),
          trabajoSeg: f['trabajo_seg'] as int?,
        ),
    ],
  );
});
