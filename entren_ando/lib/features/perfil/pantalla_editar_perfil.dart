import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/diseno.dart';
import 'perfil_repositorio.dart';

final _perfilEntrenamientoProvider = FutureProvider.autoDispose<PerfilEntrenamiento?>((ref) async {
  final repositorio = await ref.watch(perfilRepositorioProvider.future);
  return repositorio?.perfil();
});

/// Editar objetivo, nivel, días por semana y notas de lesiones (ENT-18).
class PantallaEditarPerfil extends ConsumerWidget {
  const PantallaEditarPerfil({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(_perfilEntrenamientoProvider);
    return Scaffold(
      body: perfil.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => const MensajeCentrado(
          'No se pudo leer tu perfil de la base local.',
          icono: Icons.error_outline_rounded,
        ),
        data: (datos) => _FormularioPerfil(inicial: datos),
      ),
    );
  }
}

class _FormularioPerfil extends ConsumerStatefulWidget {
  const _FormularioPerfil({required this.inicial});

  final PerfilEntrenamiento? inicial;

  @override
  ConsumerState<_FormularioPerfil> createState() => _FormularioPerfilState();
}

class _FormularioPerfilState extends ConsumerState<_FormularioPerfil> {
  final GlobalKey<FormState> _formulario = GlobalKey<FormState>();
  late String? _objetivo = widget.inicial?.objetivo;
  late String? _nivel = widget.inicial?.nivel;
  late final TextEditingController _dias =
      TextEditingController(text: widget.inicial?.diasPorSemana.toString() ?? '');
  late final TextEditingController _notas =
      TextEditingController(text: widget.inicial?.notasLesiones ?? '');
  bool _intentoGuardar = false;
  bool _guardando = false;
  String? _errorGuardar;

  @override
  void dispose() {
    _dias.dispose();
    _notas.dispose();
    super.dispose();
  }

  Future<void> _elegir(String titulo, Map<String, String> opciones, String? actual,
      ValueChanged<String> alElegir) async {
    final elegido = await mostrarHojaInferior<String>(
      context: context,
      constructor: (contexto) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EncabezadoHoja(titulo: titulo),
          const SizedBox(height: Medidas.espacio5),
          for (final opcion in opciones.entries) ...[
            FilaOpcion(
              titulo: opcion.value,
              seleccionada: opcion.key == actual,
              alTocar: () => Navigator.pop(contexto, opcion.key),
            ),
            const SizedBox(height: Medidas.espacio2),
          ],
        ],
      ),
    );
    if (elegido != null && mounted) setState(() => alElegir(elegido));
  }

  Future<void> _guardar() async {
    setState(() => _intentoGuardar = true);
    final formularioBien = _formulario.currentState?.validate() ?? false;
    if (!formularioBien ||
        ValidarPerfil.objetivo(_objetivo) != null ||
        ValidarPerfil.nivel(_nivel) != null) {
      return;
    }
    setState(() {
      _guardando = true;
      _errorGuardar = null;
    });
    try {
      final repositorio = await ref.read(perfilRepositorioProvider.future);
      await repositorio!.guardarPerfil(PerfilEntrenamiento(
        objetivo: _objetivo!,
        nivel: _nivel!,
        diasPorSemana: int.parse(_dias.text.trim()),
        notasLesiones: _notas.text,
      ));
      ref.invalidate(resumenPerfilProvider);
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _errorGuardar = 'No se pudo guardar. Intenta de nuevo.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final errorObjetivo = _intentoGuardar ? ValidarPerfil.objetivo(_objetivo) : null;
    final errorNivel = _intentoGuardar ? ValidarPerfil.nivel(_nivel) : null;
    final errorGuardar = _errorGuardar;
    return Form(
      key: _formulario,
      child: ContenidoPantalla(
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
          const EncabezadoPantalla(
            etiqueta: 'Perfil',
            titulo: 'Tu perfil',
            subtitulo: 'La IA arma tu rutina con estos datos',
          ),
          const SizedBox(height: Medidas.espacio5),
          GrupoFilas(
            filas: [
              FilaAjuste(
                titulo: 'Objetivo',
                icono: Icons.flag_outlined,
                fin: _valor(context, objetivosPerfil[_objetivo] ?? 'Elegir'),
                alTocar: () => _elegir('Objetivo', objetivosPerfil, _objetivo, (v) => _objetivo = v),
              ),
              FilaAjuste(
                titulo: 'Nivel',
                icono: Icons.trending_up_rounded,
                fin: _valor(context, nivelesPerfil[_nivel] ?? 'Elegir'),
                alTocar: () => _elegir('Nivel', nivelesPerfil, _nivel, (v) => _nivel = v),
              ),
            ],
          ),
          for (final error in [errorObjetivo, errorNivel].whereType<String>())
            Padding(
              padding: const EdgeInsets.only(top: Medidas.espacio2, left: Medidas.espacio4),
              child: Text(
                error,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.colores.error),
              ),
            ),
          const SizedBox(height: Medidas.espacio5),
          CampoTexto(
            etiqueta: 'Días por semana',
            controlador: _dias,
            pista: 'De 1 a 7',
            teclado: TextInputType.number,
            accionTeclado: TextInputAction.next,
            validar: ValidarPerfil.diasPorSemana,
          ),
          const SizedBox(height: Medidas.espacio4),
          CampoTexto(
            etiqueta: 'Lesiones o molestias',
            controlador: _notas,
            pista: 'Opcional. Por ejemplo: dolor en la rodilla derecha',
            maxLineas: 3,
          ),
          if (errorGuardar != null) ...[
            const SizedBox(height: Medidas.espacio4),
            Aviso(errorGuardar, icono: Icons.error_outline_rounded),
          ],
          const SizedBox(height: Medidas.espacio5),
          BotonPrincipal(
            texto: 'Guardar perfil',
            icono: Icons.check_rounded,
            alPresionar: _guardando ? null : _guardar,
          ),
        ],
      ),
    );
  }

  static Widget _valor(BuildContext context, String texto) {
    return Padding(
      padding: const EdgeInsets.only(right: Medidas.espacio1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            texto,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.colores.tinta2),
          ),
          Icon(Icons.chevron_right_rounded, color: context.colores.tinta2),
        ],
      ),
    );
  }
}
