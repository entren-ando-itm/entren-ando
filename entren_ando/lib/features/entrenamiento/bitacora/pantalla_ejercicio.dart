import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/diseno.dart';
import '../hoy_repositorio.dart';
import '../temporizador/temporizador.dart';
import '../temporizador/temporizador_flotante.dart';
import 'bitacora_repositorio.dart';

/// Pantalla del ejercicio: bitácora rápida (ENT-49 / ENT-89, RF-03, RNF-03).
///
/// Diseño: `docs/pantallas/03_ejercicio.png`. Se abre desde "Seguir entrenando"
/// en la pestaña Hoy (`/hoy/ejercicio/:idProgramado`), sin la barra de abajo.
///
/// * Cada serie viene precargada (ENT-88). Con **1 toque** en el círculo queda
///   guardada (ENT-87) y empieza el descanso solo: nunca más de 2 toques.
/// * Tocar los números abre una hoja con + y − para ajustar antes de confirmar.
/// * Todo se guarda en la base local: funciona en modo avión (RNF-01).
///
/// Pendiente en otras historias: "Terminar ejercicio" (ENT-50) y
/// "Cambiar solo hoy" (ENT-59).
class PantallaEjercicio extends ConsumerStatefulWidget {
  const PantallaEjercicio({super.key, required this.idProgramado});

  final String idProgramado;

  @override
  ConsumerState<PantallaEjercicio> createState() => _PantallaEjercicioState();
}

class _PantallaEjercicioState extends ConsumerState<PantallaEjercicio> {
  /// Cambios con + y − que todavía no se confirman con el círculo.
  final Map<int, SerieBitacora> _ajustes = {};

  /// Evita dobles toques mientras se guarda.
  bool _guardando = false;

  /// Serie que inició el descanso actual ("Empezó al marcar la serie 2").
  int? _serieDelDescanso;

  @override
  Widget build(BuildContext context) {
    final ejercicio = ref.watch(ejercicioBitacoraProvider(widget.idProgramado));

    return Scaffold(
      body: ejercicio.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => MensajeCentrado(
          'No se pudo leer la bitácora.\n$error',
          icono: Icons.error_outline_rounded,
        ),
        data: (datos) {
          if (datos == null) {
            return const MensajeCentrado('Este ejercicio ya no está en tu rutina.');
          }
          return _contenido(context, datos);
        },
      ),
    );
  }

  Widget _contenido(BuildContext context, EjercicioBitacora ejercicio) {
    final textos = Theme.of(context).textTheme;
    final series = [for (final s in ejercicio.series) _ajustes[s.numero] ?? s];
    // La que sigue es la primera sin guardar: va resaltada.
    final siguiente = series.where((s) => !s.guardada).firstOrNull?.numero;

    return ContenidoPantalla(
      children: [
        _Encabezado(idProgramado: widget.idProgramado),
        const SizedBox(height: Medidas.espacio5),
        EtiquetaSeccion(_etiqueta(ejercicio)),
        const SizedBox(height: Medidas.espacio2),
        Text(ejercicio.nombre.toUpperCase(), style: textos.headlineMedium),
        const SizedBox(height: Medidas.espacio1),
        Text(_vezPasada(ejercicio), style: textos.bodyMedium),
        const SizedBox(height: Medidas.espacio5),
        for (final serie in series) ...[
          _FilaSerie(
            serie: serie,
            resaltada: serie.numero == siguiente,
            alTocarNumeros: () => _ajustar(ejercicio, serie),
            alMarcar: _guardando ? null : () => _marcar(ejercicio, serie),
          ),
          const SizedBox(height: Medidas.espacio2),
        ],
        const SizedBox(height: Medidas.espacio4),
        TemporizadorFlotante(
          nombreEjercicio: ejercicio.nombre,
          descansoSeg: ejercicio.descansoSeg,
          trabajoSeg: ejercicio.trabajoSeg,
          detalle: _serieDelDescanso == null
              ? null
              : 'Empezó al marcar la serie $_serieDelDescanso',
        ),
      ],
    );
  }

  /// "PIERNA · PRENSA · COMPUESTO" (los componentes ponen las mayúsculas).
  static String _etiqueta(EjercicioBitacora e) {
    return [
      e.grupoMuscular,
      e.equipo ?? 'Peso corporal',
      e.tipoMovimiento,
    ].where((t) => t.isNotEmpty).join(' · ');
  }

  /// "La vez pasada: 4 × 12 con 120 kg" o, si nunca lo hizo, el objetivo.
  static String _vezPasada(EjercicioBitacora e) {
    final ultima = e.ultimaVez;
    if (ultima.isEmpty) {
      final primera = e.series.firstOrNull;
      if (primera == null) return 'Primera vez';
      final peso = primera.pesoKg > 0 ? ' con ${formatoKg(primera.pesoKg)} kg' : '';
      return 'Primera vez · objetivo ${e.series.length} × ${primera.repeticiones}$peso';
    }
    final pesoMax = ultima.map((s) => s.pesoKg).reduce((a, b) => a > b ? a : b);
    final peso = pesoMax > 0 ? ' con ${formatoKg(pesoMax)} kg' : '';
    return 'La vez pasada: ${ultima.length} × ${ultima.first.repeticiones}$peso';
  }

  /// 1 toque: guarda la serie y empieza el descanso. Si ya estaba, quita el ✓.
  Future<void> _marcar(EjercicioBitacora ejercicio, SerieBitacora serie) async {
    final repositorio = await ref.read(bitacoraRepositorioProvider.future);
    if (repositorio == null) return;
    setState(() => _guardando = true);
    try {
      if (serie.guardada) {
        await repositorio.quitarSerie(idProgramado: ejercicio.idProgramado, numero: serie.numero);
      } else {
        await repositorio.guardarSerie(
          idProgramado: ejercicio.idProgramado,
          numero: serie.numero,
          pesoKg: serie.pesoKg,
          repeticiones: serie.repeticiones,
        );
        // Empieza el descanso solo: el segundo toque es para ajustarlo o saltarlo.
        ref.read(temporizadorProvider.notifier).iniciar(
              nombreEjercicio: ejercicio.nombre,
              descansoSeg: ejercicio.descansoSeg,
              trabajoSeg: ejercicio.trabajoSeg,
            );
        _serieDelDescanso = serie.numero;
      }
      _ajustes.remove(serie.numero);
      ref.invalidate(ejercicioBitacoraProvider(ejercicio.idProgramado));
      ref.invalidate(diaDeHoyProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar la serie: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  /// Hoja con + y − para el peso y las repeticiones de una serie.
  Future<void> _ajustar(EjercicioBitacora ejercicio, SerieBitacora serie) async {
    final nueva = await mostrarHojaInferior<SerieBitacora>(
      context: context,
      constructor: (context) => _HojaAjuste(serie: serie),
    );
    if (nueva == null || !mounted) return;
    if (serie.guardada) {
      // Ya estaba guardada: se actualiza en la base al confirmar.
      final repositorio = await ref.read(bitacoraRepositorioProvider.future);
      await repositorio?.guardarSerie(
        idProgramado: ejercicio.idProgramado,
        numero: serie.numero,
        pesoKg: nueva.pesoKg,
        repeticiones: nueva.repeticiones,
      );
      ref.invalidate(ejercicioBitacoraProvider(ejercicio.idProgramado));
    } else {
      setState(() => _ajustes[serie.numero] = nueva);
    }
  }
}

/// "120" o "62.5": sin ".0" en los pesos enteros.
String formatoKg(double kg) => kg % 1 == 0 ? kg.toStringAsFixed(0) : kg.toStringAsFixed(1);

/// Botón Volver y "2 de 5".
class _Encabezado extends ConsumerWidget {
  const _Encabezado({required this.idProgramado});

  final String idProgramado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ejercicios = ref.watch(diaDeHoyProvider).value?.ejercicios ?? const [];
    final posicion = ejercicios.indexWhere((e) => e.idProgramado == idProgramado);
    return Row(
      children: [
        BotonCircular(
          icono: Icons.arrow_back_rounded,
          descripcion: 'Volver',
          alPresionar: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: Medidas.espacio4),
        if (posicion >= 0)
          Text(
            '${posicion + 1} de ${ejercicios.length}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.colores.tinta2),
          ),
      ],
    );
  }
}

/// Una serie: número, peso, repeticiones y el círculo para guardarla.
class _FilaSerie extends StatelessWidget {
  const _FilaSerie({
    required this.serie,
    required this.resaltada,
    required this.alTocarNumeros,
    required this.alMarcar,
  });

  final SerieBitacora serie;

  /// La serie que sigue: fondo oscuro, como en el diseño.
  final bool resaltada;
  final VoidCallback alTocarNumeros;
  final VoidCallback? alMarcar;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final textos = Theme.of(context).textTheme;
    final tinta = resaltada ? colores.botonTexto : colores.tinta;
    final tinta2 = resaltada ? colores.botonTexto : colores.tinta2;

    return Tarjeta(
      color: resaltada ? colores.boton : null,
      radio: Medidas.radioCampo,
      padding: const EdgeInsets.only(left: Medidas.espacio4, right: Medidas.espacio1),
      child: SizedBox(
        height: Medidas.altoFila + 4,
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text('${serie.numero}', style: textos.titleMedium?.copyWith(color: tinta2)),
            ),
            // Tocar los números abre la hoja con + y −.
            Expanded(
              child: Semantics(
                button: true,
                label: 'Serie ${serie.numero}: ${formatoKg(serie.pesoKg)} kilos, '
                    '${serie.repeticiones} repeticiones. Toca para ajustar.',
                child: InkWell(
                  onTap: alTocarNumeros,
                  borderRadius: BorderRadius.circular(Medidas.radioInterno),
                  child: ExcludeSemantics(
                    child: Row(
                      children: [
                        NumeroConUnidad(
                          numero: formatoKg(serie.pesoKg),
                          unidad: 'kg',
                          tamano: 22,
                          color: tinta,
                        ),
                        const SizedBox(width: Medidas.espacio4),
                        NumeroConUnidad(
                          numero: '${serie.repeticiones}',
                          unidad: 'reps',
                          tamano: 22,
                          color: tinta,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _CirculoMarcar(guardada: serie.guardada, resaltada: resaltada, alTocar: alMarcar),
          ],
        ),
      ),
    );
  }
}

/// Círculo de 40 dentro de un área de toque de 48: verde con ✓ si está guardada.
class _CirculoMarcar extends StatelessWidget {
  const _CirculoMarcar({required this.guardada, required this.resaltada, required this.alTocar});

  final bool guardada;
  final bool resaltada;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final fondo = guardada
        ? ColoresSemaforo.completa
        : (resaltada ? colores.botonTexto : colores.sup2);
    final icono = guardada ? colores.fondo : colores.boton;

    return Semantics(
      button: true,
      checked: guardada,
      label: guardada ? 'Serie guardada. Toca para quitarla' : 'Guardar serie',
      child: InkResponse(
        onTap: alTocar,
        radius: 26,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: fondo, shape: BoxShape.circle),
              child: (guardada || resaltada)
                  ? Icon(Icons.check_rounded, size: 22, color: icono)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// Hoja para ajustar peso (de 2.5 en 2.5 kg) y repeticiones con + y −.
class _HojaAjuste extends StatefulWidget {
  const _HojaAjuste({required this.serie});

  final SerieBitacora serie;

  @override
  State<_HojaAjuste> createState() => _HojaAjusteState();
}

class _HojaAjusteState extends State<_HojaAjuste> {
  static const double _pasoKg = 2.5;

  late double _peso = widget.serie.pesoKg;
  late int _reps = widget.serie.repeticiones;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EncabezadoHoja(titulo: 'Serie ${widget.serie.numero}', subtitulo: 'Ajusta antes de guardar'),
        const SizedBox(height: Medidas.espacio5),
        _Ajustador(
          etiqueta: 'Peso',
          valor: formatoKg(_peso),
          unidad: 'kg',
          alRestar: _peso <= 0 ? null : () => setState(() => _peso = (_peso - _pasoKg).clamp(0.0, 999.0)),
          alSumar: () => setState(() => _peso += _pasoKg),
        ),
        const SizedBox(height: Medidas.espacio4),
        _Ajustador(
          etiqueta: 'Repeticiones',
          valor: '$_reps',
          unidad: 'reps',
          alRestar: _reps <= 0 ? null : () => setState(() => _reps--),
          alSumar: () => setState(() => _reps++),
        ),
        const SizedBox(height: Medidas.espacio5),
        BotonSecundario(
          texto: 'Listo',
          nivel: 2,
          alPresionar: () => Navigator.pop(
            context,
            widget.serie.copiar(pesoKg: _peso, repeticiones: _reps),
          ),
        ),
      ],
    );
  }
}

/// "PESO   −   120 kg   +"
class _Ajustador extends StatelessWidget {
  const _Ajustador({
    required this.etiqueta,
    required this.valor,
    required this.unidad,
    required this.alRestar,
    required this.alSumar,
  });

  final String etiqueta;
  final String valor;
  final String unidad;
  final VoidCallback? alRestar;
  final VoidCallback alSumar;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: EtiquetaSeccion(etiqueta)),
        BotonCircular(
          icono: Icons.remove_rounded,
          descripcion: 'Menos $etiqueta',
          nivel: 2,
          alPresionar: alRestar,
        ),
        SizedBox(
          width: 110,
          child: Center(child: NumeroConUnidad(numero: valor, unidad: unidad, tamano: 28)),
        ),
        BotonCircular(
          icono: Icons.add_rounded,
          descripcion: 'Más $etiqueta',
          nivel: 2,
          alPresionar: alSumar,
        ),
      ],
    );
  }
}
