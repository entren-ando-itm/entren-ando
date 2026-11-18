import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notificacion_temporizador.dart';

/// Lógica del temporizador de descanso y de trabajo (ENT-19 / ENT-37).
///
/// No cuenta segundos en un ciclo: guarda la **hora de fin** y en cada momento
/// calcula cuánto falta (`fin - ahora`). Así no se desfasa si la app se va a
/// segundo plano o si se bloquea la pantalla.
///
///   ref.read(temporizadorProvider.notifier).iniciar(
///     nombreEjercicio: 'Press de banca', descansoSeg: 90, trabajoSeg: null);
///   final estado = ref.watch(temporizadorProvider);
///   estado?.restante(DateTime.now());

/// Descanso entre series o trabajo (ejercicios por tiempo, como la plancha).
enum ModoTemporizador { descanso, trabajo }

/// Lo que está corriendo ahora. Es inmutable: cada cambio crea uno nuevo.
class EstadoTemporizador {
  const EstadoTemporizador({
    required this.nombreEjercicio,
    required this.modo,
    required this.descansoSeg,
    required this.trabajoSeg,
    required this.duracion,
    required this.fin,
    this.pausadoRestante,
  });

  final String nombreEjercicio;
  final ModoTemporizador modo;

  /// Segundos de descanso del ejercicio (`ejercicio_programado.descanso_seg`).
  final int descansoSeg;

  /// Segundos de trabajo (`ejercicio_programado.trabajo_seg`); null si es por repeticiones.
  final int? trabajoSeg;

  /// Duración total de esta cuenta (cambia con +15 s / −15 s). Sirve para la barra.
  final Duration duracion;

  /// Hora en que termina la cuenta.
  final DateTime fin;

  /// Si está en pausa, cuánto faltaba al pausar. null = corriendo.
  final Duration? pausadoRestante;

  bool get enPausa => pausadoRestante != null;

  /// true si el ejercicio se puede hacer por tiempo (permite el modo Trabajo).
  bool get tieneTrabajo => trabajoSeg != null && trabajoSeg! > 0;

  /// Cuánto falta. Nunca es negativo.
  Duration restante(DateTime ahora) {
    final pausa = pausadoRestante;
    if (pausa != null) return pausa;
    final falta = fin.difference(ahora);
    return falta.isNegative ? Duration.zero : falta;
  }

  bool terminado(DateTime ahora) => restante(ahora) == Duration.zero;

  /// Avance de 0 (recién empezó) a 1 (terminó), para `BarraProgreso`.
  double avance(DateTime ahora) {
    if (duracion.inMilliseconds <= 0) return 1;
    final hecho = duracion - restante(ahora);
    return (hecho.inMilliseconds / duracion.inMilliseconds).clamp(0.0, 1.0);
  }

  /// "Descanso: Press de banca" o "Trabajo: Plancha".
  String get titulo =>
      '${modo == ModoTemporizador.descanso ? 'Descanso' : 'Trabajo'}: $nombreEjercicio';

  EstadoTemporizador copiar({
    ModoTemporizador? modo,
    Duration? duracion,
    DateTime? fin,
    Duration? pausadoRestante,
    bool quitarPausa = false,
  }) {
    return EstadoTemporizador(
      nombreEjercicio: nombreEjercicio,
      modo: modo ?? this.modo,
      descansoSeg: descansoSeg,
      trabajoSeg: trabajoSeg,
      duracion: duracion ?? this.duracion,
      fin: fin ?? this.fin,
      pausadoRestante: quitarPausa ? null : (pausadoRestante ?? this.pausadoRestante),
    );
  }
}

/// Temporizador de la app: null cuando no hay ninguno corriendo.
final temporizadorProvider =
    NotifierProvider<Temporizador, EstadoTemporizador?>(Temporizador.new);

class Temporizador extends Notifier<EstadoTemporizador?> {
  /// Paso de los botones −15 s y +15 s.
  static const Duration paso = Duration(seconds: 15);

  /// Reloj que se usa para calcular. Las pruebas lo pueden cambiar.
  DateTime Function() reloj = DateTime.now;

  @override
  EstadoTemporizador? build() => null;

  /// Cada cambio de estado reprograma (o quita) la notificación de fin (ENT-38).
  void _poner(EstadoTemporizador? nuevo) {
    state = nuevo;
    final aviso = ref.read(notificacionTemporizadorProvider);
    if (nuevo == null || nuevo.enPausa) {
      aviso.cancelar();
    } else {
      aviso.programar(fin: nuevo.fin, titulo: nuevo.titulo);
    }
  }

  /// Empieza una cuenta nueva (1 toque desde la bitácora).
  void iniciar({
    required String nombreEjercicio,
    required int descansoSeg,
    int? trabajoSeg,
    ModoTemporizador modo = ModoTemporizador.descanso,
  }) {
    final segundos = _segundosDe(modo, descansoSeg, trabajoSeg);
    final duracion = Duration(seconds: segundos);
    _poner(EstadoTemporizador(
      nombreEjercicio: nombreEjercicio,
      modo: modo,
      descansoSeg: descansoSeg,
      trabajoSeg: trabajoSeg,
      duracion: duracion,
      fin: reloj().add(duracion),
    ));
  }

  /// +15 s o −15 s. Con −15 s nunca baja de 0.
  void ajustar(Duration cambio) {
    final actual = state;
    if (actual == null) return;
    final ahora = reloj();
    final restante = actual.restante(ahora) + cambio;
    final nuevoRestante = restante.isNegative ? Duration.zero : restante;
    final nuevaDuracion = actual.duracion + cambio;
    _poner(actual.copiar(
      duracion: nuevaDuracion.isNegative ? Duration.zero : nuevaDuracion,
      fin: ahora.add(nuevoRestante),
      pausadoRestante: actual.enPausa ? nuevoRestante : null,
    ));
  }

  /// Vuelve a empezar la cuenta del modo actual desde el principio.
  void reiniciar() {
    final actual = state;
    if (actual == null) return;
    cambiarModo(actual.modo);
  }

  /// Cambia entre Descanso y Trabajo y empieza la cuenta de ese modo.
  void cambiarModo(ModoTemporizador modo) {
    final actual = state;
    if (actual == null) return;
    if (modo == ModoTemporizador.trabajo && !actual.tieneTrabajo) return;
    iniciar(
      nombreEjercicio: actual.nombreEjercicio,
      descansoSeg: actual.descansoSeg,
      trabajoSeg: actual.trabajoSeg,
      modo: modo,
    );
  }

  /// Pausa o sigue la cuenta.
  void pausarOSeguir() {
    final actual = state;
    if (actual == null) return;
    final ahora = reloj();
    final pausa = actual.pausadoRestante;
    _poner(pausa == null
        ? actual.copiar(pausadoRestante: actual.restante(ahora))
        : actual.copiar(fin: ahora.add(pausa), quitarPausa: true));
  }

  /// Quita el temporizador ("Saltar" o al terminar).
  void detener() => _poner(null);

  static int _segundosDe(ModoTemporizador modo, int descansoSeg, int? trabajoSeg) {
    if (modo == ModoTemporizador.trabajo && trabajoSeg != null && trabajoSeg > 0) {
      return trabajoSeg;
    }
    return descansoSeg > 0 ? descansoSeg : 90; // 90 s es el valor por defecto del esquema.
  }
}

/// "1:30", "0:05" o "12:00" para mostrar en pantalla.
String formatoTiempo(Duration tiempo) {
  // Redondea hacia arriba: con 0.4 s restantes se ve 0:01, no 0:00.
  final segundos = (tiempo.inMilliseconds / 1000).ceil();
  final minutos = segundos ~/ 60;
  final resto = (segundos % 60).toString().padLeft(2, '0');
  return '$minutos:$resto';
}
