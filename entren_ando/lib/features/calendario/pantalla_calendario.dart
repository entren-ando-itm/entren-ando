import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/db/fechas.dart';
import '../../core/diseno.dart';
import 'calendario_repositorio.dart';

/// Pestaña Calendario: semáforo mensual (ENT-60 / ENT-107, RF-08).
///
/// Diseño: `docs/pantallas/04_calendario.png`. El mes completo con un círculo
/// por día: verde (completa), naranja (parcial), azul (descanso) y gris (día de
/// entrenamiento sin registro). Hoy va en tinta con su número y los días que
/// vienen, sin color. Las flechas cambian de mes y al tocar un día se ve qué se
/// hizo: ejercicios y series.
///
/// Cambiar lo que pasó un día (override con bloqueo de 30 días) es ENT-70.
class PantallaCalendario extends ConsumerWidget {
  const PantallaCalendario({super.key});

  static const List<String> _diasCortos = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  static const List<String> _iniciales = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primerDia = ref.watch(mesVisibleProvider);
    final mes = ref.watch(mesCalendarioProvider(primerDia));

    return Scaffold(
      body: mes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => MensajeCentrado(
          'No se pudo leer la base local.\n$error',
          icono: Icons.error_outline_rounded,
        ),
        data: (datos) {
          if (datos == null) return const MensajeCentrado('Sin datos todavía.');
          return _contenido(context, ref, datos);
        },
      ),
    );
  }

  Widget _contenido(BuildContext context, WidgetRef ref, MesCalendario datos) {
    final textos = Theme.of(context).textTheme;
    final colores = context.colores;
    final hoy = Fechas.hoyComoFecha();
    final esMesActual = datos.anio == hoy.year && datos.mes == hoy.month;
    final nombreMes = DateFormat('MMMM', 'es').format(DateTime.utc(datos.anio, datos.mes));
    final control = ref.read(mesVisibleProvider.notifier);

    // Celdas vacías antes del día 1 para que empiece en su día de la semana.
    final celdas = <DiaMes?>[
      for (var i = 1; i < datos.dias.first.fecha.weekday; i++) null,
      ...datos.dias,
    ];
    while (celdas.length % 7 != 0) {
      celdas.add(null);
    }
    final conteo = datos.conteo;

    return ContenidoPantalla(
      children: [
        // El número grande es hoy; en otro mes, el número del mes.
        Semantics(
          header: true,
          child: Text(esMesActual ? '${hoy.day}' : '${datos.mes}', style: textos.displayLarge),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: nombreMes.toUpperCase()),
                    TextSpan(
                      text: ' ${datos.anio}',
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
            BotonCircular(
              icono: Icons.chevron_left_rounded,
              descripcion: 'Mes anterior',
              nivel: 2,
              alPresionar: control.anterior,
            ),
            const SizedBox(width: Medidas.espacio2),
            BotonCircular(
              icono: Icons.chevron_right_rounded,
              descripcion: 'Mes siguiente',
              nivel: 2,
              // No hay nada que ver en los meses que vienen.
              alPresionar: esMesActual ? null : control.siguiente,
            ),
          ],
        ),
        if (esMesActual)
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              _diasCortos[hoy.weekday - 1],
              style: textos.headlineSmall?.copyWith(fontWeight: FontWeight.w600, color: colores.tinta2),
            ),
          )
        else
          Align(
            alignment: Alignment.centerRight,
            child: BotonTexto(texto: 'Volver a hoy', alPresionar: control.irAHoy),
          ),
        const SizedBox(height: Medidas.espacio5),
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
                              color: esMesActual && i == hoy.weekday - 1 ? colores.tinta : colores.tinta2,
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
        // Leyenda con cuántos días hay de cada color en el mes.
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
          'Los días se pintan solos al terminar la rutina. Toca un día para ver qué hiciste.',
          style: textos.bodySmall,
        ),
        // ENT-108: solo en debug, para medir que cargue en menos de 1.5 s.
        if (kDebugMode && datos.milisegundos != null) ...[
          const SizedBox(height: Medidas.espacio2),
          Text('Cargó en ${datos.milisegundos} ms (solo debug)', style: textos.bodySmall),
        ],
      ],
    );
  }

  Widget _celda(BuildContext context, DiaMes? dia, DateTime hoy, double tamano) {
    if (dia == null) return SizedBox(width: tamano, height: tamano);
    final esHoy = dia.fecha == hoy;
    final fecha = DateFormat("EEEE d 'de' MMMM", 'es').format(dia.fecha);
    final marcadoDespues = dia.esOverride ? ' (marcado después)' : '';
    final sinColor = dia.estado == EstadoDia.futuro;
    return CirculoDia(
      estado: dia.estado,
      numero: esHoy ? dia.fecha.day : null,
      tamano: tamano,
      descripcion: sinColor
          ? '$fecha: sin registro'
          : '$fecha: ${dia.estado.nombre.toLowerCase()}$marcadoDespues',
      alTocar: sinColor ? null : () => _mostrarDetalle(context, dia, fecha),
    );
  }

  /// Hoja "qué hice ese día": ejercicios y series (criterio 2 de ENT-60).
  Future<void> _mostrarDetalle(BuildContext context, DiaMes dia, String fecha) {
    return mostrarHojaInferior<void>(
      context: context,
      constructor: (contexto) => _HojaDetalle(dia: dia, fecha: fecha),
    );
  }
}

class _HojaDetalle extends ConsumerWidget {
  const _HojaDetalle({required this.dia, required this.fecha});

  final DiaMes dia;
  final String fecha;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = Theme.of(context).textTheme;
    final detalle = ref.watch(detalleDiaProvider(Fechas.fecha(dia.fecha)));
    final titulo = fecha[0].toUpperCase() + fecha.substring(1);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EncabezadoHoja(
          titulo: titulo,
          subtitulo: dia.estado.nombre + (dia.esOverride ? ' · marcado después' : ''),
          inicio: CirculoDia(estado: dia.estado, numero: dia.fecha.day),
        ),
        const SizedBox(height: Medidas.espacio4),
        detalle.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(Medidas.espacio5),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Aviso('No se pudo leer el día: $error', icono: Icons.error_outline_rounded),
          data: (d) {
            if (d == null) {
              return Aviso(
                dia.estado == EstadoDia.descanso
                    ? 'Día de descanso según tu rutina.'
                    : 'No registraste entrenamiento este día.',
                icono: Icons.info_outline_rounded,
              );
            }
            if (d.ejercicios.isEmpty) {
              return Aviso(
                d.estado == 'descanso' ? 'Ese día descansaste.' : 'Sin ejercicios registrados.',
                icono: Icons.info_outline_rounded,
              );
            }
            return ConstrainedBox(
              // La hoja no pasa de media pantalla; lo demás se desliza.
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.5),
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (d.nombreDia != null) ...[
                    EtiquetaSeccion(d.nombreDia!),
                    const SizedBox(height: Medidas.espacio2),
                  ],
                  for (final e in d.ejercicios) ...[
                    Tarjeta(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(e.nombre, style: textos.titleMedium)),
                              if (e.completado)
                                const Icon(Icons.check_circle_rounded, size: 20, color: ColoresSemaforo.completa),
                            ],
                          ),
                          const SizedBox(height: Medidas.espacio1),
                          Text(
                            e.series.isEmpty
                                ? 'Sin series guardadas'
                                : e.series
                                    .map((s) => '${_kg(s.pesoKg)} kg × ${s.repeticiones}')
                                    .join('  ·  '),
                            style: textos.bodyMedium?.copyWith(
                              fontFeatures: TipografiaEntrenAndo.numerosTabulares,
                            ),
                          ),
                          if (e.esSustitucion) Text('Cambiado solo ese día', style: textos.bodySmall),
                        ],
                      ),
                    ),
                    const SizedBox(height: Medidas.espacio2),
                  ],
                  if (d.comentario != null) ...[
                    const SizedBox(height: Medidas.espacio2),
                    Text('"${d.comentario}"', style: textos.bodySmall),
                  ],
                ],
              ),
            );
          },
        ),
        const SizedBox(height: Medidas.espacio4),
        BotonTexto(texto: 'Cerrar', anchoCompleto: true, alPresionar: () => Navigator.pop(context)),
      ],
    );
  }

  static String _kg(double kg) => kg % 1 == 0 ? kg.toStringAsFixed(0) : kg.toStringAsFixed(1);
}
