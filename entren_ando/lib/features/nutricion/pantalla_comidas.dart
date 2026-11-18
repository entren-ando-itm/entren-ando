import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/conectividad/boton_con_red.dart';
import '../../core/conectividad/conectividad.dart';
import '../../core/db/fechas.dart';
import '../../core/diseno.dart';
import 'comidas_repositorio.dart';
import 'hoja_comida.dart';

/// Pestaña Comidas (ENT-45, RF-07). Diseño: docs/pantallas/06_comidas.png y
/// 10_comidas_sin_red.png.
///
/// Total del día en calorías y macros (sin meta: no está en la ERS), registro
/// a mano y lista de comidas; tocar una comida la edita o la borra. Todo
/// funciona en modo avión. El botón "Escanear con cámara" queda desactivado
/// hasta ENT-65.
class PantallaComidas extends ConsumerWidget {
  const PantallaComidas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comidas = ref.watch(comidasDeHoyProvider);
    final hayRed = ref.watch(hayRedProvider);

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
              Row(
                children: [
                  Expanded(child: EtiquetaSeccion('Hoy · $fecha')),
                  if (!hayRed) const InsigniaSinRed(),
                ],
              ),
              const SizedBox(height: 6),
              NumeroConUnidad(numero: '${hoy.totalCalorias}', unidad: 'kcal', tamano: 104),
              if (hoy.totales.tieneMacros) ...[
                const SizedBox(height: Medidas.espacio4),
                _Macros(hoy.totales),
              ],
              const SizedBox(height: 22),
              // ENT-65 le pone la acción (escanear con IA) y el contador de
              // escaneos del día. Mientras, queda desactivado.
              BotonConRed(
                alPresionar: null,
                boton: (alPresionar) => BotonSecundario(
                  texto: 'Escanear con cámara',
                  icono: Icons.photo_camera_outlined,
                  alPresionar: alPresionar,
                ),
                avisoSinRed: 'Sin conexión. El escaneo con IA vuelve cuando tengas red; '
                    'mientras, regístralo a mano.',
              ),
              const SizedBox(height: Medidas.espacio3),
              BotonPrincipal(
                texto: 'Registrar a mano',
                icono: Icons.edit_outlined,
                alPresionar: () => mostrarHojaComida(context),
              ),
              const SizedBox(height: 22),
              if (hoy.comidas.isEmpty)
                const Aviso('Todavía no registras comidas hoy.')
              else
                for (final comida in hoy.comidas) ...[
                  _FilaComida(
                    comida,
                    alTocar: () => mostrarHojaComida(context, comida: comida),
                  ),
                  const SizedBox(height: Medidas.espacio2),
                ],
            ],
          );
        },
      ),
    );
  }
}

/// Barra de proteína, carbohidratos y grasa del día con su leyenda.
class _Macros extends StatelessWidget {
  const _Macros(this.totales);

  final TotalesDia totales;

  static String _g(double valor) =>
      '${valor == valor.roundToDouble() ? valor.toInt() : valor.toStringAsFixed(1)} g';

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final p = _g(totales.proteinas);
    final c = _g(totales.carbohidratos);
    final g = _g(totales.grasas);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BarraSegmentos(
          descripcion: 'Proteína $p, carbohidratos $c, grasa $g',
          segmentos: [
            SegmentoBarra(valor: totales.proteinas, color: colores.tinta),
            SegmentoBarra(valor: totales.carbohidratos, color: colores.medio),
            SegmentoBarra(valor: totales.grasas, color: colores.sup4),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            ElementoLeyenda(marca: MarcaColor(colores.tinta), texto: 'Proteína $p'),
            ElementoLeyenda(marca: MarcaColor(colores.medio), texto: 'Carbohidratos $c'),
            ElementoLeyenda(marca: MarcaColor(colores.sup4), texto: 'Grasa $g'),
          ],
        ),
      ],
    );
  }
}

/// Una comida: hora, descripción (y si fue con IA) y sus kcal. Se toca para
/// editarla o borrarla.
class _FilaComida extends StatelessWidget {
  const _FilaComida(this.comida, {required this.alTocar});

  final Comida comida;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final textos = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      hint: 'Toca para editar o borrar',
      child: Tarjeta(
        alTocar: alTocar,
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
                                child: Icon(Icons.photo_camera_outlined, size: 14, color: colores.tinta2),
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
      ),
    );
  }
}
