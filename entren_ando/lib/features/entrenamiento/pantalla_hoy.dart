import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/db/fechas.dart';
import '../../core/diseno.dart';
import 'hoy_repositorio.dart';

/// Pestaña Hoy (módulo entrenamiento).
///
/// Pantalla inicial del proyecto base: muestra la plantilla del día desde la
/// base local con los componentes del diseño. La vista completa (estado de
/// cada ejercicio, botón "Seguir entrenando" y el resto de la semana) la hacen
/// ENT-20 y ENT-49 siguiendo el lienzo de ENT-12.
class PantallaHoy extends ConsumerWidget {
  const PantallaHoy({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diaDeHoy = ref.watch(diaDeHoyProvider);

    return Scaffold(
      body: diaDeHoy.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => MensajeCentrado(
          'No se pudo leer la base local.\n$error',
          icono: Icons.error_outline_rounded,
        ),
        data: (dia) {
          if (dia == null) {
            return const MensajeCentrado('No tienes un ciclo de rutina activo.');
          }
          final ahora = Fechas.ahoraCdmx();
          final nombreDia = DateFormat('EEEE', 'es').format(ahora);
          final fecha = DateFormat("d 'de' MMMM", 'es').format(ahora);
          final queToca = dia.esDescanso ? 'Descanso' : dia.nombreDia;
          return ContenidoPantalla(
            children: [
              EncabezadoPantalla(
                etiqueta: dia.nombreCiclo,
                titulo: nombreDia,
                subtitulo: '$fecha · $queToca',
              ),
              const SizedBox(height: Medidas.espacio5),
              if (dia.esDescanso)
                const Aviso('Hoy toca descanso. Recupérate bien.', icono: Icons.bedtime_outlined)
              else
                for (final ejercicio in dia.ejercicios) _FilaEjercicio(ejercicio),
            ],
          );
        },
      ),
    );
  }

  static String _detalle(EjercicioDelDia e) {
    if (e.trabajoSeg != null) return '${e.series} × ${e.trabajoSeg} s';
    final peso = e.pesoKg;
    final texto = '${e.series} × ${e.repeticiones}';
    if (peso == null) return texto;
    final kg = peso % 1 == 0 ? peso.toStringAsFixed(0) : peso.toStringAsFixed(1);
    return '$texto · $kg kg';
  }
}

/// Un ejercicio del día: círculo de estado, nombre y series × repeticiones.
class _FilaEjercicio extends StatelessWidget {
  const _FilaEjercicio(this.ejercicio);

  final EjercicioDelDia ejercicio;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final textos = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 46),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(color: colores.sup2, shape: BoxShape.circle),
          ),
          const SizedBox(width: Medidas.espacio3),
          Expanded(child: Text(ejercicio.nombre, style: textos.titleMedium)),
          const SizedBox(width: Medidas.espacio2),
          Text(
            PantallaHoy._detalle(ejercicio),
            style: textos.bodyMedium?.copyWith(
              color: colores.tinta2,
              fontFeatures: TipografiaEntrenAndo.numerosTabulares,
            ),
          ),
        ],
      ),
    );
  }
}
