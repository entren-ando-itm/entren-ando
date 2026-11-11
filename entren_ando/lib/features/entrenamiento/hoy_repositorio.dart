import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/base_datos.dart';
import '../../core/db/fechas.dart';
import '../../core/db/usuario_actual.dart';

/// Nombres de los días para mostrar en pantalla (1 = lunes ... 7 = domingo),
/// igual que `dia_semana` en la base y `DateTime.weekday`.
const List<String> nombresDias = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

/// Un ejercicio de la plantilla del día con su avance de hoy.
class EjercicioDelDia {
  const EjercicioDelDia({
    required this.idProgramado,
    required this.orden,
    required this.nombre,
    required this.series,
    required this.repeticiones,
    required this.completado,
    this.pesoKg,
    this.trabajoSeg,
  });

  /// Id de ejercicio_programado. Lo usará la pantalla del ejercicio (ENT-49).
  final String idProgramado;
  final int orden;

  /// Alias del usuario si tiene uno; si no, el nombre oficial (RF-05).
  final String nombre;
  final int series;
  final int repeticiones;
  final double? pesoKg;

  /// Segundos de trabajo para ejercicios por tiempo (por ejemplo, la plancha).
  final int? trabajoSeg;

  /// true si hoy ya se marcó como completado en la bitácora.
  final bool completado;
}

/// Un día de la semana que sigue, para las franjas de abajo.
class DiaDeLaSemana {
  const DiaDeLaSemana({
    required this.diaSemana,
    required this.nombre,
    required this.esDescanso,
  });

  /// 1 = lunes ... 7 = domingo.
  final int diaSemana;

  /// Nombre que el usuario le puso al día ("Empuje", "Pierna y glúteo").
  final String nombre;
  final bool esDescanso;
}

/// Todo lo que muestra la pestaña Hoy.
class DiaDeHoy {
  const DiaDeHoy({
    required this.nombreCiclo,
    required this.nombreDia,
    required this.esDescanso,
    required this.ejercicios,
    required this.siguientesDias,
    required this.diasSinRutina,
  });

  final String nombreCiclo;

  /// Nombre del día de hoy en la rutina ("Pierna"). Vacío si hoy no está en la rutina.
  final String nombreDia;

  /// true si hoy es descanso o si el ciclo no tiene nada para hoy.
  final bool esDescanso;
  final List<EjercicioDelDia> ejercicios;

  /// Días que vienen esta semana y que sí están en la rutina (franjas de abajo).
  final List<DiaDeLaSemana> siguientesDias;

  /// Días que vienen esta semana sin nada en la rutina (nota "Sábado y domingo: descanso").
  final List<int> diasSinRutina;

  /// Primer ejercicio sin completar: es el que lleva la marca "Sigue".
  EjercicioDelDia? get siguiente {
    for (final ejercicio in ejercicios) {
      if (!ejercicio.completado) return ejercicio;
    }
    return null;
  }

  /// true si ya se completaron todos los ejercicios de hoy.
  bool get todoCompletado =>
      ejercicios.isNotEmpty && ejercicios.every((e) => e.completado);
}

/// Lo que toca hoy según el ciclo activo (null si no hay usuario o ciclo activo).
///
/// Solo lee de la base local cifrada, así que funciona sin red (RNF-01).
final diaDeHoyProvider = FutureProvider<DiaDeHoy?>((ref) async {
  final idUsuario = ref.watch(usuarioActualIdProvider);
  if (idUsuario == null) return null;
  final bd = await ref.watch(baseDatosProvider.future);
  final hoy = Fechas.ahoraCdmx().weekday; // 1 = lunes ... 7 = domingo

  // 1. Ciclo activo del usuario (el plan gratuito solo permite uno, RN-01).
  final ciclos = await bd.rawQuery('''
    SELECT id_ciclo, nombre
    FROM ciclo_rutina
    WHERE id_usuario = ? AND estado = 'activo' AND eliminado = 0
    LIMIT 1
  ''', [idUsuario]);
  if (ciclos.isEmpty) return null;
  final ciclo = ciclos.first;

  // 2. Todos los días del ciclo, para hoy y para las franjas de la semana.
  final filasDias = await bd.rawQuery('''
    SELECT id_dia, dia_semana, nombre, es_descanso
    FROM dia_rutina
    WHERE id_ciclo = ? AND eliminado = 0
    ORDER BY dia_semana
  ''', [ciclo['id_ciclo']]);

  final diaHoy = filasDias.where((d) => d['dia_semana'] == hoy).firstOrNull;

  // 3. Días que vienen después de hoy y hasta el domingo.
  final siguientesDias = <DiaDeLaSemana>[];
  final diasSinRutina = <int>[];
  for (var dia = hoy + 1; dia <= 7; dia++) {
    final fila = filasDias.where((d) => d['dia_semana'] == dia).firstOrNull;
    if (fila == null) {
      diasSinRutina.add(dia);
    } else {
      siguientesDias.add(DiaDeLaSemana(
        diaSemana: dia,
        nombre: fila['nombre'] as String,
        esDescanso: fila['es_descanso'] == 1,
      ));
    }
  }

  // 4. Ejercicios de hoy con su alias y si ya se completaron en la sesión de hoy.
  var ejercicios = <EjercicioDelDia>[];
  if (diaHoy != null && diaHoy['es_descanso'] != 1) {
    final filas = await bd.rawQuery('''
      SELECT ep.id_programado, ep.orden,
             COALESCE(ue.nombre_alias, e.nombre_oficial) AS nombre,
             ep.series_objetivo, ep.reps_objetivo, ep.peso_objetivo_kg, ep.trabajo_seg,
             EXISTS (
               SELECT 1
               FROM sesion_entrenamiento s
               JOIN registro_ejercicio r
                 ON r.id_sesion = s.id_sesion AND r.eliminado = 0
               WHERE s.id_usuario = ? AND s.fecha = ? AND s.eliminado = 0
                 AND r.id_programado = ep.id_programado AND r.completado = 1
             ) AS completado
      FROM ejercicio_programado ep
      JOIN ejercicio e ON e.id_ejercicio = ep.id_ejercicio
      LEFT JOIN usuario_ejercicio ue
        ON ue.id_ejercicio = ep.id_ejercicio AND ue.id_usuario = ? AND ue.eliminado = 0
      WHERE ep.id_dia = ? AND ep.eliminado = 0
      ORDER BY ep.orden
    ''', [idUsuario, Fechas.hoy(), idUsuario, diaHoy['id_dia']]);

    ejercicios = [
      for (final f in filas)
        EjercicioDelDia(
          idProgramado: f['id_programado'] as String,
          orden: f['orden'] as int,
          nombre: f['nombre'] as String,
          series: f['series_objetivo'] as int,
          repeticiones: f['reps_objetivo'] as int,
          pesoKg: (f['peso_objetivo_kg'] as num?)?.toDouble(),
          trabajoSeg: f['trabajo_seg'] as int?,
          completado: f['completado'] == 1,
        ),
    ];
  }

  return DiaDeHoy(
    nombreCiclo: ciclo['nombre'] as String,
    nombreDia: diaHoy?['nombre'] as String? ?? '',
    // Un día que no está en la rutina también cuenta como descanso.
    esDescanso: diaHoy == null || diaHoy['es_descanso'] == 1,
    ejercicios: ejercicios,
    siguientesDias: siguientesDias,
    diasSinRutina: diasSinRutina,
  );
});
