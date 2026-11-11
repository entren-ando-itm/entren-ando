import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/diseno.dart';
import 'catalogo_repositorio.dart';

/// Filtros de la búsqueda: texto, grupo muscular y equipo.
typedef FiltrosCatalogo = ({String texto, String? grupo, FiltroEquipo equipo});

/// Ejercicios que cumplen los filtros, leídos de la base local.
final resultadosCatalogoProvider =
    FutureProvider.family<List<EjercicioCatalogo>, FiltrosCatalogo>((ref, filtros) async {
  final repositorio = await ref.watch(catalogoRepositorioProvider.future);
  if (repositorio == null) return const [];
  return repositorio.buscar(texto: filtros.texto, grupo: filtros.grupo, equipo: filtros.equipo);
});

/// Grupos musculares y equipos para los filtros.
final opcionesFiltroCatalogoProvider =
    FutureProvider<({List<String> grupos, List<EquipoCatalogo> equipos})>((ref) async {
  final repositorio = await ref.watch(catalogoRepositorioProvider.future);
  if (repositorio == null) return (grupos: const <String>[], equipos: const <EquipoCatalogo>[]);
  return (grupos: await repositorio.gruposMusculares(), equipos: await repositorio.equipos());
});

/// Catálogo de ejercicios con alias (ENT-17).
///
/// Busca y filtra el catálogo sin internet y deja poner o quitar un nombre
/// propio a cada ejercicio. El usuario no puede crear ejercicios.
class PantallaCatalogo extends ConsumerStatefulWidget {
  const PantallaCatalogo({super.key});

  @override
  ConsumerState<PantallaCatalogo> createState() => _PantallaCatalogoState();
}

class _PantallaCatalogoState extends ConsumerState<PantallaCatalogo> {
  final TextEditingController _buscador = TextEditingController();
  String _texto = '';
  String? _grupo;
  FiltroEquipo _equipo = FiltroEquipo.todos;

  FiltrosCatalogo get _filtros => (texto: _texto, grupo: _grupo, equipo: _equipo);

  @override
  void dispose() {
    _buscador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultados = ref.watch(resultadosCatalogoProvider(_filtros));
    final opciones = ref.watch(opcionesFiltroCatalogoProvider).value;
    final textos = Theme.of(context).textTheme;

    final cantidad = resultados.value?.length;
    return Scaffold(
      body: ContenidoPantalla(
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
            etiqueta: 'Perfil',
            titulo: 'Catálogo',
            subtitulo: cantidad == null
                ? 'Ponles tu propio nombre a los ejercicios'
                : cantidad == 1
                    ? '1 ejercicio'
                    : '$cantidad ejercicios',
          ),
          const SizedBox(height: Medidas.espacio5),
          CampoTexto(
            etiqueta: 'Buscar',
            controlador: _buscador,
            pista: 'Nombre o alias',
            accionTeclado: TextInputAction.search,
            alCambiar: (valor) => setState(() => _texto = valor),
          ),
          const SizedBox(height: Medidas.espacio4),
          GrupoFilas(
            filas: [
              FilaAjuste(
                titulo: 'Grupo muscular',
                icono: Icons.accessibility_new_rounded,
                fin: _valorFiltro(context, _grupo ?? 'Todos'),
                alTocar: opciones == null ? null : () => _elegirGrupo(opciones.grupos),
              ),
              FilaAjuste(
                titulo: 'Equipo',
                icono: Icons.fitness_center_rounded,
                fin: _valorFiltro(context, _nombreFiltroEquipo(opciones?.equipos ?? const [])),
                alTocar: opciones == null ? null : () => _elegirEquipo(opciones.equipos),
              ),
            ],
          ),
          const SizedBox(height: Medidas.espacio5),
          ...resultados.when(
            loading: () => const [
              Padding(
                padding: EdgeInsets.all(Medidas.espacio5),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (error, _) => [
              const Aviso('No se pudo leer el catálogo de la base local.', icono: Icons.error_outline_rounded),
            ],
            data: (ejercicios) {
              if (ejercicios.isEmpty) {
                return [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Medidas.espacio5),
                    child: Text(
                      'No hay ejercicios con esa búsqueda.',
                      style: textos.bodyMedium?.copyWith(color: context.colores.tinta2),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ];
              }
              return [
                for (final ejercicio in ejercicios) ...[
                  _FilaEjercicio(ejercicio: ejercicio, alTocar: () => _editarAlias(ejercicio)),
                  const SizedBox(height: Medidas.espacio2),
                ],
              ];
            },
          ),
        ],
      ),
    );
  }

  Widget _valorFiltro(BuildContext context, String texto) {
    return Padding(
      padding: const EdgeInsets.only(right: Medidas.espacio1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              texto,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.colores.tinta2),
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: context.colores.tinta2),
        ],
      ),
    );
  }

  String _nombreFiltroEquipo(List<EquipoCatalogo> equipos) {
    if (_equipo.esTodos) return 'Todos';
    if (_equipo.pesoCorporal) return 'Peso corporal';
    for (final equipo in equipos) {
      if (equipo.idEquipo == _equipo.idEquipo) return equipo.nombre;
    }
    return 'Todos';
  }

  Future<void> _elegirGrupo(List<String> grupos) async {
    // Se usa un valor vacío para "Todos" porque la hoja devuelve null al cerrarse.
    final elegido = await mostrarHojaInferior<String>(
      context: context,
      constructor: (contexto) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const EncabezadoHoja(titulo: 'Grupo muscular'),
          const SizedBox(height: Medidas.espacio5),
          for (final grupo in ['', ...grupos]) ...[
            FilaOpcion(
              titulo: grupo.isEmpty ? 'Todos' : grupo,
              seleccionada: (_grupo ?? '') == grupo,
              alTocar: () => Navigator.pop(contexto, grupo),
            ),
            const SizedBox(height: Medidas.espacio2),
          ],
        ],
      ),
    );
    if (elegido == null || !mounted) return;
    setState(() => _grupo = elegido.isEmpty ? null : elegido);
  }

  Future<void> _elegirEquipo(List<EquipoCatalogo> equipos) async {
    final elegido = await mostrarHojaInferior<FiltroEquipo>(
      context: context,
      constructor: (contexto) {
        final opciones = <(FiltroEquipo, String)>[
          (FiltroEquipo.todos, 'Todos'),
          (FiltroEquipo.soloPesoCorporal, 'Peso corporal'),
          for (final equipo in equipos) (FiltroEquipo.equipo(equipo.idEquipo), equipo.nombre),
        ];
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const EncabezadoHoja(titulo: 'Equipo'),
            const SizedBox(height: Medidas.espacio5),
            for (final (filtro, nombre) in opciones) ...[
              FilaOpcion(
                titulo: nombre,
                seleccionada: _equipo == filtro,
                alTocar: () => Navigator.pop(contexto, filtro),
              ),
              const SizedBox(height: Medidas.espacio2),
            ],
          ],
        );
      },
    );
    if (elegido == null || !mounted) return;
    setState(() => _equipo = elegido);
  }

  Future<void> _editarAlias(EjercicioCatalogo ejercicio) async {
    final repositorio = await ref.read(catalogoRepositorioProvider.future);
    if (repositorio == null || !mounted) return;
    final cambio = await mostrarHojaInferior<bool>(
      context: context,
      constructor: (contexto) => _HojaAlias(ejercicio: ejercicio, repositorio: repositorio),
    );
    if (cambio == true) ref.invalidate(resultadosCatalogoProvider);
  }
}

/// Un ejercicio en la lista: el alias grande y el nombre oficial chico debajo.
class _FilaEjercicio extends StatelessWidget {
  const _FilaEjercicio({required this.ejercicio, required this.alTocar});

  final EjercicioCatalogo ejercicio;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final detalles = [ejercicio.grupoMuscular, ejercicio.nombreEquipo ?? 'Peso corporal'].join(' · ');
    return Tarjeta(
      alTocar: alTocar,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ejercicio.nombreVisible, style: textos.titleMedium),
                if (ejercicio.tieneAlias)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(ejercicio.nombreOficial, style: textos.bodySmall),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(detalles, style: textos.bodySmall),
                ),
              ],
            ),
          ),
          if (ejercicio.tieneAlias) ...[
            const SizedBox(width: Medidas.espacio2),
            const Pastilla('Alias', chica: true),
          ],
          const SizedBox(width: Medidas.espacio1),
          Icon(Icons.edit_outlined, size: 20, color: context.colores.tinta2),
        ],
      ),
    );
  }
}

/// Hoja para poner, cambiar o quitar el alias. Devuelve true si hubo cambio.
class _HojaAlias extends StatefulWidget {
  const _HojaAlias({required this.ejercicio, required this.repositorio});

  final EjercicioCatalogo ejercicio;
  final CatalogoRepositorio repositorio;

  @override
  State<_HojaAlias> createState() => _HojaAliasState();
}

class _HojaAliasState extends State<_HojaAlias> {
  final GlobalKey<FormState> _formulario = GlobalKey<FormState>();
  late final TextEditingController _alias = TextEditingController(text: widget.ejercicio.alias ?? '');
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _alias.dispose();
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
    _ejecutar(() => widget.repositorio.guardarAlias(widget.ejercicio.idEjercicio, _alias.text));
  }

  @override
  Widget build(BuildContext context) {
    final ejercicio = widget.ejercicio;
    final error = _error;
    return Form(
      key: _formulario,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EncabezadoHoja(
            titulo: ejercicio.nombreVisible,
            subtitulo: ejercicio.tieneAlias ? 'Nombre oficial: ${ejercicio.nombreOficial}' : null,
          ),
          const SizedBox(height: Medidas.espacio5),
          CampoTexto(
            etiqueta: 'Tu nombre para este ejercicio',
            controlador: _alias,
            pista: 'Por ejemplo: Levantamiento de garrafón',
            accionTeclado: TextInputAction.done,
            validar: CatalogoRepositorio.validarAlias,
            alEnviar: (_) => _guardar(),
          ),
          const SizedBox(height: Medidas.espacio2),
          Text(
            'Solo tú lo ves. A la IA siempre le llega el nombre oficial.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (error != null) ...[
            const SizedBox(height: Medidas.espacio4),
            Aviso(error, icono: Icons.error_outline_rounded),
          ],
          const SizedBox(height: Medidas.espacio5),
          BotonPrincipal(
            texto: 'Guardar alias',
            icono: Icons.check_rounded,
            alPresionar: _guardando ? null : _guardar,
          ),
          if (ejercicio.tieneAlias) ...[
            const SizedBox(height: Medidas.espacio2),
            BotonTexto(
              texto: 'Quitar alias',
              icono: Icons.undo_rounded,
              anchoCompleto: true,
              alPresionar: _guardando
                  ? null
                  : () => _ejecutar(() => widget.repositorio.quitarAlias(ejercicio.idEjercicio)),
            ),
          ],
        ],
      ),
    );
  }
}
