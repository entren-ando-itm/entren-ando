import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/usuario_actual.dart';
import '../../core/diseno.dart';
import 'comidas_repositorio.dart';

/// Abre la hoja para registrar una comida a mano o, si pasas [comida],
/// para editarla o borrarla (ENT-82). Funciona igual sin internet.
Future<void> mostrarHojaComida(BuildContext context, {Comida? comida}) {
  return mostrarHojaInferior<void>(
    context: context,
    constructor: (_) => HojaComida(comida: comida),
  );
}

class HojaComida extends ConsumerStatefulWidget {
  const HojaComida({super.key, this.comida});

  /// null = registrar una nueva.
  final Comida? comida;

  @override
  ConsumerState<HojaComida> createState() => _HojaComidaState();
}

class _HojaComidaState extends ConsumerState<HojaComida> {
  final _formulario = GlobalKey<FormState>();
  late final TextEditingController _descripcion;
  late final TextEditingController _calorias;
  late final TextEditingController _proteinas;
  late final TextEditingController _carbohidratos;
  late final TextEditingController _grasas;

  bool _guardando = false;

  /// Primer toque en "Borrar comida" pide confirmar; el segundo borra.
  bool _confirmarBorrado = false;
  String? _error;

  bool get _editando => widget.comida != null;

  @override
  void initState() {
    super.initState();
    final c = widget.comida;
    _descripcion = TextEditingController(text: c?.descripcion ?? '');
    _calorias = TextEditingController(text: c == null ? '' : '${c.calorias}');
    _proteinas = TextEditingController(text: _gramos(c?.proteinas));
    _carbohidratos = TextEditingController(text: _gramos(c?.carbohidratos));
    _grasas = TextEditingController(text: _gramos(c?.grasas));
  }

  @override
  void dispose() {
    _descripcion.dispose();
    _calorias.dispose();
    _proteinas.dispose();
    _carbohidratos.dispose();
    _grasas.dispose();
    super.dispose();
  }

  static String _gramos(double? valor) {
    if (valor == null) return '';
    return valor == valor.roundToDouble() ? valor.toInt().toString() : valor.toString();
  }

  Future<void> _guardar() async {
    if (!_formulario.currentState!.validate()) return;
    final idUsuario = ref.read(usuarioActualIdProvider);
    if (idUsuario == null) return;
    final datos = DatosComida(
      descripcion: _descripcion.text.trim(),
      calorias: int.parse(_calorias.text.trim()),
      proteinas: ValidarComida.numero(_proteinas.text),
      carbohidratos: ValidarComida.numero(_carbohidratos.text),
      grasas: ValidarComida.numero(_grasas.text),
    );
    await _ejecutar((repositorio) async {
      if (_editando) {
        await repositorio.editar(idUsuario, widget.comida!.id, datos);
      } else {
        await repositorio.agregar(idUsuario, datos);
      }
    });
  }

  Future<void> _borrar() async {
    if (!_confirmarBorrado) {
      setState(() => _confirmarBorrado = true);
      return;
    }
    final idUsuario = ref.read(usuarioActualIdProvider);
    if (idUsuario == null) return;
    await _ejecutar((repositorio) => repositorio.borrar(idUsuario, widget.comida!.id));
  }

  Future<void> _ejecutar(Future<void> Function(ComidasRepositorio) accion) async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final repositorio = await ref.read(comidasRepositorioProvider.future);
      await accion(repositorio);
      ref.invalidate(comidasDeHoyProvider);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = 'No se pudo guardar en el celular. Intenta otra vez.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final comida = widget.comida;
    return Form(
      key: _formulario,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EncabezadoHoja(
            titulo: _editando ? 'Editar comida' : 'Registrar comida',
            subtitulo: _editando
                ? 'Registrada a las ${comida!.hora}${comida.porIa ? ' · escaneo con IA' : ''}'
                : 'Se guarda en tu celular, aunque no tengas internet',
          ),
          const SizedBox(height: 20),
          CampoTexto(
            etiqueta: 'Qué comiste',
            pista: 'Avena con plátano y leche',
            controlador: _descripcion,
            accionTeclado: TextInputAction.next,
            validar: ValidarComida.descripcion,
          ),
          const SizedBox(height: Medidas.espacio3),
          CampoTexto(
            etiqueta: 'Calorías (kcal)',
            pista: '420',
            controlador: _calorias,
            teclado: TextInputType.number,
            accionTeclado: TextInputAction.next,
            validar: ValidarComida.calorias,
          ),
          const SizedBox(height: Medidas.espacio5),
          const EtiquetaSeccion('Macros en gramos · opcional'),
          const SizedBox(height: Medidas.espacio2),
          CampoTexto(
            etiqueta: 'Proteína',
            pista: '0',
            controlador: _proteinas,
            teclado: const TextInputType.numberWithOptions(decimal: true),
            accionTeclado: TextInputAction.next,
            validar: ValidarComida.gramos,
          ),
          const SizedBox(height: Medidas.espacio3),
          CampoTexto(
            etiqueta: 'Carbohidratos',
            pista: '0',
            controlador: _carbohidratos,
            teclado: const TextInputType.numberWithOptions(decimal: true),
            accionTeclado: TextInputAction.next,
            validar: ValidarComida.gramos,
          ),
          const SizedBox(height: Medidas.espacio3),
          CampoTexto(
            etiqueta: 'Grasa',
            pista: '0',
            controlador: _grasas,
            teclado: const TextInputType.numberWithOptions(decimal: true),
            accionTeclado: TextInputAction.done,
            validar: ValidarComida.gramos,
            alEnviar: (_) {
              if (!_guardando) _guardar();
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: Medidas.espacio4),
            Aviso(_error!, icono: Icons.error_outline_rounded),
          ],
          const SizedBox(height: Medidas.espacio5),
          BotonPrincipal(
            texto: _editando ? 'Guardar cambios' : 'Guardar',
            icono: Icons.check_rounded,
            alPresionar: _guardando ? null : _guardar,
          ),
          if (_editando) ...[
            const SizedBox(height: Medidas.espacio2),
            BotonTexto(
              texto: _confirmarBorrado ? 'Toca otra vez para borrarla' : 'Borrar comida',
              icono: Icons.delete_outline_rounded,
              anchoCompleto: true,
              alPresionar: _guardando ? null : _borrar,
            ),
          ],
          BotonTexto(
            texto: 'Cancelar',
            anchoCompleto: true,
            alPresionar: _guardando ? null : () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
