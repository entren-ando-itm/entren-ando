import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/diseno.dart';
import '../../perfil/catalogo/catalogo_repositorio.dart';
import '../rutinas_proveedores.dart';
import '../rutinas_repositorio.dart';
import 'alternativas_repositorio.dart';

final ejercicioConAlternativasProvider =
    FutureProvider.autoDispose.family<EjercicioConAlternativas?, String>((ref, idProgramado) async {
  final repositorio = await ref.watch(alternativasRepositorioProvider.future);
  return repositorio?.ejercicio(idProgramado);
});

final alternativasProvider =
    FutureProvider.autoDispose.family<List<Alternativa>, String>((ref, idProgramado) async {
  final repositorio = await ref.watch(alternativasRepositorioProvider.future);
  return repositorio?.alternativas(idProgramado) ?? const [];
});

/// Alternativas de un ejercicio programado (ENT-48): hasta 3 del catálogo,
/// con prioridad de 1 a 3 y sin repetir. Por defecto propone el mismo grupo
/// muscular.
class PantallaAlternativas extends ConsumerStatefulWidget {
  const PantallaAlternativas({super.key, required this.idProgramado});

  final String idProgramado;

  @override
  ConsumerState<PantallaAlternativas> createState() => _PantallaAlternativasState();
}

class _PantallaAlternativasState extends ConsumerState<PantallaAlternativas> {
  String? _error;

  Future<void> _guardar(Future<void> Function(AlternativasRepositorio repo) accion) async {
    final repositorio = await ref.read(alternativasRepositorioProvider.future);
    if (repositorio == null) return;
    try {
      await accion(repositorio);
      if (mounted) setState(() => _error = null);
    } on ArgumentError catch (e) {
      if (mounted) setState(() => _error = '${e.message}');
    } on CicloSoloLectura {
      if (mounted) setState(() => _error = 'El ciclo está archivado. Reactívalo para editarlo.');
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo guardar. Intenta de nuevo.');
    }
    ref.invalidate(alternativasProvider(widget.idProgramado));
    ref.invalidate(ejerciciosDiaProvider); // Para el número de alternativas en el editor.
  }

  Future<void> _agregar(EjercicioConAlternativas ejercicio, List<Alternativa> actuales) async {
    final elegido = await mostrarHojaInferior<int>(
      context: context,
      constructor: (contexto) => _SelectorAlternativa(
        ejercicio: ejercicio,
        excluir: {ejercicio.idEjercicio, ...actuales.map((a) => a.idEjercicio)},
      ),
    );
    if (elegido == null) return;
    await _guardar((repo) => repo.agregar(widget.idProgramado, elegido));
  }

  @override
  Widget build(BuildContext context) {
    final ejercicio = ref.watch(ejercicioConAlternativasProvider(widget.idProgramado));
    final alternativas = ref.watch(alternativasProvider(widget.idProgramado));
    final textos = Theme.of(context).textTheme;
    final error = _error;

    return Scaffold(
      body: ejercicio.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const MensajeCentrado('No se pudo leer el ejercicio.', icono: Icons.error_outline_rounded),
        data: (datos) {
          if (datos == null) return const MensajeCentrado('Este ejercicio ya no está en la rutina.');
          final editable = datos.cicloActivo;
          final lista = alternativas.value ?? const <Alternativa>[];
          final lleno = lista.length >= AlternativasRepositorio.maximo;
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
                etiqueta: 'Alternativas',
                titulo: datos.nombre,
                subtitulo: 'Si el equipo está ocupado · hasta ${AlternativasRepositorio.maximo}',
                estiloTitulo: textos.headlineMedium,
              ),
              const SizedBox(height: Medidas.espacio5),
              if (!editable) ...[
                const Aviso('El ciclo está archivado: lo ves en solo lectura.', icono: Icons.lock_outline_rounded),
                const SizedBox(height: Medidas.espacio4),
              ],
              if (error != null) ...[
                Aviso(error, icono: Icons.error_outline_rounded),
                const SizedBox(height: Medidas.espacio4),
              ],
              ...alternativas.when(
                loading: () => const [Center(child: CircularProgressIndicator())],
                error: (e, _) => const [
                  Aviso('No se pudieron leer las alternativas.', icono: Icons.error_outline_rounded),
                ],
                data: (datosAlt) => datosAlt.isEmpty
                    ? [
                        Text(
                          editable
                              ? 'Todavía no tiene alternativas. Agrega hasta 3 del catálogo.'
                              : 'Este ejercicio no tiene alternativas.',
                          style: textos.bodyMedium?.copyWith(color: context.colores.tinta2),
                        ),
                      ]
                    : [
                        for (var i = 0; i < datosAlt.length; i++) ...[
                          _FilaAlternativa(
                            alternativa: datosAlt[i],
                            editable: editable,
                            alSubir: i == 0
                                ? null
                                : () => _guardar((r) => r.mover(widget.idProgramado, datosAlt[i].idAlternativa, i - 1)),
                            alBajar: i == datosAlt.length - 1
                                ? null
                                : () => _guardar((r) => r.mover(widget.idProgramado, datosAlt[i].idAlternativa, i + 1)),
                            alQuitar: () => _guardar((r) => r.quitar(widget.idProgramado, datosAlt[i].idAlternativa)),
                          ),
                          const SizedBox(height: Medidas.espacio2),
                        ],
                      ],
              ),
              if (editable) ...[
                const SizedBox(height: Medidas.espacio4),
                if (lleno)
                  const Aviso('Ya tiene 3 alternativas. Quita una para agregar otra.')
                else
                  BotonPrincipal(
                    texto: 'Agregar alternativa',
                    icono: Icons.add_rounded,
                    alPresionar: alternativas.isLoading ? null : () => _agregar(datos, lista),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _FilaAlternativa extends StatelessWidget {
  const _FilaAlternativa({
    required this.alternativa,
    required this.editable,
    this.alSubir,
    this.alBajar,
    this.alQuitar,
  });

  final Alternativa alternativa;
  final bool editable;
  final VoidCallback? alSubir;
  final VoidCallback? alBajar;
  final VoidCallback? alQuitar;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final colores = context.colores;
    final detalle = [
      if (alternativa.nombre != alternativa.nombreOficial) alternativa.nombreOficial,
      alternativa.grupoMuscular,
      alternativa.nombreEquipo ?? 'Peso corporal',
    ].join(' · ');
    return Tarjeta(
      padding: const EdgeInsets.fromLTRB(18, 10, 4, 10),
      child: Row(
        children: [
          Semantics(
            label: 'Prioridad ${alternativa.prioridad}',
            child: NumeroConUnidad(numero: '${alternativa.prioridad}', tamano: 28),
          ),
          const SizedBox(width: Medidas.espacio4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alternativa.nombre, style: textos.titleMedium),
                const SizedBox(height: 2),
                Text(detalle, style: textos.bodySmall),
              ],
            ),
          ),
          if (editable) ...[
            IconButton(
              tooltip: 'Subir prioridad',
              icon: const Icon(Icons.keyboard_arrow_up_rounded),
              color: colores.tinta,
              disabledColor: colores.tenue,
              onPressed: alSubir,
            ),
            IconButton(
              tooltip: 'Bajar prioridad',
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              color: colores.tinta,
              disabledColor: colores.tenue,
              onPressed: alBajar,
            ),
            IconButton(
              tooltip: 'Quitar',
              icon: const Icon(Icons.close_rounded, size: 20),
              color: colores.tinta2,
              onPressed: alQuitar,
            ),
          ],
        ],
      ),
    );
  }
}

/// Hoja para elegir una alternativa del catálogo. Por defecto muestra el
/// mismo grupo muscular; no muestra el ejercicio principal ni los ya elegidos.
class _SelectorAlternativa extends ConsumerStatefulWidget {
  const _SelectorAlternativa({required this.ejercicio, required this.excluir});

  final EjercicioConAlternativas ejercicio;
  final Set<int> excluir;

  @override
  ConsumerState<_SelectorAlternativa> createState() => _SelectorAlternativaState();
}

class _SelectorAlternativaState extends ConsumerState<_SelectorAlternativa> {
  bool _mismoGrupo = true;
  String _texto = '';
  List<EjercicioCatalogo>? _resultados;
  int _consulta = 0;

  @override
  void initState() {
    super.initState();
    _buscar();
  }

  Future<void> _buscar() async {
    final numero = ++_consulta;
    final repositorio = await ref.read(catalogoRepositorioProvider.future);
    final resultados = await repositorio?.buscar(
          texto: _texto,
          grupo: _mismoGrupo ? widget.ejercicio.grupoMuscular : null,
        ) ??
        const <EjercicioCatalogo>[];
    if (mounted && numero == _consulta) {
      setState(() => _resultados = resultados.where((e) => !widget.excluir.contains(e.idEjercicio)).toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    final resultados = _resultados;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EncabezadoHoja(titulo: 'Agregar alternativa', subtitulo: 'Para cambiar ${widget.ejercicio.nombre}'),
        const SizedBox(height: Medidas.espacio4),
        Align(
          alignment: Alignment.centerLeft,
          child: SelectorSegmentos<bool>(
            opciones: [
              OpcionSegmento(valor: true, texto: widget.ejercicio.grupoMuscular),
              const OpcionSegmento(valor: false, texto: 'Todos'),
            ],
            valor: _mismoGrupo,
            alCambiar: (valor) {
              setState(() => _mismoGrupo = valor);
              _buscar();
            },
          ),
        ),
        const SizedBox(height: Medidas.espacio4),
        CampoTexto(
          etiqueta: 'Buscar',
          pista: 'Nombre o alias',
          accionTeclado: TextInputAction.search,
          alCambiar: (valor) {
            _texto = valor;
            _buscar();
          },
        ),
        const SizedBox(height: Medidas.espacio4),
        if (resultados == null)
          const Center(child: CircularProgressIndicator())
        else if (resultados.isEmpty)
          Text('No hay más ejercicios con esa búsqueda.', style: Theme.of(context).textTheme.bodyMedium)
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
