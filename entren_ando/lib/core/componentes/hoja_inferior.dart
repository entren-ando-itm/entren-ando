import 'package:flutter/material.dart';

import '../tema/colores.dart';
import '../tema/medidas.dart';

/// Abre una hoja desde abajo con el estilo de Entren-Ando: fondo de la app,
/// esquinas de 32, agarradera y velo detrás. Devuelve lo que pases a
/// `Navigator.pop(context, valor)` (o null si se cierra sin elegir).
///
///   final elegido = await mostrarHojaInferior(
///     context: context,
///     constructor: (context) => Column(
///       mainAxisSize: MainAxisSize.min,
///       crossAxisAlignment: CrossAxisAlignment.stretch,
///       children: [
///         const EncabezadoHoja(titulo: 'Martes 3', subtitulo: 'Tocaba Empuje · sin registro'),
///         const SizedBox(height: 20),
///         FilaOpcion(
///           titulo: 'Completo',
///           inicio: const PuntoSemaforo(EstadoDia.completo, tamano: 22),
///           alTocar: () => Navigator.pop(context, EstadoDia.completo),
///         ),
///       ],
///     ),
///   );
Future<T?> mostrarHojaInferior<T>({
  required BuildContext context,
  required WidgetBuilder constructor,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (contexto) {
      final abajo = MediaQuery.paddingOf(contexto).bottom + Medidas.espacio5;
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(contexto).bottom),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(Medidas.espacio5, 0, Medidas.espacio5, abajo),
          child: constructor(contexto),
        ),
      );
    },
  );
}

/// Encabezado de una hoja inferior: título en mayúsculas y subtítulo, con algo
/// opcional a la izquierda (por ejemplo un `CirculoDia`).
class EncabezadoHoja extends StatelessWidget {
  const EncabezadoHoja({super.key, required this.titulo, this.subtitulo, this.inicio});

  final String titulo;
  final String? subtitulo;
  final Widget? inicio;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final inicio = this.inicio;
    final subtitulo = this.subtitulo;
    return Row(
      children: [
        if (inicio != null) ...[inicio, const SizedBox(width: 14)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  titulo.toUpperCase(),
                  style: textos.headlineSmall?.copyWith(fontWeight: FontWeight.w800, fontSize: 28),
                ),
              ),
              if (subtitulo != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    subtitulo,
                    style: textos.bodyMedium?.copyWith(fontSize: 14, color: context.colores.tinta2),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Opción grande para elegir dentro de una hoja (66 de alto, fondo sup1).
class FilaOpcion extends StatelessWidget {
  const FilaOpcion({
    super.key,
    required this.titulo,
    this.descripcion,
    this.inicio,
    this.alTocar,
    this.seleccionada = false,
  });

  final String titulo;
  final String? descripcion;

  /// Algo chico a la izquierda, por ejemplo `PuntoSemaforo(..., tamano: 22)`.
  final Widget? inicio;
  final VoidCallback? alTocar;

  /// Marca la opción actual (fondo sup2 y palomita).
  final bool seleccionada;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final textos = Theme.of(context).textTheme;
    final inicio = this.inicio;
    final descripcion = this.descripcion;
    return Semantics(
      button: true,
      selected: seleccionada,
      child: Material(
        color: seleccionada ? colores.sup2 : colores.sup1,
        borderRadius: BorderRadius.circular(Medidas.radioTarjeta),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: alTocar,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 66),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                children: [
                  if (inicio != null) ...[
                    SizedBox(width: 22, child: Center(child: inicio)),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: textos.titleMedium?.copyWith(fontSize: 17, fontWeight: FontWeight.w600),
                        ),
                        if (descripcion != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(descripcion, style: textos.bodySmall),
                          ),
                      ],
                    ),
                  ),
                  if (seleccionada) Icon(Icons.check_rounded, color: colores.tinta),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
