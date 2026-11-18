import 'package:entren_ando/features/entrenamiento/temporizador/notificacion_temporizador.dart';
import 'package:entren_ando/features/entrenamiento/temporizador/temporizador.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pruebas del temporizador (ENT-19). No necesitan emulador: el reloj se
/// controla a mano y la notificación es falsa.
class _NotificacionFalsa extends NotificacionTemporizador {
  int programadas = 0;
  int canceladas = 0;
  DateTime? ultimaHoraFin;

  @override
  Future<void> programar({required DateTime fin, required String titulo}) async {
    programadas++;
    ultimaHoraFin = fin;
  }

  @override
  Future<void> cancelar() async => canceladas++;
}

void main() {
  late ProviderContainer contenedor;
  late _NotificacionFalsa aviso;
  late DateTime ahora;
  late Temporizador temporizador;

  EstadoTemporizador estado() => contenedor.read(temporizadorProvider)!;

  setUp(() {
    aviso = _NotificacionFalsa();
    contenedor = ProviderContainer(
      overrides: [notificacionTemporizadorProvider.overrideWithValue(aviso)],
    );
    ahora = DateTime(2026, 11, 17, 7, 0, 0);
    temporizador = contenedor.read(temporizadorProvider.notifier)..reloj = () => ahora;
  });

  tearDown(() => contenedor.dispose());

  test('Iniciar descanso: título, 01:30 y programa el aviso a la hora de fin', () {
    temporizador.iniciar(nombreEjercicio: 'Press de banca', descansoSeg: 90);
    expect(estado().titulo, 'Descanso: Press de banca');
    expect(formatoTiempo(estado().restante(ahora)), '01:30');
    expect(aviso.programadas, 1);
    expect(aviso.ultimaHoraFin, ahora.add(const Duration(seconds: 90)));
  });

  test('Cuenta con la hora de fin aunque pase el tiempo en segundo plano', () {
    temporizador.iniciar(nombreEjercicio: 'Sentadilla', descansoSeg: 90);
    ahora = ahora.add(const Duration(seconds: 20));
    expect(formatoTiempo(estado().restante(ahora)), '01:10');
  });

  test('+15 s y −15 s ajustan al instante y nunca baja de 0', () {
    temporizador.iniciar(nombreEjercicio: 'Remo', descansoSeg: 20);
    temporizador.ajustar(Temporizador.paso);
    expect(estado().restante(ahora), const Duration(seconds: 35));
    temporizador.ajustar(-Temporizador.paso);
    temporizador.ajustar(-Temporizador.paso);
    temporizador.ajustar(-Temporizador.paso);
    expect(estado().restante(ahora), Duration.zero);
    expect(estado().terminado(ahora), isTrue);
    expect(estado().duracion.isNegative, isFalse);
  });

  test('Pausa congela la cuenta y cancela el aviso; seguir lo reprograma', () {
    temporizador.iniciar(nombreEjercicio: 'Remo', descansoSeg: 60);
    ahora = ahora.add(const Duration(seconds: 10));
    temporizador.pausarOSeguir();
    expect(estado().enPausa, isTrue);
    expect(aviso.canceladas, 1);

    ahora = ahora.add(const Duration(minutes: 5));
    expect(estado().restante(ahora), const Duration(seconds: 50));

    temporizador.pausarOSeguir();
    expect(estado().enPausa, isFalse);
    expect(aviso.ultimaHoraFin, ahora.add(const Duration(seconds: 50)));
  });

  test('Modo Trabajo usa trabajo_seg y solo existe si el ejercicio es por tiempo', () {
    temporizador.iniciar(nombreEjercicio: 'Plancha', descansoSeg: 60, trabajoSeg: 45);
    temporizador.cambiarModo(ModoTemporizador.trabajo);
    expect(estado().titulo, 'Trabajo: Plancha');
    expect(estado().restante(ahora), const Duration(seconds: 45));

    temporizador.iniciar(nombreEjercicio: 'Remo', descansoSeg: 60);
    temporizador.cambiarModo(ModoTemporizador.trabajo);
    expect(estado().modo, ModoTemporizador.descanso);
  });

  test('Saltar quita el temporizador y cancela el aviso', () {
    temporizador.iniciar(nombreEjercicio: 'Remo', descansoSeg: 60);
    temporizador.detener();
    expect(contenedor.read(temporizadorProvider), isNull);
    expect(aviso.canceladas, 1);
  });

  test('Formato con dos dígitos, como el diseño', () {
    expect(formatoTiempo(const Duration(seconds: 72)), '01:12');
    expect(formatoTiempo(const Duration(milliseconds: 400)), '00:01');
    expect(formatoTiempo(Duration.zero), '00:00');
    expect(formatoTiempo(const Duration(minutes: 12)), '12:00');
  });
}
