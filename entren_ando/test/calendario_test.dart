import 'package:entren_ando/core/diseno.dart';
import 'package:entren_ando/features/calendario/calendario_repositorio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pruebas de los colores del calendario semáforo (ENT-60 / ENT-106). Sin emulador.
void main() {
  // Noviembre de 2026: el 1 es domingo. Hoy = miércoles 25.
  final hoy = DateTime.utc(2026, 11, 25);
  // Rutina: lunes a jueves se entrena; viernes es descanso; sábado y domingo no están.
  const plantilla = {1: false, 2: false, 3: false, 4: false, 5: true};

  List<DiaMes> colorear({
    Map<String, ({String estado, bool esOverride})> sesiones = const {},
    DateTime? registro,
    Map<int, bool> plantilla = plantilla,
  }) {
    return colorearMes(
      anio: 2026,
      mes: 11,
      hoy: hoy,
      registro: registro,
      sesiones: sesiones,
      plantilla: plantilla,
    );
  }

  EstadoDia estadoDel(List<DiaMes> dias, int dia) => dias[dia - 1].estado;

  test('El mes trae todos sus días', () {
    expect(colorear(), hasLength(30));
  });

  test('Sesiones: verde, naranja y azul', () {
    final dias = colorear(sesiones: const {
      '2026-11-02': (estado: 'completa', esOverride: false),
      '2026-11-03': (estado: 'parcial', esOverride: false),
      '2026-11-04': (estado: 'descanso', esOverride: true),
    });
    expect(estadoDel(dias, 2), EstadoDia.completo);
    expect(estadoDel(dias, 3), EstadoDia.parcial);
    expect(estadoDel(dias, 4), EstadoDia.descanso);
    expect(dias[3].esOverride, isTrue);
  });

  test('Sin sesión: gris si tocaba entrenar, azul si era descanso o no estaba en la rutina', () {
    final dias = colorear();
    expect(estadoDel(dias, 9), EstadoDia.sinActividad); // lunes
    expect(estadoDel(dias, 13), EstadoDia.descanso); // viernes (descanso)
    expect(estadoDel(dias, 14), EstadoDia.descanso); // sábado (no está en la rutina)
  });

  test('Hoy va en tinta hasta que se entrena; los días que vienen no tienen color', () {
    var dias = colorear();
    expect(estadoDel(dias, 25), EstadoDia.hoy);
    expect(estadoDel(dias, 26), EstadoDia.futuro);
    expect(estadoDel(dias, 30), EstadoDia.futuro);

    dias = colorear(sesiones: const {'2026-11-25': (estado: 'parcial', esOverride: false)});
    expect(estadoDel(dias, 25), EstadoDia.parcial);
  });

  test('Antes del registro de la cuenta no hay color', () {
    final dias = colorear(registro: DateTime.utc(2026, 11, 10));
    expect(estadoDel(dias, 9), EstadoDia.futuro);
    expect(estadoDel(dias, 10), EstadoDia.sinActividad);
  });

  test('Sin ciclo activo, un día pasado sin sesión es gris', () {
    final dias = colorear(plantilla: const {});
    expect(estadoDel(dias, 14), EstadoDia.sinActividad);
  });

  test('Conteo para la leyenda', () {
    final mes = MesCalendario(
      anio: 2026,
      mes: 11,
      dias: colorear(sesiones: const {'2026-11-02': (estado: 'completa', esOverride: false)}),
    );
    expect(mes.conteo[EstadoDia.completo], 1);
    expect(mes.conteo[EstadoDia.futuro], 5); // del 26 al 30
  });
}
