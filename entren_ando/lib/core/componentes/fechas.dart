import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../tema/colores.dart';
import '../tema/medidas.dart';
import 'botones.dart';
import 'hoja_inferior.dart';
import 'textos.dart';

/// Campo para elegir una fecha desde un calendario (no se escribe).
/// Se ve como `CampoTexto`: etiqueta arriba y superficie sup1 sin borde.
/// Las fechas van como texto ISO 'aaaa-mm-dd', igual que en la base.
///
///   CampoFecha(
///     etiqueta: 'Inicio',
///     valor: _inicio,
///     alCambiar: (fecha) => setState(() => _inicio = fecha!),
///   )
///   CampoFecha(
///     etiqueta: 'Fin (opcional)',
///     valor: _fin,
///     opcional: true,
///     desde: _inicio, // no deja elegir antes del inicio
///     alCambiar: (fecha) => setState(() => _fin = fecha),
///   )
class CampoFecha extends StatelessWidget {
  const CampoFecha({
    super.key,
    required this.etiqueta,
    required this.valor,
    required this.alCambiar,
    this.opcional = false,
    this.desde,
    this.pista = 'Sin fecha',
    this.habilitado = true,
  });

  final String etiqueta;

  /// Fecha elegida en ISO ('2026-11-23') o null si está vacía.
  final String? valor;

  /// Recibe la fecha nueva, o null si se quitó (solo cuando es opcional).
  final ValueChanged<String?> alCambiar;

  /// Muestra la opción para dejarla vacía.
  final bool opcional;

  /// Primera fecha que se puede elegir (ISO). null = sin límite.
  final String? desde;

  /// Texto gris cuando está vacía.
  final String pista;
  final bool habilitado;

  static final DateFormat _iso = DateFormat('yyyy-MM-dd');

  Future<void> _elegir(BuildContext context) async {
    final eleccion = await mostrarHojaInferior<_Eleccion>(
      context: context,
      constructor: (contexto) => _SelectorFecha(
        titulo: etiqueta.replaceAll(' (opcional)', ''),
        valor: valor,
        desde: desde,
        opcional: opcional && valor != null,
      ),
    );
    if (eleccion != null) alCambiar(eleccion.fecha);
  }

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final textos = Theme.of(context).textTheme;
    final valor = this.valor;
    final texto = valor == null ? pista : DateFormat("EEEE d 'de' MMMM 'de' y", 'es').format(DateTime.parse(valor));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EtiquetaSeccion(etiqueta),
        const SizedBox(height: 6),
        Semantics(
          button: true,
          enabled: habilitado,
          label: '$etiqueta: $texto',
          excludeSemantics: true,
          child: Material(
            color: colores.sup1,
            borderRadius: BorderRadius.circular(Medidas.radioCampo),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: habilitado ? () => _elegir(context) : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: Medidas.altoCampo),
                child: Padding(
                  padding: const EdgeInsets.only(left: 20, right: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          texto,
                          style: textos.bodyLarge?.copyWith(color: valor == null ? colores.medio : null),
                        ),
                      ),
                      if (opcional && valor != null)
                        IconButton(
                          tooltip: 'Quitar fecha',
                          icon: const Icon(Icons.close_rounded, size: 20),
                          color: colores.tinta2,
                          onPressed: habilitado ? () => alCambiar(null) : null,
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Icon(Icons.calendar_today_outlined, size: 20, color: colores.tinta2),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Convierte un DateTime a ISO 'aaaa-mm-dd'.
  static String aIso(DateTime fecha) => _iso.format(fecha);
}

/// Lo que devuelve la hoja: una fecha, o null en `fecha` si se quitó.
class _Eleccion {
  const _Eleccion(this.fecha);
  final String? fecha;
}

/// Hoja con el calendario de un mes: flechas para cambiar de mes y un toque
/// en el día para elegirlo.
class _SelectorFecha extends StatefulWidget {
  const _SelectorFecha({required this.titulo, this.valor, this.desde, required this.opcional});

  final String titulo;
  final String? valor;
  final String? desde;
  final bool opcional;

  @override
  State<_SelectorFecha> createState() => _SelectorFechaState();
}

class _SelectorFechaState extends State<_SelectorFecha> {
  static const _letras = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  late final DateTime _hoy = _soloDia(DateTime.now());
  late final DateTime? _elegida = widget.valor == null ? null : DateTime.parse(widget.valor!);
  late final DateTime? _desde = widget.desde == null ? null : DateTime.parse(widget.desde!);
  late DateTime _mes = () {
    final desde = _desde;
    final base = _elegida ?? (desde != null && desde.isAfter(_hoy) ? desde : _hoy);
    return DateTime(base.year, base.month);
  }();

  static DateTime _soloDia(DateTime fecha) => DateTime(fecha.year, fecha.month, fecha.day);

  bool get _puedeAtras {
    final desde = _desde;
    if (desde == null) return _mes.year > 2000;
    return _mes.isAfter(DateTime(desde.year, desde.month));
  }

  bool get _puedeAdelante => _mes.year < 2100;

  void _moverMes(int meses) => setState(() => _mes = DateTime(_mes.year, _mes.month + meses));

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final textos = Theme.of(context).textTheme;
    final elegida = _elegida;
    final subtitulo =
        elegida == null ? 'Toca un día' : DateFormat("EEEE d 'de' MMMM 'de' y", 'es').format(elegida);

    // Celdas del mes: huecos al inicio para que el día 1 caiga en su columna (lunes = 1).
    final huecos = _mes.weekday - 1;
    final diasDelMes = DateTime(_mes.year, _mes.month + 1, 0).day;
    final celdas = <DateTime?>[
      for (var i = 0; i < huecos; i++) null,
      for (var d = 1; d <= diasDelMes; d++) DateTime(_mes.year, _mes.month, d),
    ];
    while (celdas.length % 7 != 0) {
      celdas.add(null);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EncabezadoHoja(titulo: widget.titulo, subtitulo: subtitulo),
        const SizedBox(height: Medidas.espacio4),
        Row(
          children: [
            BotonCircular(
              icono: Icons.chevron_left_rounded,
              descripcion: 'Mes anterior',
              alPresionar: _puedeAtras ? () => _moverMes(-1) : null,
            ),
            Expanded(
              child: Text(
                DateFormat('MMMM y', 'es').format(_mes).toUpperCase(),
                textAlign: TextAlign.center,
                style: textos.titleLarge,
              ),
            ),
            BotonCircular(
              icono: Icons.chevron_right_rounded,
              descripcion: 'Mes siguiente',
              alPresionar: _puedeAdelante ? () => _moverMes(1) : null,
            ),
          ],
        ),
        const SizedBox(height: Medidas.espacio3),
        Row(
          children: [
            for (final letra in _letras)
              Expanded(child: Text(letra, textAlign: TextAlign.center, style: textos.labelMedium)),
          ],
        ),
        const SizedBox(height: Medidas.espacio2),
        for (var fila = 0; fila < celdas.length; fila += 7)
          Row(
            children: [
              for (final dia in celdas.sublist(fila, fila + 7))
                Expanded(child: dia == null ? const SizedBox(height: Medidas.toqueMinimo) : _celda(dia, colores, textos)),
            ],
          ),
        if (widget.opcional) ...[
          const SizedBox(height: Medidas.espacio3),
          BotonTexto(
            texto: 'Dejar sin fecha',
            anchoCompleto: true,
            alPresionar: () => Navigator.pop(context, const _Eleccion(null)),
          ),
        ],
      ],
    );
  }

  Widget _celda(DateTime dia, ColoresEntrenAndo colores, TextTheme textos) {
    final desde = _desde;
    final permitido = desde == null || !dia.isBefore(desde);
    final esElegido = _elegida != null && DateUtils.isSameDay(dia, _elegida);
    final esHoy = DateUtils.isSameDay(dia, _hoy);
    final fondo = esElegido ? colores.tinta : (esHoy ? colores.sup2 : Colors.transparent);
    final letra = esElegido ? colores.fondo : (permitido ? colores.tinta : colores.medio);
    return Semantics(
      button: true,
      enabled: permitido,
      selected: esElegido,
      label: DateFormat("EEEE d 'de' MMMM", 'es').format(dia),
      excludeSemantics: true,
      child: InkResponse(
        radius: 22,
        onTap: permitido ? () => Navigator.pop(context, _Eleccion(CampoFecha.aIso(dia))) : null,
        child: SizedBox(
          height: Medidas.toqueMinimo,
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: fondo, shape: BoxShape.circle),
              child: Text(
                '${dia.day}',
                style: textos.titleMedium?.copyWith(color: letra, fontWeight: esElegido ? FontWeight.w600 : null),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
