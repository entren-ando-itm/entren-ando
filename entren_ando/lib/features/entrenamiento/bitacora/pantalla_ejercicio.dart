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
/// * ENT-121: las series se muestran una por una y se marcan en orden; solo se
///   quita el ✓ de la última. "Terminar ejercicio" con un toque completa las
///   que faltan; manteniéndolo presionado termina solo con las hechas.
///
/// * "Cambiar solo hoy" (ENT-59): cambia el ejercicio por una alternativa solo
///   hoy; sin alternativas, el botón no aparece.
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
    final total = series.length;
    final hechas = series.where((s) => s.guardada).toList();
    // ENT-121: una por una. La actual es la primera sin guardar; se marcan en orden.
    final actual = series.where((s) => !s.guardada).firstOrNull;
    final ultimaHecha = hechas.lastOrNull?.numero;

    return ContenidoPantalla(
      children: [
        _Encabezado(
          idProgramado: widget.idProgramado,
          accion: _botonCambiar(ejercicio),
        ),
        const SizedBox(height: Medidas.espacio5),
        EtiquetaSeccion(_etiqueta(ejercicio)),
        const SizedBox(height: Medidas.espacio2),
        Text(ejercicio.nombre.toUpperCase(), style: textos.headlineMedium),
        const SizedBox(height: Medidas.espacio1),
        Text(_vezPasada(ejercicio), style: textos.bodyMedium),
        if (ejercicio.esSustitucion) ...[
          const SizedBox(height: Medidas.espacio1),
          Text(
            'Solo hoy, en lugar de ${ejercicio.nombreOriginal}',
            style: textos.bodySmall,
          ),
        ],
        const SizedBox(height: Medidas.espacio5),
        BarraProgreso(
          valor: total == 0 ? 0 : hechas.length / total,
          descripcion: '${hechas.length} de $total series',
        ),
        const SizedBox(height: Medidas.espacio2),
        Text('${hechas.length} de $total series', style: textos.bodySmall),
        const SizedBox(height: Medidas.espacio4),
        // Las hechas: se puede corregir el peso o las reps de cualquiera, y
        // quitar el ✓ solo de la última (para no dejar huecos).
        for (final serie in hechas) ...[
          _FilaSerie(
            serie: serie,
            resaltada: false,
            alTocarNumeros: () => _ajustar(ejercicio, serie),
            // Terminado: para quitar series primero hay que volver a abrirlo.
            alMarcar: _guardando || ejercicio.completado || serie.numero != ultimaHecha
                ? null
                : () => _marcar(ejercicio, serie),
          ),
          const SizedBox(height: Medidas.espacio2),
        ],
        if (actual != null && !ejercicio.completado) ...[
          EtiquetaSeccion('Serie ${actual.numero} de $total'),
          const SizedBox(height: Medidas.espacio2),
          _FilaSerie(
            serie: actual,
            resaltada: true,
            alTocarNumeros: () => _ajustar(ejercicio, actual),
            alMarcar: _guardando ? null : () => _marcar(ejercicio, actual),
          ),
          if (total - actual.numero > 0) ...[
            const SizedBox(height: Medidas.espacio2),
            Text(
              total - actual.numero == 1 ? 'Después queda 1 serie' : 'Después quedan ${total - actual.numero} series',
              style: textos.bodySmall,
            ),
          ],
        ] else if (actual == null && !ejercicio.completado)
          const Aviso('Hiciste todas las series. Toca Terminar ejercicio.', icono: Icons.check_circle_outline_rounded),
        const SizedBox(height: Medidas.espacio4),
        TemporizadorFlotante(
          nombreEjercicio: ejercicio.nombre,
          descansoSeg: ejercicio.descansoSeg,
          trabajoSeg: ejercicio.trabajoSeg,
          detalle: _serieDelDescanso == null
              ? null
              : 'Empezó al marcar la serie $_serieDelDescanso',
        ),
        const SizedBox(height: Medidas.espacio5),
        if (ejercicio.completado) ...[
          Aviso(
            hechas.length >= total
                ? 'Ejercicio terminado.'
                : 'Terminaste con ${hechas.length} de $total series.',
            icono: Icons.check_circle_outline_rounded,
          ),
          BotonTexto(
            texto: 'Volver a abrir',
            anchoCompleto: true,
            alPresionar: _guardando ? null : () => _reabrir(ejercicio),
          ),
        ] else ...[
          // Un toque: completa las series que faltan. Mantener presionado:
          // terminar solo con las series hechas (ENT-121).
          GestureDetector(
            onLongPress: _guardando ? null : () => _terminarParcial(ejercicio, hechas.length, total),
            child: BotonSecundario(
              texto: 'Terminar ejercicio',
              nivel: 2,
              grande: true,
              alPresionar: _guardando ? null : () => _terminarCompleto(ejercicio),
            ),
          ),
          const SizedBox(height: Medidas.espacio2),
          Text(
            'Mantén presionado para terminar solo con las series que hiciste.',
            textAlign: TextAlign.center,
            style: textos.bodySmall,
          ),
        ],
      ],
    );
  }

  void _refrescar(String idProgramado) {
    ref.invalidate(ejercicioBitacoraProvider(idProgramado));
    ref.invalidate(diaDeHoyProvider);
    ref.invalidate(sesionDeHoyProvider);
  }

  void _avisarError(String accion, Object error) {
    if (!mounted) return;
    final mensaje = error is SerieFueraDeOrden ? error.mensaje : 'No se pudo $accion: $error';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  /// Un toque en "Terminar ejercicio": guarda las series que faltan con lo que
  /// muestra la pantalla y lo marca completo; regresa a Hoy.
  Future<void> _terminarCompleto(EjercicioBitacora ejercicio) async {
    final repositorio = await ref.read(bitacoraRepositorioProvider.future);
    if (repositorio == null) return;
    setState(() => _guardando = true);
    try {
      await repositorio.terminarCompleto(ejercicio.idProgramado, ajustes: Map.of(_ajustes));
      _ajustes.clear();
      ref.read(temporizadorProvider.notifier).detener();
      _refrescar(ejercicio.idProgramado);
      if (mounted) Navigator.of(context).maybePop();
    } catch (error) {
      _avisarError('terminar el ejercicio', error);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  /// Mantener presionado: confirma y termina solo con las series hechas.
  Future<void> _terminarParcial(EjercicioBitacora ejercicio, int hechas, int total) async {
    final seguro = await mostrarHojaInferior<bool>(
      context: context,
      constructor: (contexto) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EncabezadoHoja(
            titulo: 'Terminar con $hechas de $total series',
            subtitulo: hechas == 0
                ? 'No se guarda ninguna serie de este ejercicio. Tu día cuenta como completo si haces al menos el 80% de sus series.'
                : 'Se guardan solo las series que marcaste. Tu día cuenta como completo si haces al menos el 80% de sus series.',
          ),
          const SizedBox(height: Medidas.espacio5),
          BotonSecundario(
            texto: 'Terminar así',
            nivel: 2,
            alPresionar: () => Navigator.pop(contexto, true),
          ),
          const SizedBox(height: Medidas.espacio2),
          BotonTexto(texto: 'Seguir con el ejercicio', anchoCompleto: true, alPresionar: () => Navigator.pop(contexto)),
        ],
      ),
    );
    if (seguro != true || !mounted) return;
    final repositorio = await ref.read(bitacoraRepositorioProvider.future);
    if (repositorio == null) return;
    setState(() => _guardando = true);
    try {
      await repositorio.completarEjercicio(ejercicio.idProgramado);
      _ajustes.clear();
      ref.read(temporizadorProvider.notifier).detener();
      _refrescar(ejercicio.idProgramado);
      if (mounted) Navigator.of(context).maybePop();
    } catch (error) {
      _avisarError('terminar el ejercicio', error);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  /// "Volver a abrir": el ejercicio regresa a en curso.
  Future<void> _reabrir(EjercicioBitacora ejercicio) async {
    final repositorio = await ref.read(bitacoraRepositorioProvider.future);
    if (repositorio == null) return;
    setState(() => _guardando = true);
    try {
      await repositorio.completarEjercicio(ejercicio.idProgramado, completado: false);
      _refrescar(ejercicio.idProgramado);
    } catch (error) {
      _avisarError('volver a abrir el ejercicio', error);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  /// "Cambiar solo hoy" (ENT-59). No aparece si el ejercicio no tiene alternativas.
  Widget? _botonCambiar(EjercicioBitacora ejercicio) {
    final alternativas = ref.watch(alternativasProvider(widget.idProgramado)).value ?? const [];
    if (alternativas.isEmpty) return null;
    return BotonChico(
      texto: 'Cambiar solo hoy',
      icono: Icons.swap_horiz_rounded,
      alPresionar: _guardando ? null : () => _cambiar(ejercicio, alternativas),
    );
  }

  /// Hoja con las alternativas (por prioridad) y, si ya se cambió, el original.
  Future<void> _cambiar(EjercicioBitacora ejercicio, List<AlternativaEjercicio> alternativas) async {
    final conSeries = ejercicio.seriesGuardadas > 0;
    final elegido = await mostrarHojaInferior<int>(
      context: context,
      constructor: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const EncabezadoHoja(
            titulo: 'Cambiar solo hoy',
            subtitulo: 'Mañana y tu rutina siguen con el ejercicio original',
          ),
          const SizedBox(height: Medidas.espacio4),
          if (conSeries) ...[
            const Aviso(
              'Ya guardaste series de este ejercicio. Quítales la ✓ para poder cambiarlo.',
              icono: Icons.info_outline_rounded,
            ),
            const SizedBox(height: Medidas.espacio4),
          ],
          if (ejercicio.esSustitucion && ejercicio.idEjercicioOriginal != null)
            FilaOpcion(
              titulo: ejercicio.nombreOriginal ?? 'Ejercicio original',
              descripcion: 'El de tu rutina',
              inicio: Icon(Icons.undo_rounded, size: 22, color: context.colores.tinta2),
              alTocar: conSeries
                  ? null
                  : () => Navigator.pop(context, ejercicio.idEjercicioOriginal),
            ),
          for (final alternativa in alternativas)
            FilaOpcion(
              titulo: alternativa.nombre,
              descripcion: alternativa.equipo ?? 'Peso corporal',
              seleccionada: alternativa.idEjercicio == ejercicio.idEjercicio,
              alTocar: conSeries ? null : () => Navigator.pop(context, alternativa.idEjercicio),
            ),
        ],
      ),
    );
    if (elegido == null || !mounted) return;

    final repositorio = await ref.read(bitacoraRepositorioProvider.future);
    if (repositorio == null) return;
    setState(() => _guardando = true);
    try {
      await repositorio.sustituir(idProgramado: widget.idProgramado, idEjercicio: elegido);
      _ajustes.clear();
      ref.read(temporizadorProvider.notifier).detener();
      ref.invalidate(ejercicioBitacoraProvider(widget.idProgramado));
      ref.invalidate(diaDeHoyProvider);
      ref.invalidate(sesionDeHoyProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo cambiar el ejercicio: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
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
      _refrescar(ejercicio.idProgramado);
    } catch (error) {
      _avisarError('guardar la serie', error);
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
      _refrescar(ejercicio.idProgramado);
    } else {
      setState(() => _ajustes[serie.numero] = nueva);
    }
  }
}

/// "120" o "62.5": sin ".0" en los pesos enteros.
String formatoKg(double kg) => kg % 1 == 0 ? kg.toStringAsFixed(0) : kg.toStringAsFixed(1);

/// Botón Volver y "2 de 5".
class _Encabezado extends ConsumerWidget {
  const _Encabezado({required this.idProgramado, this.accion});

  final String idProgramado;

  /// "Cambiar solo hoy" a la derecha, como en el diseño.
  final Widget? accion;

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
        const Spacer(),
        ?accion,
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
