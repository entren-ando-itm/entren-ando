import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/db/fechas.dart';
import '../../core/diseno.dart';
import 'comidas_repositorio.dart';

/// Pestaña Comidas (módulo nutrición).
///
/// Pantalla inicial del proyecto base: las comidas de hoy desde la base local
/// con los componentes del diseño. Los botones de escanear y registrar, los
/// macros y el aviso sin red los hacen ENT-45 y ENT-65 siguiendo el lienzo.
class PantallaComidas extends ConsumerWidget {
  const PantallaComidas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comidas = ref.watch(comidasDeHoyProvider);

    return Scaffold(
      body: comidas.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => MensajeCentrado(
          'No se pudo leer la base local.\n$error',
          icono: Icons.error_outline_rounded,
        ),
        data: (hoy) {
          final fecha = DateFormat("EEEE d 'de' MMMM", 'es').format(Fechas.ahoraCdmx());
          return ContenidoPantalla(
            children: [
              EtiquetaSeccion('Hoy · $fecha'),
              const SizedBox(height: 6),
              NumeroConUnidad(numero: '${hoy.totalCalorias}', unidad: 'kcal', tamano: 104),
              const SizedBox(height: 22),
              if (hoy.comidas.isEmpty)
                const Aviso('Todavía no registras comidas hoy.')
              else
                for (final comida in hoy.comidas) ...[
                  _FilaComida(comida),
                  const SizedBox(height: Medidas.espacio2),
                ],
            ],
          );
        },
      ),
    );
  }
}

/// Una comida: hora, descripción (y si fue con IA) y sus kcal.
class _FilaComida extends StatelessWidget {
  const _FilaComida(this.comida);

  final Comida comida;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final textos = Theme.of(context).textTheme;
    return Tarjeta(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              comida.hora,
              style: TextStyle(
                fontFamily: TipografiaEntrenAndo.condensada,
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: colores.tinta2,
                fontFeatures: TipografiaEntrenAndo.numerosTabulares,
              ),
            ),
          ),
          const SizedBox(width: Medidas.espacio3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(comida.descripcion, style: textos.titleMedium),
                if (comida.porIa)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Icon(Icons.auto_awesome_outlined, size: 14, color: colores.tinta2),
                            ),
                          ),
                          const TextSpan(text: 'Escaneo con IA'),
                        ],
                      ),
                      style: textos.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Medidas.espacio3),
          NumeroConUnidad(numero: '${comida.calorias}', unidad: 'kcal', tamano: 22),
        ],
      ),
    );
  }
}
