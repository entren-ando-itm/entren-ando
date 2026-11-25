import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/diseno.dart';
import 'hoja_limite_ciclos.dart';
import 'pantalla_ciclos.dart';
import 'rutinas_proveedores.dart';
import 'rutinas_repositorio.dart';

/// Un ciclo con sus 7 días, como un horario escolar (ENT-47).
///
/// Si está archivado se ve en solo lectura y se puede reactivar respetando
/// el límite del plan.
class PantallaCiclo extends ConsumerWidget {
  const PantallaCiclo({super.key, required this.idCiclo});

  final String idCiclo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ciclo = ref.watch(cicloProvider(idCiclo));
    final dias = ref.watch(diasCicloProvider(idCiclo));

    return Scaffold(
      body: ciclo.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => const MensajeCentrado(
          'No se pudo leer el ciclo.',
          icono: Icons.error_outline_rounded,
        ),
        data: (datos) {
          if (datos == null) return const MensajeCentrado('Este ciclo ya no existe.');
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
                etiqueta: datos.activo ? 'Ciclo activo' : 'Ciclo archivado',
                titulo: datos.nombre,
                subtitulo: FechaCiclo.rango(datos.fechaInicio, datos.fechaFin),
                estiloTitulo: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: Medidas.espacio5),
              if (!datos.activo) ...[
                const Aviso('Está archivado: lo ves en solo lectura. Reactívalo para editarlo.',
                    icono: Icons.lock_outline_rounded),
                const SizedBox(height: Medidas.espacio4),
                BotonPrincipal(
                  texto: 'Reactivar ciclo',
                  icono: Icons.unarchive_outlined,
                  alPresionar: () => _reactivar(context, ref, datos),
                ),
                const SizedBox(height: Medidas.espacio5),
              ],
              const EtiquetaSeccion('Semana'),
              const SizedBox(height: 10),
              ...dias.when(
                loading: () => const [Center(child: CircularProgressIndicator())],
                error: (error, _) => const [
                  Aviso('No se pudieron leer los días.', icono: Icons.error_outline_rounded),
                ],
                data: (lista) => [
                  for (final dia in lista) ...[
                    _FilaDia(dia: dia, alTocar: () => context.push('/perfil/ciclos/$idCiclo/dia/${dia.idDia}')),
                    const SizedBox(height: Medidas.espacio2),
                  ],
                ],
              ),
              if (datos.activo) ...[
                const SizedBox(height: Medidas.espacio4),
                BotonSecundario(
                  texto: 'Editar nombre y fechas',
                  icono: Icons.edit_outlined,
                  alPresionar: () => _editar(context, ref, datos),
                ),
                const SizedBox(height: Medidas.espacio2),
                BotonTexto(
                  texto: 'Archivar ciclo',
                  icono: Icons.inventory_2_outlined,
                  anchoCompleto: true,
                  alPresionar: () => _archivar(context, ref, datos),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _editar(BuildContext context, WidgetRef ref, Ciclo ciclo) async {
    final repositorio = await ref.read(rutinasRepositorioProvider.future);
    if (repositorio == null || !context.mounted) return;
    final guardado = await mostrarHojaInferior<String>(
      context: context,
      constructor: (contexto) => HojaDatosCiclo(repositorio: repositorio, ciclo: ciclo),
    );
    if (guardado != null) refrescarRutinas(ref);
  }

  Future<void> _archivar(BuildContext context, WidgetRef ref, Ciclo ciclo) async {
    final confirmar = await mostrarHojaInferior<bool>(
      context: context,
      constructor: (contexto) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EncabezadoHoja(
            titulo: 'Archivar ciclo',
            subtitulo: '«${ciclo.nombre}» deja de verse en Hoy. No se borra: lo puedes reactivar después.',
          ),
          const SizedBox(height: Medidas.espacio5),
          BotonPrincipal(
            texto: 'Archivar',
            icono: Icons.inventory_2_outlined,
            alPresionar: () => Navigator.pop(contexto, true),
          ),
          const SizedBox(height: Medidas.espacio2),
          BotonTexto(texto: 'Cancelar', anchoCompleto: true, alPresionar: () => Navigator.pop(contexto, false)),
        ],
      ),
    );
    if (confirmar != true) return;
    final repositorio = await ref.read(rutinasRepositorioProvider.future);
    await repositorio?.archivarCiclo(ciclo.idCiclo);
    refrescarRutinas(ref);
  }

  Future<void> _reactivar(BuildContext context, WidgetRef ref, Ciclo ciclo) async {
    final repositorio = await ref.read(rutinasRepositorioProvider.future);
    if (repositorio == null) return;
    final limite = await repositorio.limite();
    if (!context.mounted) return;
    var archivar = <String>[];
    if (!limite.puedeActivarOtro) {
      final activos = (await repositorio.ciclos()).where((c) => c.activo).toList();
      if (!context.mounted) return;
      final eleccion = await mostrarHojaLimiteCiclos(context, limite: limite, activos: activos);
      if (!context.mounted) return;
      switch (eleccion) {
        case ArchivarCiclo(:final idCiclo):
          archivar = [idCiclo];
        case VerPremium():
          await context.push('/perfil/premium');
          return;
        case null:
          return;
      }
    }
    await repositorio.activarCiclo(ciclo.idCiclo, archivarAntes: archivar);
    refrescarRutinas(ref);
  }
}

/// Un día de la semana: "LUNES · Pierna · 5 ejercicios" o "Descanso".
class _FilaDia extends StatelessWidget {
  const _FilaDia({required this.dia, required this.alTocar});

  final DiaRutina dia;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final colores = context.colores;
    final detalle = dia.esDescanso
        ? 'Descanso'
        : '${dia.nombre} · ${dia.ejercicios == 1 ? '1 ejercicio' : '${dia.ejercicios} ejercicios'}';
    return Tarjeta(
      nivel: dia.esDescanso ? 1 : 2,
      alTocar: alTocar,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Text(dia.nombreDiaSemana.toUpperCase(), style: textos.titleLarge),
          const SizedBox(width: Medidas.espacio3),
          // Expanded y alineado al final para que todas las flechas queden en la orilla.
          Expanded(
            child: Text(
              detalle,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: textos.bodyMedium?.copyWith(color: dia.esDescanso ? colores.tinta2 : colores.tinta),
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: colores.tinta2),
        ],
      ),
    );
  }
}
