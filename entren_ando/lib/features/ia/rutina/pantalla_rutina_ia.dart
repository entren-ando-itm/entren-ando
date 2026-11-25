import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/diseno.dart';
import '../../rutinas/hoja_limite_ciclos.dart';
import '../../rutinas/pantalla_editor_dia.dart';
import '../../rutinas/rutinas_proveedores.dart';
import '../../rutinas/rutinas_repositorio.dart';
import 'rutina_ia_repositorio.dart';

/// Generar la rutina inicial con IA y editarla antes de guardar (ENT-58).
///
/// 1. Pide la propuesta a la función generar-rutina (con indicador de carga).
/// 2. Muestra la semana y deja cambiar, quitar o agregar ejercicios, series y
///    repeticiones. Todo es en memoria: no se guarda nada hasta "Guardar".
/// 3. Guarda el ciclo con origen 'ia' respetando el límite del plan (RN-01).
class PantallaRutinaIa extends ConsumerStatefulWidget {
  const PantallaRutinaIa({super.key});

  @override
  ConsumerState<PantallaRutinaIa> createState() => _PantallaRutinaIaState();
}

class _PantallaRutinaIaState extends ConsumerState<PantallaRutinaIa> {
  PropuestaRutina? _propuesta;
  ErrorRutinaIa? _error;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _generar();
  }

  Future<void> _generar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final repositorio = await ref.read(rutinaIaRepositorioProvider.future);
      if (repositorio == null) throw const ErrorRutinaIa(MensajesRutinaIa.sinNube);
      final propuesta = await repositorio.generar();
      if (mounted) setState(() => _propuesta = propuesta);
    } on ErrorRutinaIa catch (e) {
      if (mounted) setState(() => _error = e);
    } catch (_) {
      if (mounted) setState(() => _error = const ErrorRutinaIa(MensajesRutinaIa.generico));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final propuesta = _propuesta;
    final error = _error;
    return Scaffold(
      body: ContenidoPantalla(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: BotonCircular(
              icono: Icons.close_rounded,
              descripcion: 'Cerrar sin guardar',
              alPresionar: () => context.pop(),
            ),
          ),
          const SizedBox(height: Medidas.espacio4),
          if (_cargando) ..._cargandoVista(context)
          else if (error != null) ..._errorVista(context, error)
          else if (propuesta != null) _VistaPrevia(propuesta: propuesta),
        ],
      ),
    );
  }

  List<Widget> _cargandoVista(BuildContext context) => [
        const EncabezadoPantalla(
          etiqueta: 'Rutina con IA',
          titulo: 'Armando tu semana',
          subtitulo: 'La IA usa tu perfil, tu medición y tu equipo. Puede tardar hasta 30 segundos.',
        ),
        const SizedBox(height: Medidas.espacio6),
        const Center(child: CircularProgressIndicator()),
      ];

  List<Widget> _errorVista(BuildContext context, ErrorRutinaIa error) => [
        const EncabezadoPantalla(etiqueta: 'Rutina con IA', titulo: 'No se pudo'),
        const SizedBox(height: Medidas.espacio5),
        Aviso(error.mensaje, icono: Icons.error_outline_rounded),
        const SizedBox(height: Medidas.espacio5),
        if (error.irAPerfil)
          BotonPrincipal(
            texto: 'Completar mi perfil',
            icono: Icons.flag_outlined,
            alPresionar: () => context.pushReplacement('/perfil/editar'),
          )
        else
          BotonPrincipal(texto: 'Intentar de nuevo', icono: Icons.refresh_rounded, alPresionar: _generar),
        const SizedBox(height: Medidas.espacio2),
        BotonTexto(
          texto: 'Crear mi rutina a mano',
          icono: Icons.edit_outlined,
          anchoCompleto: true,
          alPresionar: () => context.pop(),
        ),
      ];
}

/// La propuesta editable, con nombre, fechas y el botón para guardar.
class _VistaPrevia extends ConsumerStatefulWidget {
  const _VistaPrevia({required this.propuesta});

  final PropuestaRutina propuesta;

  @override
  ConsumerState<_VistaPrevia> createState() => _VistaPreviaState();
}

class _VistaPreviaState extends ConsumerState<_VistaPrevia> {
  final GlobalKey<FormState> _formulario = GlobalKey<FormState>();
  late final TextEditingController _nombre = TextEditingController(text: widget.propuesta.nombreCiclo);
  late final TextEditingController _inicio = TextEditingController(text: FechaCiclo.aCampo(RutinasRepositorio.hoy()));
  late final TextEditingController _fin =
      TextEditingController(text: FechaCiclo.aCampo(FechaCiclo.finSugerido(RutinasRepositorio.hoy())));
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _inicio.dispose();
    _fin.dispose();
    super.dispose();
  }

  String? _validarFin(String? texto) {
    if ((texto ?? '').trim().isEmpty) return null;
    final fin = FechaCiclo.deCampo(texto);
    if (fin == null) return 'Escribe la fecha como 30/06/2027 o déjala vacía.';
    final inicio = FechaCiclo.deCampo(_inicio.text);
    return inicio == null ? null : ValidarRutina.fechas(inicio, fin);
  }

  Future<void> _editarDia(DiaPropuesto dia) async {
    FocusScope.of(context).unfocus();
    await mostrarHojaInferior<void>(context: context, constructor: (_) => _HojaDiaPropuesto(dia: dia));
    if (mounted) setState(() {});
  }

  Future<void> _guardar() async {
    if (!(_formulario.currentState?.validate() ?? false)) return;
    final propuesta = widget.propuesta..nombreCiclo = _nombre.text.trim();
    if (propuesta.diasEntrenamiento == 0) {
      setState(() => _error = 'La rutina no tiene ningún día con ejercicios.');
      return;
    }
    final repositorio = await ref.read(rutinaIaRepositorioProvider.future);
    if (repositorio == null || !mounted) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      // RN-01: si el plan ya no permite otro ciclo activo, archivar uno o ver Premium.
      var archivar = <String>[];
      final limite = await repositorio.rutinas.limite();
      if (!limite.puedeActivarOtro) {
        final activos = (await repositorio.rutinas.ciclos()).where((c) => c.activo).toList();
        if (!mounted) return;
        final eleccion = await mostrarHojaLimiteCiclos(context, limite: limite, activos: activos);
        if (!mounted) return;
        switch (eleccion) {
          case ArchivarCiclo(:final idCiclo):
            archivar = [idCiclo];
          case VerPremium():
            setState(() => _guardando = false);
            await mostrarPremiumPronto(context);
            return;
          case null:
            setState(() => _guardando = false);
            return;
        }
      }
      final idCiclo = await repositorio.guardar(
        propuesta,
        fechaInicio: FechaCiclo.deCampo(_inicio.text)!,
        fechaFin: _fin.text.trim().isEmpty ? null : FechaCiclo.deCampo(_fin.text),
        archivarAntes: archivar,
      );
      refrescarRutinas(ref);
      if (mounted) context.pushReplacement('/perfil/ciclos/$idCiclo');
    } catch (_) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = 'No se pudo guardar. Intenta de nuevo.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final propuesta = widget.propuesta;
    final dias = propuesta.diasEntrenamiento;
    final error = _error;
    return Form(
      key: _formulario,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EncabezadoPantalla(
            etiqueta: 'Propuesta de la IA',
            titulo: 'Tu semana',
            subtitulo: '${dias == 1 ? '1 día' : '$dias días'} de entrenamiento · revísala y edítala antes de guardar',
          ),
          if (propuesta.descartados > 0) ...[
            const SizedBox(height: Medidas.espacio4),
            Aviso('Se quitaron ${propuesta.descartados} ejercicios que no están en el catálogo.'),
          ],
          const SizedBox(height: Medidas.espacio5),
          CampoTexto(
            etiqueta: 'Nombre del ciclo',
            controlador: _nombre,
            accionTeclado: TextInputAction.next,
            validar: ValidarRutina.nombre,
          ),
          const SizedBox(height: Medidas.espacio4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CampoTexto(
                  etiqueta: 'Inicio',
                  controlador: _inicio,
                  pista: 'dd/mm/aaaa',
                  teclado: TextInputType.datetime,
                  validar: (t) => FechaCiclo.deCampo(t) == null ? 'Escribe la fecha como 24/11/2026.' : null,
                ),
              ),
              const SizedBox(width: Medidas.espacio3),
              Expanded(
                child: CampoTexto(
                  etiqueta: 'Fin (opcional)',
                  controlador: _fin,
                  pista: 'dd/mm/aaaa',
                  teclado: TextInputType.datetime,
                  validar: _validarFin,
                ),
              ),
            ],
          ),
          const SizedBox(height: Medidas.espacio5),
          const EtiquetaSeccion('Semana · toca un día para editarlo'),
          const SizedBox(height: 10),
          for (final dia in propuesta.dias) ...[
            _TarjetaDiaPropuesto(dia: dia, alTocar: () => _editarDia(dia)),
            const SizedBox(height: Medidas.espacio2),
          ],
          if (error != null) ...[
            const SizedBox(height: Medidas.espacio4),
            Aviso(error, icono: Icons.error_outline_rounded),
          ],
          const SizedBox(height: Medidas.espacio5),
          BotonPrincipal(
            texto: 'Guardar rutina',
            icono: Icons.check_rounded,
            alPresionar: _guardando ? null : _guardar,
          ),
          const SizedBox(height: Medidas.espacio2),
          BotonTexto(
            texto: 'Descartar',
            icono: Icons.close_rounded,
            anchoCompleto: true,
            alPresionar: _guardando ? null : () => context.pop(),
          ),
        ],
      ),
    );
  }
}

/// "3 × 10 · 60 kg · 90 s" de un ejercicio propuesto.
String resumenPropuesto(EjercicioPropuesto e) {
  String numero(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  final peso = e.pesoKg;
  return [
    '${e.series} × ${e.repeticiones}',
    if (peso != null) '${numero(peso)} kg',
    '${e.descansoSeg} s de descanso',
  ].join(' · ');
}

class _TarjetaDiaPropuesto extends StatelessWidget {
  const _TarjetaDiaPropuesto({required this.dia, required this.alTocar});

  final DiaPropuesto dia;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final colores = context.colores;
    return Tarjeta(
      nivel: dia.esDescanso ? 1 : 2,
      alTocar: alTocar,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(dia.nombreDiaSemana.toUpperCase(), style: textos.titleLarge),
              const SizedBox(width: Medidas.espacio3),
              Expanded(
                child: Text(
                  dia.esDescanso ? 'Descanso' : dia.nombre,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: textos.bodyMedium?.copyWith(color: dia.esDescanso ? colores.tinta2 : colores.tinta),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colores.tinta2),
            ],
          ),
          if (!dia.esDescanso)
            for (final e in dia.ejercicios)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('${e.nombre} · ${resumenPropuesto(e)}', style: textos.bodySmall),
              ),
        ],
      ),
    );
  }
}

/// Hoja para editar un día de la propuesta en memoria: tipo, nombre y
/// ejercicios (cambiar series, reps, peso y descanso; quitar; agregar; ordenar).
class _HojaDiaPropuesto extends ConsumerStatefulWidget {
  const _HojaDiaPropuesto({required this.dia});

  final DiaPropuesto dia;

  @override
  ConsumerState<_HojaDiaPropuesto> createState() => _HojaDiaPropuestoState();
}

class _HojaDiaPropuestoState extends ConsumerState<_HojaDiaPropuesto> {
  late final TextEditingController _nombre =
      TextEditingController(text: widget.dia.esDescanso ? '' : widget.dia.nombre);

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  void _cambiarTipo(bool esDescanso) {
    setState(() {
      widget.dia.esDescanso = esDescanso;
      if (!esDescanso && _nombre.text.trim().isEmpty) _nombre.text = 'Entrenamiento';
      widget.dia.nombre = esDescanso ? 'Descanso' : _nombre.text.trim();
    });
  }

  Future<void> _agregar() async {
    FocusScope.of(context).unfocus();
    final id = await mostrarHojaInferior<int>(context: context, constructor: (_) => const SelectorEjercicio());
    if (id == null || !mounted) return;
    final repositorio = await ref.read(rutinaIaRepositorioProvider.future);
    final lista = await repositorio?.catalogo.buscar() ?? const [];
    final e = lista.where((x) => x.idEjercicio == id).firstOrNull;
    if (e == null || !mounted) return;
    setState(() {
      widget.dia.ejercicios.add(EjercicioPropuesto(
        idEjercicio: e.idEjercicio,
        nombre: e.nombreVisible,
        nombreOficial: e.nombreOficial,
        grupoMuscular: e.grupoMuscular,
        series: 3,
        repeticiones: 10,
        descansoSeg: 90,
      ));
      widget.dia.esDescanso = false;
    });
  }

  Future<void> _editar(EjercicioPropuesto e) async {
    FocusScope.of(context).unfocus();
    final quitar = await mostrarHojaInferior<bool>(context: context, constructor: (_) => _HojaEjercicioPropuesto(ejercicio: e));
    if (!mounted) return;
    setState(() {
      if (quitar == true) widget.dia.ejercicios.remove(e);
    });
  }

  void _mover(int desde, int hacia) {
    setState(() {
      final e = widget.dia.ejercicios.removeAt(desde);
      widget.dia.ejercicios.insert(hacia, e);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dia = widget.dia;
    final textos = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EncabezadoHoja(titulo: dia.nombreDiaSemana, subtitulo: 'Los cambios se guardan al tocar "Guardar rutina"'),
        const SizedBox(height: Medidas.espacio4),
        Align(
          alignment: Alignment.centerLeft,
          child: SelectorSegmentos<bool>(
            opciones: const [
              OpcionSegmento(valor: false, texto: 'Rutina'),
              OpcionSegmento(valor: true, texto: 'Descanso'),
            ],
            valor: dia.esDescanso,
            alCambiar: _cambiarTipo,
          ),
        ),
        if (!dia.esDescanso) ...[
          const SizedBox(height: Medidas.espacio4),
          CampoTexto(
            etiqueta: 'Nombre del día',
            controlador: _nombre,
            pista: 'Por ejemplo: Pierna',
            alCambiar: (t) => dia.nombre = t.trim().isEmpty ? 'Entrenamiento' : t.trim(),
          ),
          const SizedBox(height: Medidas.espacio4),
          for (var i = 0; i < dia.ejercicios.length; i++) ...[
            Tarjeta(
              alTocar: () => _editar(dia.ejercicios[i]),
              padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(dia.ejercicios[i].nombre, style: textos.titleMedium),
                        Text(resumenPropuesto(dia.ejercicios[i]), style: textos.bodySmall),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Subir',
                    icon: const Icon(Icons.keyboard_arrow_up_rounded),
                    color: context.colores.tinta,
                    disabledColor: context.colores.tenue,
                    onPressed: i == 0 ? null : () => _mover(i, i - 1),
                  ),
                  IconButton(
                    tooltip: 'Bajar',
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    color: context.colores.tinta,
                    disabledColor: context.colores.tenue,
                    onPressed: i == dia.ejercicios.length - 1 ? null : () => _mover(i, i + 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Medidas.espacio2),
          ],
          const SizedBox(height: Medidas.espacio2),
          BotonSecundario(texto: 'Agregar ejercicio', icono: Icons.add_rounded, alPresionar: _agregar),
        ],
        const SizedBox(height: Medidas.espacio4),
        BotonPrincipal(texto: 'Listo', icono: Icons.check_rounded, alPresionar: () => Navigator.pop(context)),
      ],
    );
  }
}

/// Hoja para cambiar series, repeticiones, peso y descanso de un ejercicio
/// propuesto, o quitarlo. Devuelve true si hay que quitarlo.
class _HojaEjercicioPropuesto extends StatefulWidget {
  const _HojaEjercicioPropuesto({required this.ejercicio});

  final EjercicioPropuesto ejercicio;

  @override
  State<_HojaEjercicioPropuesto> createState() => _HojaEjercicioPropuestoState();
}

class _HojaEjercicioPropuestoState extends State<_HojaEjercicioPropuesto> {
  final GlobalKey<FormState> _formulario = GlobalKey<FormState>();
  late final _series = TextEditingController(text: '${widget.ejercicio.series}');
  late final _reps = TextEditingController(text: '${widget.ejercicio.repeticiones}');
  late final _peso = TextEditingController(
    text: widget.ejercicio.pesoKg == null
        ? ''
        : (widget.ejercicio.pesoKg! % 1 == 0
            ? widget.ejercicio.pesoKg!.toStringAsFixed(0)
            : widget.ejercicio.pesoKg!.toStringAsFixed(1)),
  );
  late final _descanso = TextEditingController(text: '${widget.ejercicio.descansoSeg}');

  @override
  void dispose() {
    for (final c in [_series, _reps, _peso, _descanso]) {
      c.dispose();
    }
    super.dispose();
  }

  void _aplicar() {
    if (!(_formulario.currentState?.validate() ?? false)) return;
    widget.ejercicio
      ..series = int.parse(_series.text.trim())
      ..repeticiones = int.parse(_reps.text.trim())
      ..pesoKg = _peso.text.trim().isEmpty ? null : double.parse(_peso.text.trim().replaceAll(',', '.'))
      ..descansoSeg = int.parse(_descanso.text.trim());
    Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.ejercicio;
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
            titulo: e.nombre,
            subtitulo: e.nombre != e.nombreOficial ? 'Nombre oficial: ${e.nombreOficial}' : e.grupoMuscular,
          ),
          const SizedBox(height: Medidas.espacio5),
          par(
            CampoTexto(etiqueta: 'Series', controlador: _series, teclado: numero, validar: ValidarRutina.series),
            CampoTexto(etiqueta: 'Repeticiones', controlador: _reps, teclado: numero, validar: ValidarRutina.repeticiones),
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
            CampoTexto(etiqueta: 'Descanso (s)', controlador: _descanso, teclado: numero, validar: ValidarRutina.descansoSeg),
          ),
          const SizedBox(height: Medidas.espacio5),
          BotonPrincipal(texto: 'Aplicar', icono: Icons.check_rounded, alPresionar: _aplicar),
          const SizedBox(height: Medidas.espacio2),
          BotonTexto(
            texto: 'Quitar del día',
            icono: Icons.delete_outline_rounded,
            anchoCompleto: true,
            alPresionar: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
  }
}
