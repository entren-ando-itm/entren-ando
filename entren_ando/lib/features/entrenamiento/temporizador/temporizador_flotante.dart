import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/diseno.dart';
import 'temporizador.dart';

/// Tarjeta del temporizador de descanso y trabajo (ENT-19 / ENT-37).
///
/// Diseño: tarjeta "DESCANSO · 01:12" de `docs/pantallas/03_ejercicio.png`.
/// La bitácora (ENT-49) la pone debajo de las series:
///
///   TemporizadorFlotante(
///     nombreEjercicio: 'Press de banca',
///     descansoSeg: 90,
///     trabajoSeg: null,
///   )
///
/// Si no hay cuenta corriendo para este ejercicio, muestra "Iniciar descanso"
/// (1 toque). La cuenta vive en `temporizadorProvider`, así que no se pierde
/// al cambiar de pantalla.
class TemporizadorFlotante extends ConsumerStatefulWidget {
  const TemporizadorFlotante({
    super.key,
    required this.nombreEjercicio,
    required this.descansoSeg,
    this.trabajoSeg,
  });

  final String nombreEjercicio;
  final int descansoSeg;
  final int? trabajoSeg;

  @override
  ConsumerState<TemporizadorFlotante> createState() => _TemporizadorFlotanteState();
}

class _TemporizadorFlotanteState extends ConsumerState<TemporizadorFlotante> {
  /// Solo redibuja la pantalla; el tiempo se calcula con la hora de fin.
  Timer? _refresco;

  @override
  void initState() {
    super.initState();
    _refresco = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted && ref.read(temporizadorProvider) != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _refresco?.cancel();
    super.dispose();
  }

  Temporizador get _control => ref.read(temporizadorProvider.notifier);

  void _iniciar() => _control.iniciar(
        nombreEjercicio: widget.nombreEjercicio,
        descansoSeg: widget.descansoSeg,
        trabajoSeg: widget.trabajoSeg,
      );

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(temporizadorProvider);

    // Sin cuenta para este ejercicio: un solo botón para empezar.
    if (estado == null || estado.nombreEjercicio != widget.nombreEjercicio) {
      return BotonSecundario(
        texto: 'Iniciar descanso',
        icono: Icons.timer_outlined,
        alPresionar: _iniciar,
      );
    }

    final colores = context.colores;
    final textos = Theme.of(context).textTheme;
    final ahora = DateTime.now();
    final restante = estado.restante(ahora);
    final terminado = estado.terminado(ahora);
    final modo = estado.modo == ModoTemporizador.descanso ? 'Descanso' : 'Trabajo';

    return Tarjeta(
      radio: Medidas.radioGrande,
      padding: const EdgeInsets.all(Medidas.espacio5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "DESCANSO · PRESS DE BANCA"
          EtiquetaSeccion(
            terminado ? '$modo terminado · ${estado.nombreEjercicio}' : '$modo · ${estado.nombreEjercicio}',
          ),
          const SizedBox(height: Medidas.espacio2),
          Semantics(
            liveRegion: true,
            label: '${estado.titulo}. Faltan ${formatoTiempo(restante)}',
            child: ExcludeSemantics(
              child: Text(
                formatoTiempo(restante),
                style: textos.displaySmall?.copyWith(
                  fontFeatures: TipografiaEntrenAndo.numerosTabulares,
                  color: estado.enPausa ? colores.tinta2 : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: Medidas.espacio3),
          BarraProgreso(valor: estado.avance(ahora), descripcion: 'Avance del $modo'),
          if (estado.tieneTrabajo) ...[
            const SizedBox(height: Medidas.espacio4),
            SelectorSegmentos<ModoTemporizador>(
              opciones: const [
                OpcionSegmento(valor: ModoTemporizador.descanso, texto: 'Descanso'),
                OpcionSegmento(valor: ModoTemporizador.trabajo, texto: 'Trabajo'),
              ],
              valor: estado.modo,
              alCambiar: _control.cambiarModo,
            ),
          ],
          const SizedBox(height: Medidas.espacio4),
          Wrap(
            spacing: Medidas.espacio2,
            runSpacing: Medidas.espacio2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              BotonChico(
                texto: '−15 s',
                nivel: 2,
                alPresionar: terminado ? null : () => _control.ajustar(-Temporizador.paso),
              ),
              BotonChico(
                texto: '+15 s',
                nivel: 2,
                alPresionar: () => _control.ajustar(Temporizador.paso),
              ),
              BotonChico(
                texto: 'Reiniciar',
                icono: Icons.replay_rounded,
                nivel: 2,
                alPresionar: _control.reiniciar,
              ),
              BotonTexto(
                texto: terminado ? 'Cerrar' : 'Saltar',
                alPresionar: _control.detener,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
