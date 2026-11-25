import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/db/fechas.dart';
import '../../core/diseno.dart';
import 'calendario_repositorio.dart';
import 'override/antiguedad.dart';
import 'override/override_repositorio.dart';
import 'resumen_mes.dart';

/// Pestaña Calendario: semáforo mensual (ENT-60 / ENT-107, RF-08).
///
/// Diseño: `docs/pantallas/04_calendario.png`. El mes completo con un círculo
/// por día: verde (completa), naranja (parcial), azul (descanso) y gris (día de
/// entrenamiento sin registro). Hoy va en tinta con su número y los días que
/// vienen, sin color. Las flechas cambian de mes y al tocar un día se ve qué se
/// hizo: ejercicios y series.
///
/// Un día gris de los últimos 30 se puede "Forzar a completado" (ENT-70, RF-09);
/// los de más de 30 días ya no se pueden cambiar (RF-10).
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
          'Los días se pintan solos al terminar la rutina. Toca un día para ver qué hiciste '
          'o, si es de los últimos $diasEditables, marcarlo después.',
          style: textos.bodySmall,
        ),
        // ENT-71: resumen del mes debajo del calendario.
        const SizedBox(height: Medidas.espacio5),
        _ResumenDelMes(primerDia: DateTime.utc(datos.anio, datos.mes)),
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

/// Tarjetas de resumen del mes (ENT-71 / ENT-120): cumplimiento, volumen y
/// los 3 ejercicios con más progreso. Los días por color ya están en la leyenda.
class _ResumenDelMes extends ConsumerWidget {
  const _ResumenDelMes({required this.primerDia});

  final DateTime primerDia;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumen = ref.watch(resumenMesProvider(primerDia)).value;
    if (resumen == null) return const SizedBox.shrink();
    final textos = Theme.of(context).textTheme;
    final volumen = NumberFormat.decimalPattern('es_MX').format(resumen.volumenKg.round());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EtiquetaSeccion('Resumen del mes'),
        const SizedBox(height: Medidas.espacio3),
        Row(
          children: [
            Expanded(
              child: TarjetaDato(
                valor: resumen.porcentaje == null ? '—' : '${resumen.porcentaje}',
                unidad: resumen.porcentaje == null ? null : '%',
                etiqueta: 'Cumplimiento',
              ),
            ),
            const SizedBox(width: Medidas.espacio3),
            Expanded(child: TarjetaDato(valor: volumen, unidad: 'kg', etiqueta: 'Volumen levantado')),
          ],
        ),
        const SizedBox(height: Medidas.espacio5),
        const EtiquetaSeccion('Más progreso'),
        const SizedBox(height: Medidas.espacio3),
        if (resumen.top.isEmpty)
          const Aviso('Todavía no subes de peso en ningún ejercicio este mes.', icono: Icons.trending_flat_rounded)
        else
          for (final p in resumen.top) ...[
            Tarjeta(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.nombre, style: textos.titleMedium, overflow: TextOverflow.ellipsis),
                        Text(
                          '${_HojaDetalle._kg(p.primeroKg)} → ${_HojaDetalle._kg(p.ultimoKg)} kg',
                          style: textos.bodySmall?.copyWith(fontFeatures: TipografiaEntrenAndo.numerosTabulares),
                        ),
                      ],
                    ),
                  ),
                  Pastilla('+${_HojaDetalle._kg(p.diferenciaKg)} kg'),
                ],
              ),
            ),
            const SizedBox(height: Medidas.espacio2),
          ],
      ],
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
              if (dia.estado == EstadoDia.descanso) {
                return const Aviso('Día de descanso según tu rutina.', icono: Icons.info_outline_rounded);
              }
              // ENT-70: un día gris de los últimos 30 días se puede forzar a completado.
              final fechaTexto = Fechas.fecha(dia.fecha);
              if (dia.estado != EstadoDia.sinActividad) {
                return const Aviso('No registraste entrenamiento este día.', icono: Icons.info_outline_rounded);
              }
              if (!sePuedeEditar(fechaTexto)) {
                return const Aviso(
                  'Ya pasaron más de $diasEditables días: este día no se puede cambiar.',
                  icono: Icons.lock_outline_rounded,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Aviso(
                    '¿Entrenaste y olvidaste registrarlo? Se copia tu última sesión de ese día de la rutina.',
                    icono: Icons.info_outline_rounded,
                  ),
                  const SizedBox(height: Medidas.espacio4),
                  BotonSecundario(
                    texto: 'Forzar a completado',
                    icono: Icons.check_circle_outline_rounded,
                    nivel: 2,
                    alPresionar: () => _forzar(context, ref, fechaTexto),
                  ),
                ],
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

  /// Crea la sesión con es_override = 1 y repinta el mes al instante.
  Future<void> _forzar(BuildContext context, WidgetRef ref, String fecha) async {
    try {
      final repositorio = await ref.read(overrideRepositorioProvider.future);
      await repositorio?.forzarCompletado(fecha);
      ref.invalidate(mesCalendarioProvider(DateTime.utc(dia.fecha.year, dia.fecha.month)));
      ref.invalidate(detalleDiaProvider(fecha));
      if (context.mounted) Navigator.pop(context);
    } catch (error) {
      if (!context.mounted) return;
      final mensaje = error is StateError ? error.message : '$error';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
    }
  }

  static String _kg(double kg) => kg % 1 == 0 ? kg.toStringAsFixed(0) : kg.toStringAsFixed(1);
}
