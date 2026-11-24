import 'package:entren_ando/core/sync/sincronizacion.dart';
import 'package:entren_ando/features/nube/indicador_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Pruebas del indicador de sincronización (ENT-54). No necesitan emulador.
void main() {
  setUpAll(() => initializeDateFormatting('es'));

  test('Los 4 estados del indicador', () {
    expect(estadoRespaldo(FaseSync.lista, 0), EstadoRespaldo.sincronizado);
    expect(estadoRespaldo(FaseSync.lista, 3), EstadoRespaldo.pendiente);
    expect(estadoRespaldo(FaseSync.subiendo, 3), EstadoRespaldo.sincronizando);
    expect(estadoRespaldo(FaseSync.error, 0), EstadoRespaldo.error);
  });

  test('Sin red: pendiente si quedó algo por subir, si no, sincronizado', () {
    expect(estadoRespaldo(FaseSync.sinRed, 2), EstadoRespaldo.pendiente);
    expect(estadoRespaldo(FaseSync.sinRed, 0), EstadoRespaldo.sincronizado);
  });

  test('Sin llaves o sin sesión no hay respaldo', () {
    expect(estadoRespaldo(FaseSync.apagada, 0), EstadoRespaldo.error);
    expect(estadoRespaldo(FaseSync.sinSesion, 0), EstadoRespaldo.error);
  });

  test('Texto del estado con el número de cambios', () {
    expect(textoRespaldo(EstadoRespaldo.pendiente, 1), '1 cambio por subir');
    expect(textoRespaldo(EstadoRespaldo.pendiente, 5), '5 cambios por subir');
    expect(textoRespaldo(EstadoRespaldo.sincronizado, 0), 'Todo respaldado');
  });

  test('Fecha y hora de la última sincronización', () {
    final ahora = DateTime(2026, 11, 23, 21, 0);
    expect(textoUltimaVez(null, ahora: ahora), 'Todavía no se sincroniza');
    expect(textoUltimaVez(DateTime(2026, 11, 23, 20, 15), ahora: ahora), 'Última sincronización: hoy a las 20:15');
    expect(textoUltimaVez(DateTime(2026, 11, 22, 9, 5), ahora: ahora), 'Última sincronización: ayer a las 9:05');
    expect(
      textoUltimaVez(DateTime(2026, 11, 16, 20, 15), ahora: ahora),
      'Última sincronización: lunes 16 de noviembre a las 20:15',
    );
  });
}
