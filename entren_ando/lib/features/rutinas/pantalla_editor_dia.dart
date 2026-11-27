import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/diseno.dart';
import '../perfil/catalogo/catalogo_repositorio.dart';
import 'rutinas_proveedores.dart';
import 'rutinas_repositorio.dart';

/// Editor de un día del ciclo (ENT-47): tipo de día, nombre y ejercicios del
/// catálogo con series, repeticiones, peso, descanso y trabajo. Todo se guarda
/// al instante en la base local, sin internet.
class PantallaEditorDia extends ConsumerWidget {
  const PantallaEditorDia({super.key, required this.idCiclo, required this.idDia});

  final String idCiclo;
  final String idDia;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ciclo = ref.watch(cicloProvider(idCiclo)).value;
    final dia = ref.watch(diaRutinaProvider(idDia));
    return Scaffold(
      body: dia.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => const MensajeCentrado('No se pudo leer el día.', icono: Icons.error_outline_rounded),
        data: (datos) {
          if (datos == null || ciclo == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return _ContenidoEditor(ciclo: ciclo, dia: datos);
        },
      ),
    );
  }
}

class _ContenidoEditor extends ConsumerStatefulWidget {
  const _ContenidoEditor({required this.ciclo, required this.dia});

  final Ciclo ciclo;
  final DiaRutina dia;

  @override
  ConsumerState<_ContenidoEditor> createState() => _ContenidoEditorState();
}

class _ContenidoEditorState extends ConsumerState<_ContenidoEditor> {
  late final TextEditingController _nombre =
      TextEditingController(text: widget.dia.esDescanso && widget.dia.nombre == 'Descanso' ? '' : widget.dia.nombre);
  Timer? _espera;
  String? _error;

  bool get _soloLectura => !widget.ciclo.activo;

  /// true cuando el usuario ya eligió Rutina o Descanso en esta pantalla.
  bool _eligioTipo = false;

  /// Un día de descanso SIN ejercicios se abre en modo Rutina (sin guardar):
  /// así se pueden agregar ejercicios de inmediato. Si no se agrega ninguno,
  /// en la base sigue de descanso (agregar uno lo cambia, ver agregarEjercicio).
  bool _esDescansoVisible(DiaRutina dia, AsyncValue<List<EjercicioProgramado>> ejercicios) {
    if (_eligioTipo || _soloLectura || !dia.esDescanso) return dia.esDescanso;
    final lista = ejercicios.value;
    return lista == null || lista.isNotEmpty;
  }

  @override
  void dispose() {
    _espera?.cancel();
    _nombre.dispose();
    super.dispose();
  }

  Future<RutinasRepositorio?> _repositorio() => ref.read(rutinasRepositorioProvider.future);

  /// Ejecuta un guardado y vuelve a leer la pantalla; muestra el error si falla.
  Future<void> _guardar(Future<void> Function(RutinasRepositorio repo) accion) async {
    final repositorio = await _repositorio();
    if (repositorio == null) return;
    try {
      await accion(repositorio);
      if (mounted) setState(() => _error = null);
    } on CicloSoloLectura {
      if (mounted) setState(() => _error = 'El ciclo está archivado. Reactívalo para editarlo.');
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo guardar. Intenta de nuevo.');
    }
    refrescarRutinas(ref);
  }

  void _cambiarTipo(bool esDescanso) {
    setState(() => _eligioTipo = true);
    final nombre = _nombre.text.trim();
    _guardar((repo) => repo.actualizarDia(
          widget.dia.idDia,
          nombre: esDescanso ? (nombre.isEmpty ? 'Descanso' : nombre) : (nombre.isEmpty ? 'Entrenamiento' : nombre),
          esDescanso: esDescanso,
        ));
    if (!esDescanso && nombre.isEmpty) _nombre.text = 'Entrenamiento';
  }

  /// Guarda el nombre medio segundo después de dejar de escribir.
  void _nombreCambio(String texto) {
    _espera?.cancel();
    if (ValidarRutina.nombre(texto) != null) return;
    _espera = Timer(const Duration(milliseconds: 600), () {
      _guardar((repo) => repo.actualizarDia(widget.dia.idDia, nombre: texto, esDescanso: widget.dia.esDescanso));
    });
  }

  Future<void> _agregar() async {
    // Sin esto, al cerrar la hoja vuelve a salir el teclado del nombre del día.
    FocusScope.of(context).unfocus();
    final elegido = await mostrarHojaInferior<int>(
      context: context,
      constructor: (contexto) => const SelectorEjercicio(),
    );
    if (elegido == null) return;
    await _guardar((repo) => repo.agregarEjercicio(widget.dia.idDia, elegido));
  }

  Future<void> _editar(EjercicioProgramado ejercicio) async {
    FocusScope.of(context).unfocus();
    final repositorio = await _repositorio();
    if (repositorio == null || !mounted) return;
    final cambio = await mostrarHojaInferior<bool>(
      context: context,
      constructor: (contexto) => _HojaEjercicio(
        ejercicio: ejercicio,
        repositorio: repositorio,
        alAlternativas: () {
          Navigator.pop(contexto);
          _abrirAlternativas(ejercicio);
        },
      ),
    );
    if (cambio == true) refrescarRutinas(ref);
  }

  /// Abre las alternativas de un ejercicio (ENT-48).
  void _abrirAlternativas(EjercicioProgramado ejercicio) {
    context.push(
      '/perfil/ciclos/${widget.ciclo.idCiclo}/dia/${widget.dia.idDia}/alternativas/${ejercicio.idProgramado}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final dia = widget.dia;
    final ejercicios = ref.watch(ejerciciosDiaProvider(dia.idDia));
    final textos = Theme.of(context).textTheme;
    final error = _error;
    final lista = ejercicios.value ?? const <EjercicioProgramado>[];
    final esDescanso = _esDescansoVisible(dia, ejercicios);

    return ContenidoPantalla(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: BotonCircular(
            icono: Icons.arrow_back_rounded,
            descripcion: 'Volver',
            alPresionar: () => context.pop(),
          ),
        ),
        const SizedBox(height: Medidas.espacio4),
        EncabezadoPantalla(
          etiqueta: widget.ciclo.nombre,
          titulo: dia.nombreDiaSemana,
          subtitulo: esDescanso ? 'Descanso' : (dia.esDescanso ? 'Agrega ejercicios para tu rutina' : dia.nombre),
        ),
        const SizedBox(height: Medidas.espacio5),
        if (_soloLectura) ...[
          const Aviso('El ciclo está archivado: lo ves en solo lectura.', icono: Icons.lock_outline_rounded),
          const SizedBox(height: Medidas.espacio4),
        ] else ...[
          const EtiquetaSeccion('Tipo de día'),
          const SizedBox(height: 10),
          // En su propio renglón y con textos cortos para que quepa en celulares angostos.
          Align(
            alignment: Alignment.centerLeft,
            child: SelectorSegmentos<bool>(
              opciones: const [
                OpcionSegmento(valor: false, texto: 'Rutina'),
                OpcionSegmento(valor: true, texto: 'Descanso'),
              ],
              valor: esDescanso,
              alCambiar: _cambiarTipo,
            ),
          ),
          if (!esDescanso) ...[
            const SizedBox(height: Medidas.espacio4),
            CampoTexto(
              etiqueta: 'Nombre del día',
              controlador: _nombre,
              pista: 'Por ejemplo: Pierna',
              accionTeclado: TextInputAction.done,
              validar: ValidarRutina.nombre,
              alCambiar: _nombreCambio,
            ),
          ],
          const SizedBox(height: Medidas.espacio5),
        ],
        if (error != null) ...[
          Aviso(error, icono: Icons.error_outline_rounded),
          const SizedBox(height: Medidas.espacio4),
        ],
        if (esDescanso && !_soloLectura)
          Text(
            lista.isEmpty
                ? 'Este día es de descanso. Cámbialo a Rutina para agregar ejercicios.'
                : 'Este día es de descanso. Sus ${lista.length} ejercicios se guardan por si lo cambias.',
            style: textos.bodyMedium?.copyWith(color: context.colores.tinta2),
          )
        else ...[
          const EtiquetaSeccion('Ejercicios'),
          const SizedBox(height: 10),
          ...ejercicios.when(
            loading: () => const [Center(child: CircularProgressIndicator())],
            error: (error, _) => const [
              Aviso('No se pudieron leer los ejercicios.', icono: Icons.error_outline_rounded),
            ],
            data: (datos) => datos.isEmpty
                ? [
                    Text(
                      _soloLectura ? 'Este día no tiene ejercicios.' : 'Agrega ejercicios del catálogo.',
                      style: textos.bodyMedium?.copyWith(color: context.colores.tinta2),
                    ),
                  ]
                : [
                    for (var i = 0; i < datos.length; i++) ...[
                      _FilaEjercicio(
                        ejercicio: datos[i],
                        soloLectura: _soloLectura,
                        // En solo lectura, tocar abre sus alternativas (también en solo lectura).
                        alTocar: _soloLectura ? () => _abrirAlternativas(datos[i]) : () => _editar(datos[i]),
                        alSubir: (_soloLectura || i == 0)
                            ? null
                            : () => _guardar((repo) => repo.moverEjercicio(datos[i].idProgramado, i - 1)),
                        alBajar: (_soloLectura || i == datos.length - 1)
                            ? null
                            : () => _guardar((repo) => repo.moverEjercicio(datos[i].idProgramado, i + 1)),
                      ),
                      const SizedBox(height: Medidas.espacio2),
                    ],
                  ],
          ),
          if (!_soloLectura) ...[
            const SizedBox(height: Medidas.espacio4),
            BotonPrincipal(texto: 'Agregar ejercicio', icono: Icons.add_rounded, alPresionar: _agregar),
          ],
        ],
      ],
    );
  }
}

/// Texto corto de lo programado: "3 × 10 · 60 kg · 90 s de descanso".
String resumenProgramado(EjercicioProgramado e) {
  String numero(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  final peso = e.pesoKg;
  final trabajo = e.trabajoSeg;
  return [
    '${e.series} × ${e.repeticiones}',
    if (peso != null && peso > 0) '${numero(peso)} kg',
    if (trabajo != null) '$trabajo s de trabajo',
    '${e.descansoSeg} s de descanso',
  ].join(' · ');
}

class _FilaEjercicio extends StatelessWidget {
  const _FilaEjercicio({
    required this.ejercicio,
    required this.soloLectura,
    this.alTocar,
    this.alSubir,
    this.alBajar,
  });

  final EjercicioProgramado ejercicio;
  final bool soloLectura;
  final VoidCallback? alTocar;
  final VoidCallback? alSubir;
  final VoidCallback? alBajar;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final colores = context.colores;
    return Tarjeta(
      alTocar: alTocar,
      padding: const EdgeInsets.fromLTRB(18, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ejercicio.nombre, style: textos.titleMedium),
                if (ejercicio.nombre != ejercicio.nombreOficial)
                  Text(ejercicio.nombreOficial, style: textos.bodySmall),
                const SizedBox(height: 2),
                Text(resumenProgramado(ejercicio), style: textos.bodySmall),
                if (ejercicio.alternativas > 0)
                  Text(
                    ejercicio.alternativas == 1 ? '1 alternativa' : '${ejercicio.alternativas} alternativas',
                    style: textos.bodySmall,
                  ),
              ],
            ),
          ),
          if (!soloLectura) ...[
            IconButton(
              tooltip: 'Subir',
              icon: const Icon(Icons.keyboard_arrow_up_rounded),
              color: colores.tinta,
              disabledColor: colores.tenue,
              onPressed: alSubir,
            ),
            IconButton(
              tooltip: 'Bajar',
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              color: colores.tinta,
              disabledColor: colores.tenue,
              onPressed: alBajar,
            ),
          ],
        ],
      ),
    );
  }
}

/// Hoja para elegir un ejercicio del catálogo (con alias). Devuelve su id.
/// La usan el editor del día (ENT-47) y la vista previa de la IA (ENT-58).
class SelectorEjercicio extends ConsumerStatefulWidget {
  const SelectorEjercicio({super.key});

  @override
  ConsumerState<SelectorEjercicio> createState() => SelectorEjercicioState();
}

class SelectorEjercicioState extends ConsumerState<SelectorEjercicio> {
  String _texto = '';
  List<EjercicioCatalogo>? _resultados;
  int _consulta = 0;

  @override
  void initState() {
    super.initState();
    _buscar('');
  }

  Future<void> _buscar(String texto) async {
    _texto = texto;
    final numero = ++_consulta;
    final repositorio = await ref.read(catalogoRepositorioProvider.future);
    final resultados = await repositorio?.buscar(texto: texto) ?? const <EjercicioCatalogo>[];
    // Ignora respuestas viejas si el usuario siguió escribiendo.
    if (mounted && numero == _consulta) setState(() => _resultados = resultados);
  }

  @override
  Widget build(BuildContext context) {
    final resultados = _resultados;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EncabezadoHoja(titulo: 'Agregar ejercicio', subtitulo: 'Del catálogo, con tus alias'),
        const SizedBox(height: Medidas.espacio4),
        CampoTexto(
          etiqueta: 'Buscar',
          pista: 'Nombre o alias',
          accionTeclado: TextInputAction.search,
          alCambiar: _buscar,
        ),
        const SizedBox(height: Medidas.espacio4),
        if (resultados == null)
          const Center(child: CircularProgressIndicator())
        else if (resultados.isEmpty)
          Text('No hay ejercicios con «$_texto».', style: Theme.of(context).textTheme.bodyMedium)
        else
          for (final e in resultados.take(40)) ...[
            FilaOpcion(
              titulo: e.nombreVisible,
              descripcion: [
                if (e.tieneAlias) e.nombreOficial,
                e.grupoMuscular,
                e.nombreEquipo ?? 'Peso corporal',
              ].join(' · '),
              alTocar: () => Navigator.pop(context, e.idEjercicio),
            ),
            const SizedBox(height: Medidas.espacio2),
          ],
      ],
    );
  }
}

/// Hoja para editar series, repeticiones, peso, descanso y trabajo, o quitar
/// el ejercicio del día. Devuelve true si hubo cambio.
class _HojaEjercicio extends StatefulWidget {
  const _HojaEjercicio({required this.ejercicio, required this.repositorio, required this.alAlternativas});

  final EjercicioProgramado ejercicio;
  final RutinasRepositorio repositorio;

  /// Cierra la hoja y abre las alternativas de este ejercicio.
  final VoidCallback alAlternativas;

  @override
  State<_HojaEjercicio> createState() => _HojaEjercicioState();
}

class _HojaEjercicioState extends State<_HojaEjercicio> {
  final GlobalKey<FormState> _formulario = GlobalKey<FormState>();
  late final _series = TextEditingController(text: '${widget.ejercicio.series}');
  late final _reps = TextEditingController(text: '${widget.ejercicio.repeticiones}');
  late final _peso = TextEditingController(
    text: widget.ejercicio.pesoKg == null ? '' : _numero(widget.ejercicio.pesoKg!),
  );
  late final _descanso = TextEditingController(text: '${widget.ejercicio.descansoSeg}');
  late final _trabajo = TextEditingController(text: widget.ejercicio.trabajoSeg?.toString() ?? '');
  bool _guardando = false;
  String? _error;

  static String _numero(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  void dispose() {
    for (final c in [_series, _reps, _peso, _descanso, _trabajo]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _ejecutar(Future<void> Function() accion) async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await accion();
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = 'No se pudo guardar. Intenta de nuevo.';
        });
      }
    }
  }

  void _guardar() {
    if (!(_formulario.currentState?.validate() ?? false)) return;
    _ejecutar(() => widget.repositorio.actualizarEjercicio(
          widget.ejercicio.idProgramado,
          series: int.parse(_series.text.trim()),
          repeticiones: int.parse(_reps.text.trim()),
          pesoKg: _peso.text.trim().isEmpty ? null : double.parse(_peso.text.trim().replaceAll(',', '.')),
          descansoSeg: int.parse(_descanso.text.trim()),
          trabajoSeg: _trabajo.text.trim().isEmpty ? null : int.parse(_trabajo.text.trim()),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final ejercicio = widget.ejercicio;
    final error = _error;
    const numero = TextInputType.number;
    Widget par(Widget a, Widget b) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Expanded(child: a), const SizedBox(width: Medidas.espacio3), Expanded(child: b)],
        );
    return Form(
      key: _formulario,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EncabezadoHoja(
            titulo: ejercicio.nombre,
            subtitulo: ejercicio.nombre != ejercicio.nombreOficial
                ? 'Nombre oficial: ${ejercicio.nombreOficial}'
                : ejercicio.grupoMuscular,
          ),
          const SizedBox(height: Medidas.espacio5),
          par(
            CampoTexto(etiqueta: 'Series', controlador: _series, teclado: numero, validar: ValidarRutina.series),
            CampoTexto(
              etiqueta: 'Repeticiones',
              controlador: _reps,
              teclado: numero,
              validar: ValidarRutina.repeticiones,
            ),
          ),
          const SizedBox(height: Medidas.espacio4),
          par(
            CampoTexto(
              etiqueta: 'Peso (kg)',
              controlador: _peso,
              pista: 'Opcional',
              teclado: const TextInputType.numberWithOptions(decimal: true),
              validar: ValidarRutina.pesoKg,
            ),
            CampoTexto(
              etiqueta: 'Descanso (s)',
              controlador: _descanso,
              teclado: numero,
              validar: ValidarRutina.descansoSeg,
            ),
          ),
          const SizedBox(height: Medidas.espacio4),
          CampoTexto(
            etiqueta: 'Trabajo (s)',
            controlador: _trabajo,
            pista: 'Opcional, para ejercicios por tiempo',
            teclado: numero,
            validar: ValidarRutina.trabajoSeg,
          ),
          if (error != null) ...[
            const SizedBox(height: Medidas.espacio4),
            Aviso(error, icono: Icons.error_outline_rounded),
          ],
          const SizedBox(height: Medidas.espacio5),
          BotonPrincipal(texto: 'Guardar', icono: Icons.check_rounded, alPresionar: _guardando ? null : _guardar),
          const SizedBox(height: Medidas.espacio2),
          BotonSecundario(
            texto: ejercicio.alternativas == 0 ? 'Alternativas' : 'Alternativas (${ejercicio.alternativas})',
            icono: Icons.swap_horiz_rounded,
            alPresionar: _guardando ? null : widget.alAlternativas,
          ),
          const SizedBox(height: Medidas.espacio2),
          BotonTexto(
            texto: 'Quitar del día',
            icono: Icons.delete_outline_rounded,
            anchoCompleto: true,
            alPresionar: _guardando
                ? null
                : () => _ejecutar(() => widget.repositorio.quitarEjercicio(ejercicio.idProgramado)),
          ),
        ],
      ),
    );
  }
}
