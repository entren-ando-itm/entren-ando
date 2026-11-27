import 'package:entren_ando/features/rutinas/rutinas_repositorio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pruebas de ciclos de rutina (ENT-47). No necesitan emulador.
void main() {
  test('Límite de ciclos: sale del plan y NULL es ilimitado (RN-01)', () {
    const gratuitoLleno = LimiteCiclos(plan: 'Gratuito', activos: 1, maximo: 1);
    const gratuitoLibre = LimiteCiclos(plan: 'Gratuito', activos: 0, maximo: 1);
    const premium = LimiteCiclos(plan: 'Premium', activos: 5);
    expect(gratuitoLleno.puedeActivarOtro, isFalse);
    expect(gratuitoLibre.puedeActivarOtro, isTrue);
    expect(premium.puedeActivarOtro, isTrue);
  });

  test('Gratuito: 1 ciclo en total; los archivados de Premium solo se consultan', () {
    const sinCiclos = LimiteCiclos(plan: 'Gratuito', activos: 0, total: 0, maximo: 1);
    const conUno = LimiteCiclos(plan: 'Gratuito', activos: 1, total: 1, maximo: 1);
    const unoArchivado = LimiteCiclos(plan: 'Gratuito', activos: 0, total: 1, maximo: 1);
    const exPremium = LimiteCiclos(plan: 'Gratuito', activos: 1, total: 3, maximo: 1);
    const exPremiumSinActivo = LimiteCiclos(plan: 'Gratuito', activos: 0, total: 3, maximo: 1);
    const premium = LimiteCiclos(plan: 'Premium', activos: 4, total: 6);
    expect(sinCiclos.puedeCrearOtro, isTrue);
    expect(conUno.puedeCrearOtro, isFalse);
    expect(unoArchivado.puedeCrearOtro, isFalse);
    expect(unoArchivado.puedeReactivar, isTrue);
    expect(exPremium.puedeReactivar, isFalse);
    expect(exPremiumSinActivo.puedeReactivar, isFalse);
    expect(premium.puedeCrearOtro, isTrue);
    expect(premium.puedeReactivar, isTrue);
  });

  test('Hoy usa el ciclo activo con fecha_inicio más reciente', () {
    final sql = RutinasRepositorio.consultaCicloParaHoy;
    expect(sql, contains("estado = 'activo'"));
    expect(sql, contains('eliminado = 0'));
    expect(sql, contains('ORDER BY fecha_inicio DESC'));
  });

  test('Los ejercicios del día usan el alias del catálogo', () {
    final sql = RutinasRepositorio.consultaEjerciciosDelDia;
    expect(sql, contains('COALESCE(ue.nombre_alias, e.nombre_oficial)'));
    expect(sql, contains('ue.eliminado = 0'));
    expect(sql, contains('ep.eliminado = 0'));
    expect(sql, contains('ORDER BY ep.orden'));
  });

  test('Reordenar mueve un ejercicio a la posición pedida', () {
    const ids = ['a', 'b', 'c', 'd'];
    expect(RutinasRepositorio.reordenar(ids, 'c', 0), ['c', 'a', 'b', 'd']);
    expect(RutinasRepositorio.reordenar(ids, 'a', 3), ['b', 'c', 'd', 'a']);
    expect(RutinasRepositorio.reordenar(ids, 'b', 2), ['a', 'c', 'b', 'd']);
    expect(RutinasRepositorio.reordenar(ids, 'a', 99), ['b', 'c', 'd', 'a']);
    expect(RutinasRepositorio.reordenar(ids, 'd', -1), ['d', 'a', 'b', 'c']);
  });

  test('Fechas del ciclo: el fin no puede ser antes del inicio (CHECK)', () {
    expect(ValidarRutina.fechas('2026-11-17', null), isNull);
    expect(ValidarRutina.fechas('2026-11-17', '2026-11-17'), isNull);
    expect(ValidarRutina.fechas('2026-11-17', '2027-05-30'), isNull);
    expect(ValidarRutina.fechas('2026-11-17', '2026-11-16'), isNotNull);
  });

  test('Validaciones de series, repeticiones, peso, descanso y trabajo', () {
    expect(ValidarRutina.series('0'), isNotNull);
    expect(ValidarRutina.series('4'), isNull);
    expect(ValidarRutina.repeticiones(''), isNotNull);
    expect(ValidarRutina.repeticiones('12'), isNull);
    expect(ValidarRutina.pesoKg(''), isNull);
    expect(ValidarRutina.pesoKg('62,5'), isNull);
    expect(ValidarRutina.pesoKg('-1'), isNotNull);
    expect(ValidarRutina.descansoSeg('0'), isNull);
    expect(ValidarRutina.descansoSeg('-5'), isNotNull);
    expect(ValidarRutina.trabajoSeg(''), isNull);
    expect(ValidarRutina.trabajoSeg('45'), isNull);
    expect(ValidarRutina.nombre('  '), isNotNull);
    expect(ValidarRutina.nombre('Semestre agosto-diciembre'), isNull);
  });

  test('Nombres de los días: 1 = lunes ... 7 = domingo', () {
    expect(nombresDiaSemana.first, 'Lunes');
    expect(nombresDiaSemana.last, 'Domingo');
    const dia = DiaRutina(idDia: 'x', idCiclo: 'c', diaSemana: 3, nombre: 'Pierna', esDescanso: false);
    expect(dia.nombreDiaSemana, 'Miércoles');
  });
}
