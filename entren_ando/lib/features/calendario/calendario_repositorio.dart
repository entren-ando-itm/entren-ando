import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/base_datos.dart';
import '../../core/db/fechas.dart';
import '../../core/db/usuario_actual.dart';
import '../../core/diseno.dart';

/// Calendario semáforo mensual (ENT-60, RF-08, RNF-04).
///
/// * ENT-106: **una sola consulta de sesiones por mes** (usa el índice
///   `idx_sesion_calendario (id_usuario, fecha)`), más la plantilla del ciclo
///   activo y la fecha de registro. Los colores se calculan en memoria con
///   [colorearMes]. Nunca una consulta por día: eso vuelve lento el calendario.
/// * ENT-108: en debug mide con `Stopwatch` cuánto tarda en cargar el mes
///   (meta: menos de 1.5 s con los 45 días demo).
///
/// Todo se lee de la base local: funciona sin internet.

/// Un día del mes con su color.
class DiaMes {
  const DiaMes({
    required this.fecha,
    required this.estado,
    this.esOverride = false,
    this.tieneSesion = false,
  });

  /// Medianoche del día (modo UTC, como `Fechas.hoyComoFecha()`).
  final DateTime fecha;

  /// Color del día. `EstadoDia.futuro` = sin color (días que vienen o antes del registro).
  final EstadoDia estado;

  /// true si el día se marcó después (override, ENT-70).
  final bool esOverride;

  /// true si hay sesión guardada ese día (se puede ver el detalle).
  final bool tieneSesion;
}

/// El mes completo para la pantalla.
class MesCalendario {
  const MesCalendario({
    required this.anio,
    required this.mes,
    required this.dias,
    this.milisegundos,
  });

  final int anio;
  final int mes;

  /// Del día 1 al último del mes.
  final List<DiaMes> dias;

  /// Cuánto tardó en cargar (solo en debug, ENT-108).
  final int? milisegundos;

  /// Días por color, para la leyenda.
  Map<EstadoDia, int> get conteo {
    final conteo = <EstadoDia, int>{};
    for (final dia in dias) {
      conteo[dia.estado] = (conteo[dia.estado] ?? 0) + 1;
    }
    return conteo;
  }
}

/// Regla de colores de ENT-60 (función pura, se prueba sin base):
/// * Días que vienen o anteriores al registro de la cuenta: sin color.
/// * Con sesión: verde (completa), naranja (parcial) o azul (descanso).
/// * Sin sesión: azul si la plantilla dice descanso o el día no está en la
///   rutina; gris si era día de entrenamiento.
/// * Hoy: su color si ya tiene sesión completa o parcial; si no, va en tinta.
///
/// [sesiones] usa la fecha 'AAAA-MM-DD' como llave. [plantilla] es
/// dia_semana (1 = lunes) → es_descanso; vacía si no hay ciclo activo.
List<DiaMes> colorearMes({
  required int anio,
  required int mes,
  required DateTime hoy,
  required DateTime? registro,
  required Map<String, ({String estado, bool esOverride})> sesiones,
  required Map<int, bool> plantilla,
}) {
  final ultimo = DateTime.utc(anio, mes + 1, 0).day;
  final dias = <DiaMes>[];
  for (var d = 1; d <= ultimo; d++) {
    final fecha = DateTime.utc(anio, mes, d);
    final sesion = sesiones[Fechas.fecha(fecha)];
    final esHoy = fecha == hoy;

    EstadoDia estado;
    if (fecha.isAfter(hoy) || (registro != null && fecha.isBefore(registro))) {
      estado = EstadoDia.futuro;
    } else if (sesion != null) {
      estado = EstadoDia.deSesion(sesion.estado);
      if (esHoy && estado == EstadoDia.descanso) estado = EstadoDia.hoy;
    } else if (esHoy) {
      estado = EstadoDia.hoy;
    } else if (plantilla.isEmpty) {
      estado = EstadoDia.sinActividad;
    } else {
      final esDescanso = plantilla[fecha.weekday] ?? true; // no está en la rutina = descanso
      estado = esDescanso ? EstadoDia.descanso : EstadoDia.sinActividad;
    }

    dias.add(DiaMes(
      fecha: fecha,
      estado: estado,
      esOverride: sesion?.esOverride ?? false,
      tieneSesion: sesion != null,
    ));
  }
  return dias;
}

/// El mes que se está viendo (1.er día del mes). Empieza en el mes de hoy.
final mesVisibleProvider = NotifierProvider<MesVisible, DateTime>(MesVisible.new);

class MesVisible extends Notifier<DateTime> {
  @override
  DateTime build() {
    final hoy = Fechas.hoyComoFecha();
    return DateTime.utc(hoy.year, hoy.month);
  }

  void anterior() => state = DateTime.utc(state.year, state.month - 1);

  void siguiente() => state = DateTime.utc(state.year, state.month + 1);

  void irAHoy() => state = build();
}

/// El mes con sus colores (ENT-106). La llave es el 1.er día del mes.
final mesCalendarioProvider =
    FutureProvider.family<MesCalendario?, DateTime>((ref, primerDia) async {
  final idUsuario = ref.watch(usuarioActualIdProvider);
  if (idUsuario == null) return null;
  final bd = await ref.watch(baseDatosProvider.future);
  final reloj = Stopwatch()..start();

  final ultimoDia = DateTime.utc(primerDia.year, primerDia.month + 1, 0);

  // 1. Las sesiones del mes: una sola consulta con idx_sesion_calendario.
  final filas = await bd.rawQuery('''
    SELECT fecha, estado, es_override
    FROM sesion_entrenamiento
    WHERE id_usuario = ? AND fecha BETWEEN ? AND ? AND eliminado = 0
  ''', [idUsuario, Fechas.fecha(primerDia), Fechas.fecha(ultimoDia)]);

  // Si hay varias sesiones el mismo día, gana la de mejor estado.
  const prioridad = {'completa': 3, 'parcial': 2, 'descanso': 1};
  final sesiones = <String, ({String estado, bool esOverride})>{};
  for (final f in filas) {
    final fecha = f['fecha'] as String;
    final estado = f['estado'] as String;
    final actual = sesiones[fecha];
    if (actual == null || (prioridad[estado] ?? 0) > (prioridad[actual.estado] ?? 0)) {
      sesiones[fecha] = (estado: estado, esOverride: f['es_override'] == 1);
    }
  }

  // 2. La plantilla del ciclo activo (qué días son de descanso).
  final plantillaFilas = await bd.rawQuery('''
    SELECT d.dia_semana, d.es_descanso
    FROM dia_rutina d
    JOIN ciclo_rutina c ON c.id_ciclo = d.id_ciclo
    WHERE c.id_usuario = ? AND c.estado = 'activo' AND c.eliminado = 0 AND d.eliminado = 0
  ''', [idUsuario]);
  final plantilla = {
    for (final f in plantillaFilas) f['dia_semana'] as int: f['es_descanso'] == 1,
  };

  // 3. Fecha de registro: los días anteriores no tienen color.
  final usuario = await bd.rawQuery(
    'SELECT fecha_registro FROM usuario WHERE id_usuario = ? AND eliminado = 0',
    [idUsuario],
  );
  final textoRegistro = usuario.firstOrNull?['fecha_registro'] as String?;
  var registro = textoRegistro == null ? null : Fechas.deTexto(textoRegistro);
  // Los datos demo traen sesiones de antes del registro: la sesión más antigua manda.
  final primeraSesion = await bd.rawQuery(
    'SELECT MIN(fecha) AS f FROM sesion_entrenamiento WHERE id_usuario = ? AND eliminado = 0',
    [idUsuario],
  );
  final textoPrimera = primeraSesion.first['f'] as String?;
  if (textoPrimera != null && registro != null) {
    final primera = Fechas.deTexto(textoPrimera);
    if (primera.isBefore(registro)) registro = primera;
  }

  final dias = colorearMes(
    anio: primerDia.year,
    mes: primerDia.month,
    hoy: Fechas.hoyComoFecha(),
    registro: registro,
    sesiones: sesiones,
    plantilla: plantilla,
  );

  reloj.stop();
  if (kDebugMode) {
    // ENT-108: debe ser menos de 1500 ms con los 45 días demo.
    debugPrint('Calendario ${Fechas.fecha(primerDia).substring(0, 7)}: '
        '${reloj.elapsedMilliseconds} ms');
  }
  return MesCalendario(
    anio: primerDia.year,
    mes: primerDia.month,
    dias: dias,
    milisegundos: kDebugMode ? reloj.elapsedMilliseconds : null,
  );
});

/// Una serie del detalle de un día.
typedef SerieDelDia = ({int numero, double pesoKg, int repeticiones});

/// Un ejercicio que se hizo ese día.
class EjercicioDelDiaPasado {
  const EjercicioDelDiaPasado({
    required this.nombre,
    required this.completado,
    required this.esSustitucion,
    required this.series,
  });

  final String nombre;
  final bool completado;
  final bool esSustitucion;
  final List<SerieDelDia> series;
}

/// Lo que se hizo un día: estado, comentario, ejercicios y series.
class DetalleDia {
  const DetalleDia({
    required this.estado,
    required this.ejercicios,
    this.comentario,
    this.nombreDia,
    this.esOverride = false,
  });

  final String estado;
  final String? comentario;
  final String? nombreDia;
  final bool esOverride;
  final List<EjercicioDelDiaPasado> ejercicios;
}

/// Detalle de un día al tocarlo (null si no hay sesión). Solo se consulta al tocar.
final detalleDiaProvider = FutureProvider.family<DetalleDia?, String>((ref, fecha) async {
  final idUsuario = ref.watch(usuarioActualIdProvider);
  if (idUsuario == null) return null;
  final bd = await ref.watch(baseDatosProvider.future);

  final sesiones = await bd.rawQuery('''
    SELECT s.id_sesion, s.estado, s.comentario, s.es_override, d.nombre AS nombre_dia
    FROM sesion_entrenamiento s
    LEFT JOIN dia_rutina d ON d.id_dia = s.id_dia
    WHERE s.id_usuario = ? AND s.fecha = ? AND s.eliminado = 0
    ORDER BY CASE s.estado WHEN 'completa' THEN 0 WHEN 'parcial' THEN 1 ELSE 2 END
    LIMIT 1
  ''', [idUsuario, fecha]);
  if (sesiones.isEmpty) return null;
  final sesion = sesiones.first;

  // Ejercicios y series en una sola consulta.
  final filas = await bd.rawQuery('''
    SELECT r.id_registro, r.orden, r.completado, r.es_sustitucion,
           COALESCE(ue.nombre_alias, e.nombre_oficial) AS nombre,
           ep.series_objetivo,
           x.numero_serie, x.peso_kg, x.repeticiones
    FROM registro_ejercicio r
    JOIN ejercicio e ON e.id_ejercicio = r.id_ejercicio
    LEFT JOIN ejercicio_programado ep ON ep.id_programado = r.id_programado
    LEFT JOIN usuario_ejercicio ue
      ON ue.id_ejercicio = r.id_ejercicio AND ue.id_usuario = ? AND ue.eliminado = 0
    LEFT JOIN serie x ON x.id_registro = r.id_registro AND x.eliminado = 0
    WHERE r.id_sesion = ? AND r.eliminado = 0
    ORDER BY r.orden, x.numero_serie
  ''', [idUsuario, sesion['id_sesion']]);

  final ejercicios = <String, EjercicioDelDiaPasado>{};
  final objetivos = <String, int?>{};
  for (final f in filas) {
    final id = f['id_registro'] as String;
    final ejercicio = ejercicios.putIfAbsent(
      id,
      () => EjercicioDelDiaPasado(
        nombre: f['nombre'] as String,
        completado: f['completado'] == 1,
        esSustitucion: f['es_sustitucion'] == 1,
        series: [],
      ),
    );
    objetivos[id] = f['series_objetivo'] as int?;
    if (f['numero_serie'] != null) {
      ejercicio.series.add((
        numero: f['numero_serie'] as int,
        pesoKg: (f['peso_kg'] as num).toDouble(),
        repeticiones: f['repeticiones'] as int,
      ));
    }
  }

  return DetalleDia(
    estado: sesion['estado'] as String,
    comentario: sesion['comentario'] as String?,
    nombreDia: sesion['nombre_dia'] as String?,
    esOverride: sesion['es_override'] == 1,
    // ENT-121: con todas sus series marcadas también cuenta como hecho,
    // aunque no se haya tocado "Terminar ejercicio".
    ejercicios: [
      for (final MapEntry(key: id, value: e) in ejercicios.entries)
        EjercicioDelDiaPasado(
          nombre: e.nombre,
          completado: e.completado || (objetivos[id] != null && e.series.length >= objetivos[id]!),
          esSustitucion: e.esSustitucion,
          series: e.series,
        ),
    ],
  );
});
