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
    this.seriesHechas = 0,
    this.pesoKg,
    this.descansoSeg = 90,
    this.trabajoSeg,
  });

  /// Id de ejercicio_programado. Lo usará la pantalla del ejercicio (ENT-49).
  final String idProgramado;
  final int orden;

  /// Alias del usuario si tiene uno; si no, el nombre oficial (RF-05).
  /// Si hoy se cambió por una alternativa (ENT-59), el de la alternativa.
  final String nombre;
  final int series;
  final int repeticiones;
  final double? pesoKg;

  /// Segundos de descanso entre series (para el temporizador, ENT-19).
  final int descansoSeg;

  /// Segundos de trabajo para ejercicios por tiempo (por ejemplo, la plancha).
  final int? trabajoSeg;

  /// true si hoy ya se terminó en la bitácora, o si ya tiene todas sus series
  /// marcadas aunque no se haya tocado "Terminar ejercicio" (ENT-121).
  final bool completado;

  /// Series guardadas hoy (ENT-121: "2/4" cuando se terminó parcialmente).
  final int seriesHechas;

  /// Terminado con menos series que las de la rutina.
  bool get parcial => completado && seriesHechas < series;
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
             ep.series_objetivo, ep.reps_objetivo, ep.peso_objetivo_kg, ep.descanso_seg, ep.trabajo_seg,
             EXISTS (
               SELECT 1
               FROM sesion_entrenamiento s
               JOIN registro_ejercicio r
                 ON r.id_sesion = s.id_sesion AND r.eliminado = 0
               WHERE s.id_usuario = ? AND s.fecha = ? AND s.eliminado = 0
                 AND r.id_programado = ep.id_programado AND r.completado = 1
             ) AS completado,
             (
               SELECT COUNT(*)
               FROM sesion_entrenamiento s3
               JOIN registro_ejercicio r3 ON r3.id_sesion = s3.id_sesion AND r3.eliminado = 0
               JOIN serie x ON x.id_registro = r3.id_registro AND x.eliminado = 0
               WHERE s3.id_usuario = ? AND s3.fecha = ? AND s3.eliminado = 0
                 AND r3.id_programado = ep.id_programado
             ) AS series_hechas
      FROM ejercicio_programado ep
      -- ENT-59: si hoy se cambió por una alternativa, se muestra la alternativa.
      JOIN ejercicio e ON e.id_ejercicio = COALESCE((
        SELECT r2.id_ejercicio
        FROM sesion_entrenamiento s2
        JOIN registro_ejercicio r2 ON r2.id_sesion = s2.id_sesion AND r2.eliminado = 0
        WHERE s2.id_usuario = ? AND s2.fecha = ? AND s2.eliminado = 0
          AND r2.id_programado = ep.id_programado
        ORDER BY r2.creado_en
        LIMIT 1
      ), ep.id_ejercicio)
      LEFT JOIN usuario_ejercicio ue
        ON ue.id_ejercicio = e.id_ejercicio AND ue.id_usuario = ? AND ue.eliminado = 0
      WHERE ep.id_dia = ? AND ep.eliminado = 0
      ORDER BY ep.orden
    ''', [idUsuario, Fechas.hoy(), idUsuario, Fechas.hoy(), idUsuario, Fechas.hoy(), idUsuario, diaHoy['id_dia']]);

    ejercicios = [
      for (final f in filas)
        EjercicioDelDia(
          idProgramado: f['id_programado'] as String,
          orden: f['orden'] as int,
          nombre: f['nombre'] as String,
          series: f['series_objetivo'] as int,
          repeticiones: f['reps_objetivo'] as int,
          pesoKg: (f['peso_objetivo_kg'] as num?)?.toDouble(),
          descansoSeg: f['descanso_seg'] as int,
          trabajoSeg: f['trabajo_seg'] as int?,
          // ENT-121: con todas las series marcadas cuenta como hecho (también
          // después de "Volver a abrir"); si se quita una, ya no.
          completado: f['completado'] == 1 || (f['series_hechas'] as int) >= (f['series_objetivo'] as int),
          seriesHechas: f['series_hechas'] as int,
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
