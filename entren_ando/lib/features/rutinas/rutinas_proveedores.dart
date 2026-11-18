import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../entrenamiento/hoy_repositorio.dart';
import 'rutinas_repositorio.dart';

/// Ciclos del usuario (activos primero).
final ciclosProvider = FutureProvider.autoDispose<List<Ciclo>>((ref) async {
  final repositorio = await ref.watch(rutinasRepositorioProvider.future);
  return repositorio?.ciclos() ?? const [];
});

/// Límite de ciclos activos del plan del usuario.
final limiteCiclosProvider = FutureProvider.autoDispose<LimiteCiclos?>((ref) async {
  final repositorio = await ref.watch(rutinasRepositorioProvider.future);
  return repositorio?.limite();
});

final cicloProvider = FutureProvider.autoDispose.family<Ciclo?, String>((ref, idCiclo) async {
  final repositorio = await ref.watch(rutinasRepositorioProvider.future);
  return repositorio?.ciclo(idCiclo);
});

final diasCicloProvider = FutureProvider.autoDispose.family<List<DiaRutina>, String>((ref, idCiclo) async {
  final repositorio = await ref.watch(rutinasRepositorioProvider.future);
  return repositorio?.dias(idCiclo) ?? const [];
});

final diaRutinaProvider = FutureProvider.autoDispose.family<DiaRutina?, String>((ref, idDia) async {
  final repositorio = await ref.watch(rutinasRepositorioProvider.future);
  return repositorio?.dia(idDia);
});

final ejerciciosDiaProvider =
    FutureProvider.autoDispose.family<List<EjercicioProgramado>, String>((ref, idDia) async {
  final repositorio = await ref.watch(rutinasRepositorioProvider.future);
  return repositorio?.ejerciciosDelDia(idDia) ?? const [];
});

/// Vuelve a leer todo lo de rutinas después de guardar, y la pestaña Hoy.
void refrescarRutinas(WidgetRef ref) {
  ref.invalidate(ciclosProvider);
  ref.invalidate(limiteCiclosProvider);
  ref.invalidate(cicloProvider);
  ref.invalidate(diasCicloProvider);
  ref.invalidate(diaRutinaProvider);
  ref.invalidate(ejerciciosDiaProvider);
  ref.invalidate(diaDeHoyProvider);
}

/// Fechas para mostrar y capturar: '2026-11-17' ↔ '17/11/2026' y "17 de noviembre de 2026".
abstract final class FechaCiclo {
  static final DateFormat _corta = DateFormat('dd/MM/yyyy');

  static String aCampo(String iso) => _corta.format(DateTime.parse(iso));

  /// Convierte 'dd/mm/aaaa' a 'aaaa-mm-dd' (null si no es una fecha real).
  static String? deCampo(String? texto) {
    final partes = (texto ?? '').trim().split(RegExp(r'[/\-.]'));
    if (partes.length != 3) return null;
    final dia = int.tryParse(partes[0]);
    final mes = int.tryParse(partes[1]);
    final anio = int.tryParse(partes[2]);
    if (dia == null || mes == null || anio == null || anio < 2000 || anio > 2100) return null;
    final fecha = DateTime(anio, mes, dia);
    if (fecha.day != dia || fecha.month != mes) return null; // por ejemplo, 31/02
    return DateFormat('yyyy-MM-dd').format(fecha);
  }

  static String larga(String iso) => DateFormat("d 'de' MMMM 'de' y", 'es').format(DateTime.parse(iso));

  static String rango(String inicio, String? fin) =>
      fin == null ? 'Desde el ${larga(inicio)}' : '${larga(inicio)} al ${larga(fin)}';

  /// Fin sugerido: un semestre (18 semanas) después del inicio.
  static String finSugerido(String inicioIso) =>
      DateFormat('yyyy-MM-dd').format(DateTime.parse(inicioIso).add(const Duration(days: 18 * 7)));
}
