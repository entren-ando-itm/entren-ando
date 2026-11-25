import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/conectividad/boton_con_red.dart';
import '../../core/diseno.dart';
import 'hoja_limite_ciclos.dart';
import 'rutinas_proveedores.dart';
import 'rutinas_repositorio.dart';

/// Mis ciclos (ENT-47): activos y archivados, y el botón para crear uno.
class PantallaCiclos extends ConsumerWidget {
  const PantallaCiclos({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ciclos = ref.watch(ciclosProvider);
    final limite = ref.watch(limiteCiclosProvider).value;
    final textos = Theme.of(context).textTheme;

    final maximo = limite?.maximo;
    final subtitulo = limite == null
        ? 'Tu rutina por semestres'
        : maximo == null
            ? 'Plan ${limite.plan} · ciclos activos sin límite'
            : 'Plan ${limite.plan} · ${limite.activos} de $maximo ciclo${maximo == 1 ? '' : 's'} activo'
                '${maximo == 1 ? '' : 's'}';

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
          EncabezadoPantalla(etiqueta: 'Rutina', titulo: 'Mis ciclos', subtitulo: subtitulo),
          const SizedBox(height: Medidas.espacio5),
          BotonPrincipal(
            texto: 'Nuevo ciclo',
            icono: Icons.add_rounded,
            alPresionar: ciclos.isLoading ? null : () => _nuevoCiclo(context, ref),
          ),
          const SizedBox(height: Medidas.espacio2),
          // ENT-58 (ENT-102): sin red se desactiva y sugiere crearla a mano (RNF-02).
          BotonConRed(
            alPresionar: () => context.push('/perfil/ciclos/ia'),
            avisoSinRed: 'Sin conexión. La rutina con IA vuelve cuando tengas red; mientras, '
                'crea tu ciclo a mano con "Nuevo ciclo".',
            boton: (alPresionar) => BotonSecundario(
              texto: 'Generar con IA',
              icono: Icons.auto_awesome_outlined,
              alPresionar: alPresionar,
            ),
          ),
          const SizedBox(height: Medidas.espacio5),
          ...ciclos.when(
            loading: () => const [Center(child: CircularProgressIndicator())],
            error: (error, _) => const [
              Aviso('No se pudieron leer tus ciclos.', icono: Icons.error_outline_rounded),
            ],
            data: (lista) {
              if (lista.isEmpty) {
                return [
                  Text(
                    'Todavía no tienes ciclos. Crea uno y arma tu semana.',
                    style: textos.bodyMedium?.copyWith(color: context.colores.tinta2),
                  ),
                ];
              }
              final activos = lista.where((c) => c.activo).toList();
              final archivados = lista.where((c) => !c.activo).toList();
              return [
                if (activos.isNotEmpty) ...[
                  const EtiquetaSeccion('Activos'),
                  const SizedBox(height: 10),
                  for (final ciclo in activos) ...[
                    _TarjetaCiclo(ciclo),
                    const SizedBox(height: Medidas.espacio2),
                  ],
                  const SizedBox(height: Medidas.espacio4),
                ],
                if (archivados.isNotEmpty) ...[
                  const EtiquetaSeccion('Archivados'),
                  const SizedBox(height: 10),
                  for (final ciclo in archivados) ...[
                    _TarjetaCiclo(ciclo),
                    const SizedBox(height: Medidas.espacio2),
                  ],
                ],
              ];
            },
          ),
        ],
      ),
    );
  }

  Future<void> _nuevoCiclo(BuildContext context, WidgetRef ref) async {
    final repositorio = await ref.read(rutinasRepositorioProvider.future);
    if (repositorio == null || !context.mounted) return;
    final idNuevo = await mostrarHojaInferior<String>(
      context: context,
      constructor: (contexto) => HojaDatosCiclo(repositorio: repositorio),
    );
    if (idNuevo == null || !context.mounted) return;
    refrescarRutinas(ref);
    context.push('/perfil/ciclos/$idNuevo');
  }
}

class _TarjetaCiclo extends StatelessWidget {
  const _TarjetaCiclo(this.ciclo);

  final Ciclo ciclo;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final dias = ciclo.diasEntrenamiento;
    final detalle = [
      dias == 1 ? '1 día de entrenamiento' : '$dias días de entrenamiento',
      if (ciclo.origen == 'ia') 'Hecho con IA',
    ].join(' · ');
    return Tarjeta(
      alTocar: () => context.push('/perfil/ciclos/${ciclo.idCiclo}'),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ciclo.nombre, style: textos.titleMedium),
                const SizedBox(height: 2),
                Text(FechaCiclo.rango(ciclo.fechaInicio, ciclo.fechaFin), style: textos.bodySmall),
                const SizedBox(height: 2),
                Text(detalle, style: textos.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: Medidas.espacio2),
          Pastilla(ciclo.activo ? 'Activo' : 'Archivado', chica: true, resaltada: ciclo.activo),
          Icon(Icons.chevron_right_rounded, color: context.colores.tinta2),
        ],
      ),
    );
  }
}

/// Hoja con nombre y fechas de un ciclo. Sin [ciclo] crea uno nuevo y
/// devuelve su id; con [ciclo] lo edita y devuelve su id.
///
/// Al crear, si el plan ya no permite otro activo, pide archivar uno o ver
/// Premium (RN-01).
class HojaDatosCiclo extends StatefulWidget {
  const HojaDatosCiclo({super.key, required this.repositorio, this.ciclo});

  final RutinasRepositorio repositorio;
  final Ciclo? ciclo;

  @override
  State<HojaDatosCiclo> createState() => _HojaDatosCicloState();
}

class _HojaDatosCicloState extends State<HojaDatosCiclo> {
  final GlobalKey<FormState> _formulario = GlobalKey<FormState>();
  late final TextEditingController _nombre = TextEditingController(text: widget.ciclo?.nombre ?? '');
  late final TextEditingController _inicio = TextEditingController(
    text: FechaCiclo.aCampo(widget.ciclo?.fechaInicio ?? RutinasRepositorio.hoy()),
  );
  late final TextEditingController _fin = TextEditingController(
    text: () {
      final ciclo = widget.ciclo;
      if (ciclo == null) return FechaCiclo.aCampo(FechaCiclo.finSugerido(RutinasRepositorio.hoy()));
      final fin = ciclo.fechaFin;
      return fin == null ? '' : FechaCiclo.aCampo(fin);
    }(),
  );
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _inicio.dispose();
    _fin.dispose();
    super.dispose();
  }

  String? _validarInicio(String? texto) =>
      FechaCiclo.deCampo(texto) == null ? 'Escribe la fecha como 17/11/2026.' : null;

  String? _validarFin(String? texto) {
    if ((texto ?? '').trim().isEmpty) return null;
    final fin = FechaCiclo.deCampo(texto);
    if (fin == null) return 'Escribe la fecha como 30/06/2027 o déjala vacía.';
    final inicio = FechaCiclo.deCampo(_inicio.text);
    return inicio == null ? null : ValidarRutina.fechas(inicio, fin);
  }

  Future<void> _guardar() async {
    if (!(_formulario.currentState?.validate() ?? false)) return;
    final nombre = _nombre.text.trim();
    final inicio = FechaCiclo.deCampo(_inicio.text)!;
    final fin = _fin.text.trim().isEmpty ? null : FechaCiclo.deCampo(_fin.text);
    final repositorio = widget.repositorio;
    final ciclo = widget.ciclo;

    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      if (ciclo != null) {
        await repositorio.actualizarCiclo(ciclo.idCiclo, nombre: nombre, fechaInicio: inicio, fechaFin: fin);
        if (mounted) Navigator.pop(context, ciclo.idCiclo);
        return;
      }
      final limite = await repositorio.limite();
      if (limite.puedeActivarOtro) {
        final id = await repositorio.crearCiclo(nombre: nombre, fechaInicio: inicio, fechaFin: fin);
        if (mounted) Navigator.pop(context, id);
        return;
      }
      if (!mounted) return;
      final activos = (await repositorio.ciclos()).where((c) => c.activo).toList();
      if (!mounted) return;
      final eleccion = await mostrarHojaLimiteCiclos(context, limite: limite, activos: activos);
      if (!mounted) return;
      switch (eleccion) {
        case ArchivarCiclo(:final idCiclo):
          final id = await repositorio.crearCiclo(
            nombre: nombre,
            fechaInicio: inicio,
            fechaFin: fin,
            activar: false,
          );
          await repositorio.activarCiclo(id, archivarAntes: [idCiclo]);
          if (mounted) Navigator.pop(context, id);
        case VerPremium():
          setState(() => _guardando = false);
          await mostrarPremiumPronto(context);
        case null:
          setState(() => _guardando = false);
      }
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
    final editando = widget.ciclo != null;
    return Form(
      key: _formulario,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EncabezadoHoja(
            titulo: editando ? 'Editar ciclo' : 'Nuevo ciclo',
            subtitulo: editando ? null : 'Después armas los 7 días',
          ),
          const SizedBox(height: Medidas.espacio5),
          CampoTexto(
            etiqueta: 'Nombre',
            controlador: _nombre,
            pista: 'Por ejemplo: Semestre enero-junio',
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
                  accionTeclado: TextInputAction.next,
                  validar: _validarInicio,
                ),
              ),
              const SizedBox(width: Medidas.espacio3),
              Expanded(
                child: CampoTexto(
                  etiqueta: 'Fin (opcional)',
                  controlador: _fin,
                  pista: 'dd/mm/aaaa',
                  teclado: TextInputType.datetime,
                  accionTeclado: TextInputAction.done,
                  validar: _validarFin,
                ),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: Medidas.espacio4),
            Aviso(error, icono: Icons.error_outline_rounded),
          ],
          const SizedBox(height: Medidas.espacio5),
          BotonPrincipal(
            texto: editando ? 'Guardar cambios' : 'Crear ciclo',
            icono: Icons.check_rounded,
            alPresionar: _guardando ? null : _guardar,
          ),
        ],
      ),
    );
  }
}
