import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/diseno.dart';
import 'perfil_repositorio.dart';

final _medicionesProvider = FutureProvider.autoDispose<List<Medicion>>((ref) async {
  final repositorio = await ref.watch(perfilRepositorioProvider.future);
  return repositorio?.mediciones() ?? const [];
});

/// Historial de mediciones y botón para agregar una nueva (ENT-18).
class PantallaMediciones extends ConsumerWidget {
  const PantallaMediciones({super.key});

  static String numero(double valor) =>
      valor % 1 == 0 ? valor.toStringAsFixed(0) : valor.toStringAsFixed(1);

  Future<void> _nuevaMedicion(BuildContext context, WidgetRef ref, Medicion? ultima) async {
    final repositorio = await ref.read(perfilRepositorioProvider.future);
    if (repositorio == null || !context.mounted) return;
    final guardo = await mostrarHojaInferior<bool>(
      context: context,
      constructor: (contexto) => _HojaMedicion(repositorio: repositorio, ultima: ultima),
    );
    if (guardo == true) {
      ref.invalidate(_medicionesProvider);
      ref.invalidate(resumenPerfilProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediciones = ref.watch(_medicionesProvider);
    final textos = Theme.of(context).textTheme;
    final lista = mediciones.value ?? const <Medicion>[];

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
          const EncabezadoPantalla(
            etiqueta: 'Perfil',
            titulo: 'Mediciones',
            subtitulo: 'Peso, estatura y grasa con su fecha',
          ),
          const SizedBox(height: Medidas.espacio5),
          BotonPrincipal(
            texto: 'Nueva medición',
            icono: Icons.add_rounded,
            alPresionar: mediciones.isLoading
                ? null
                : () => _nuevaMedicion(context, ref, lista.isEmpty ? null : lista.first),
          ),
          const SizedBox(height: Medidas.espacio5),
          const EtiquetaSeccion('Historial'),
          const SizedBox(height: 10),
          ...mediciones.when(
            loading: () => const [Center(child: CircularProgressIndicator())],
            error: (error, _) => const [
              Aviso('No se pudieron leer tus mediciones.', icono: Icons.error_outline_rounded),
            ],
            data: (datos) => datos.isEmpty
                ? [
                    Text(
                      'Todavía no tienes mediciones.',
                      style: textos.bodyMedium?.copyWith(color: context.colores.tinta2),
                    ),
                  ]
                : [
                    for (final medicion in datos) ...[
                      _FilaMedicion(medicion),
                      const SizedBox(height: Medidas.espacio2),
                    ],
                  ],
          ),
        ],
      ),
    );
  }
}

class _FilaMedicion extends StatelessWidget {
  const _FilaMedicion(this.medicion);

  final Medicion medicion;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final fecha = DateTime.tryParse(medicion.fecha);
    final grasa = medicion.porcentajeGrasa;
    final detalle = [
      '${PantallaMediciones.numero(medicion.estaturaCm)} cm',
      if (grasa != null) '${PantallaMediciones.numero(grasa)} % grasa',
    ].join(' · ');
    return Tarjeta(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fecha == null ? medicion.fecha : DateFormat("EEEE d 'de' MMMM", 'es').format(fecha),
                  style: textos.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(detalle, style: textos.bodySmall),
              ],
            ),
          ),
          NumeroConUnidad(numero: PantallaMediciones.numero(medicion.pesoKg), unidad: 'kg'),
        ],
      ),
    );
  }
}

/// Hoja para capturar una medición nueva. Devuelve true si se guardó.
class _HojaMedicion extends StatefulWidget {
  const _HojaMedicion({required this.repositorio, this.ultima});

  final PerfilRepositorio repositorio;
  final Medicion? ultima;

  @override
  State<_HojaMedicion> createState() => _HojaMedicionState();
}

class _HojaMedicionState extends State<_HojaMedicion> {
  final GlobalKey<FormState> _formulario = GlobalKey<FormState>();
  final TextEditingController _peso = TextEditingController();
  // La estatura casi no cambia: se propone la de la última medición.
  late final TextEditingController _estatura = TextEditingController(
    text: widget.ultima == null ? '' : PantallaMediciones.numero(widget.ultima!.estaturaCm),
  );
  final TextEditingController _grasa = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _peso.dispose();
    _estatura.dispose();
    _grasa.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!(_formulario.currentState?.validate() ?? false)) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.repositorio.agregarMedicion(
        pesoKg: ValidarPerfil.numero(_peso.text)!,
        estaturaCm: ValidarPerfil.numero(_estatura.text)!,
        porcentajeGrasa: ValidarPerfil.numero(_grasa.text),
      );
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

  @override
  Widget build(BuildContext context) {
    final error = _error;
    const decimal = TextInputType.numberWithOptions(decimal: true);
    return Form(
      key: _formulario,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const EncabezadoHoja(titulo: 'Nueva medición', subtitulo: 'Se guarda con la fecha de hoy'),
          const SizedBox(height: Medidas.espacio5),
          CampoTexto(
            etiqueta: 'Peso (kg)',
            controlador: _peso,
            pista: 'Por ejemplo: 74.6',
            teclado: decimal,
            accionTeclado: TextInputAction.next,
            validar: ValidarPerfil.pesoKg,
          ),
          const SizedBox(height: Medidas.espacio4),
          CampoTexto(
            etiqueta: 'Estatura (cm)',
            controlador: _estatura,
            pista: 'Por ejemplo: 175',
            teclado: decimal,
            accionTeclado: TextInputAction.next,
            validar: ValidarPerfil.estaturaCm,
          ),
          const SizedBox(height: Medidas.espacio4),
          CampoTexto(
            etiqueta: 'Grasa (%)',
            controlador: _grasa,
            pista: 'Opcional',
            teclado: decimal,
            accionTeclado: TextInputAction.done,
            validar: ValidarPerfil.porcentajeGrasa,
            alEnviar: (_) => _guardar(),
          ),
          if (error != null) ...[
            const SizedBox(height: Medidas.espacio4),
            Aviso(error, icono: Icons.error_outline_rounded),
          ],
          const SizedBox(height: Medidas.espacio5),
          BotonPrincipal(
            texto: 'Guardar medición',
            icono: Icons.check_rounded,
            alPresionar: _guardando ? null : _guardar,
          ),
        ],
      ),
    );
  }
}
