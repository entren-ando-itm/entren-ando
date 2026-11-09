import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/db/fechas.dart';
import '../../core/diseno.dart';
import 'calendario_repositorio.dart';

/// Pestaña Calendario (módulo calendario).
///
/// Pantalla inicial del proyecto base: los últimos 14 días con el semáforo y
/// los componentes del diseño. El calendario del mes completo lo hace ENT-60
/// y guardar el cambio de un día (override con bloqueo de 30 días), ENT-70.
class PantallaCalendario extends ConsumerWidget {
  const PantallaCalendario({super.key});

  static const List<String> _diasCortos = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  static const List<String> _iniciales = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dias = ref.watch(ultimosDiasProvider);

    return Scaffold(
      body: dias.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => MensajeCentrado(
          'No se pudo leer la base local.\n$error',
          icono: Icons.error_outline_rounded,
        ),
        data: (lista) {
          if (lista.isEmpty) return const MensajeCentrado('Sin datos todavía.');
          final textos = Theme.of(context).textTheme;
          final colores = context.colores;
          final hoy = Fechas.hoyComoFecha();
          final mes = DateFormat('MMMM', 'es').format(hoy);

          // Del más antiguo al más reciente, acomodados por día de la semana.
          final ordenados = lista.reversed.toList();
          final celdas = <DiaCalendario?>[
            for (var i = 1; i < ordenados.first.fecha.weekday; i++) null,
            ...ordenados,
          ];
          while (celdas.length % 7 != 0) {
            celdas.add(null);
          }

          final conteo = <EstadoDia, int>{};
          for (final dia in lista) {
            final estado = EstadoDia.deSesion(dia.estado);
            conteo[estado] = (conteo[estado] ?? 0) + 1;
          }

          return ContenidoPantalla(
            children: [
              Semantics(header: true, child: Text('${hoy.day}', style: textos.displayLarge)),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: mes.toUpperCase()),
                          TextSpan(
                            text: ' ${hoy.year}',
                            style: TextStyle(
                              fontFamily: TipografiaEntrenAndo.barlow,
                              fontWeight: FontWeight.w400,
                              color: colores.tinta2,
                            ),
                          ),
                        ],
                      ),
                      style: textos.headlineSmall,
                    ),
                  ),
                  Text(
                    _diasCortos[hoy.weekday - 1],
                    style: textos.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colores.tinta2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              LayoutBuilder(
                builder: (context, limites) {
                  final tamano = ((limites.maxWidth - 36) / 7).clamp(28.0, 42.0);
                  return Column(
                    children: [
                      Row(
                        children: [
                          for (var i = 0; i < 7; i++)
                            Expanded(
                              child: Center(
                                child: Text(
                                  _iniciales[i],
                                  style: textos.labelMedium?.copyWith(
                                    letterSpacing: 0,
                                    color: i == hoy.weekday - 1 ? colores.tinta : colores.tinta2,
                                    fontWeight: i == hoy.weekday - 1 ? FontWeight.w700 : FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      for (var fila = 0; fila < celdas.length ~/ 7; fila++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              for (var columna = 0; columna < 7; columna++)
                                Expanded(
                                  child: Center(
                                    child: _celda(context, celdas[fila * 7 + columna], hoy, tamano),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: Medidas.espacio3),
              Wrap(
                spacing: Medidas.espacio5,
                runSpacing: 10,
                children: [
                  for (final estado in const [
                    EstadoDia.completo,
                    EstadoDia.parcial,
                    EstadoDia.descanso,
                    EstadoDia.sinActividad,
                  ])
                    ElementoLeyenda(
                      marca: PuntoSemaforo(estado),
                      texto: estado.nombre,
                      valor: '${conteo[estado] ?? 0}',
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Últimos 14 días. Los días se pintan solos al terminar la rutina; '
                'toca un día para ver las opciones.',
                style: textos.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _celda(BuildContext context, DiaCalendario? dia, DateTime hoy, double tamano) {
    if (dia == null) return SizedBox(width: tamano, height: tamano);
    final esHoy = dia.fecha.year == hoy.year && dia.fecha.month == hoy.month && dia.fecha.day == hoy.day;
    final deLaSesion = EstadoDia.deSesion(dia.estado);
    // Hoy se ve en tinta con su número hasta que se registra la rutina.
    final estado = esHoy && (deLaSesion == EstadoDia.sinActividad || deLaSesion == EstadoDia.descanso)
        ? EstadoDia.hoy
        : deLaSesion;
    final fecha = DateFormat("d 'de' MMMM", 'es').format(dia.fecha);
    final marcadoDespues = dia.esOverride ? ' (marcado después)' : '';
    return CirculoDia(
      estado: estado,
      numero: esHoy ? dia.fecha.day : null,
      tamano: tamano,
      descripcion: '$fecha: ${estado.nombre.toLowerCase()}$marcadoDespues',
      alTocar: esHoy ? null : () => _mostrarOpciones(context, dia, fecha),
    );
  }

  /// Ejemplo de la hoja "tocar un día" del lienzo. Guardar el cambio lo hace ENT-70.
  Future<void> _mostrarOpciones(BuildContext context, DiaCalendario dia, String fecha) async {
    final actual = EstadoDia.deSesion(dia.estado);
    final elegido = await mostrarHojaInferior<EstadoDia>(
      context: context,
      constructor: (contexto) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EncabezadoHoja(
            titulo: fecha,
            subtitulo: 'Ahora: ${actual.nombre.toLowerCase()}',
            inicio: CirculoDia(estado: actual, numero: dia.fecha.day),
          ),
          const SizedBox(height: 20),
          const EtiquetaSeccion('¿Qué pasó ese día?'),
          const SizedBox(height: 10),
          for (final opcion in const [EstadoDia.completo, EstadoDia.parcial, EstadoDia.descanso]) ...[
            FilaOpcion(
              titulo: opcion.nombre,
              descripcion: switch (opcion) {
                EstadoDia.completo => 'Se llena con los pesos de la sesión anterior',
                EstadoDia.parcial => 'Eliges qué ejercicios sí hiciste',
                _ => 'Ese día descansaste',
              },
              inicio: PuntoSemaforo(opcion, tamano: 22),
              seleccionada: actual == opcion,
              alTocar: () => Navigator.pop(contexto, opcion),
            ),
            const SizedBox(height: Medidas.espacio2),
          ],
          BotonTexto(
            texto: 'Cancelar',
            anchoCompleto: true,
            alPresionar: () => Navigator.pop(contexto),
          ),
        ],
      ),
    );
    if (elegido == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ejemplo del diseño: guardar "${elegido.nombre}" lo hace ENT-70.')),
    );
  }
}
