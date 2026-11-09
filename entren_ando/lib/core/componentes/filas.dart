import 'package:flutter/material.dart';

import '../tema/colores.dart';
import '../tema/medidas.dart';

/// Grupo de filas pegadas, como "Ajustes" en Perfil: esquinas de 18 arriba y
/// abajo, de 6 entre filas, y 3 de separación.
///
///   GrupoFilas(filas: [
///     FilaAjuste(titulo: 'Tema', fin: SelectorSegmentos(...)),
///     FilaAjuste(titulo: 'Aviso de privacidad', alTocar: () {...}),
///     FilaAjuste(titulo: 'Cerrar sesión', alTocar: () {...}),
///   ])
class GrupoFilas extends StatelessWidget {
  const GrupoFilas({super.key, required this.filas});

  final List<Widget> filas;

  @override
  Widget build(BuildContext context) {
    const grande = Radius.circular(Medidas.radioCampo);
    const chico = Radius.circular(Medidas.radioInterno);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < filas.length; i++) ...[
          if (i > 0) const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.vertical(
              top: i == 0 ? grande : chico,
              bottom: i == filas.length - 1 ? grande : chico,
            ),
            child: filas[i],
          ),
        ],
      ],
    );
  }
}

/// Fila de ajustes (52 de alto, fondo sup1). Va dentro de [GrupoFilas].
///
/// Si se puede tocar y no tiene nada al final, muestra una flecha.
class FilaAjuste extends StatelessWidget {
  const FilaAjuste({
    super.key,
    required this.titulo,
    this.icono,
    this.fin,
    this.alTocar,
    this.mostrarFlecha,
  });

  final String titulo;
  final IconData? icono;

  /// Algo a la derecha, como un [SelectorSegmentos] o un `Switch`.
  final Widget? fin;
  final VoidCallback? alTocar;

  /// Por defecto, flecha solo si la fila se toca y no tiene [fin].
  final bool? mostrarFlecha;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final icono = this.icono;
    final fin = this.fin;
    final flecha = mostrarFlecha ?? (alTocar != null && fin == null);
    return Material(
      color: colores.sup1,
      child: InkWell(
        onTap: alTocar,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Medidas.altoFila),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 6, fin == null ? 16 : 8, 6),
            child: Row(
              children: [
                if (icono != null) ...[
                  Icon(icono, size: 20, color: colores.tinta),
                  const SizedBox(width: 10),
                ],
                Expanded(child: Text(titulo, style: Theme.of(context).textTheme.titleMedium)),
                ?fin,
                if (flecha) Icon(Icons.chevron_right_rounded, color: colores.tinta2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Una opción de [SelectorSegmentos].
class OpcionSegmento<T> {
  const OpcionSegmento({required this.valor, required this.texto});

  final T valor;
  final String texto;
}

/// Selector en forma de píldora, como Tema: Claro | Oscuro.
///
///   SelectorSegmentos(
///     opciones: const [
///       OpcionSegmento(valor: ThemeMode.light, texto: 'Claro'),
///       OpcionSegmento(valor: ThemeMode.dark, texto: 'Oscuro'),
///     ],
///     valor: modo,
///     alCambiar: (nuevo) => ...,
///   )
class SelectorSegmentos<T> extends StatelessWidget {
  const SelectorSegmentos({
    super.key,
    required this.opciones,
    required this.valor,
    required this.alCambiar,
  });

  final List<OpcionSegmento<T>> opciones;
  final T valor;
  final ValueChanged<T> alCambiar;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final estilo = Theme.of(context).textTheme.titleSmall ?? const TextStyle();
    const duracion = Duration(milliseconds: 180);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: colores.sup2, borderRadius: BorderRadius.circular(19)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < opciones.length; i++)
            Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 2),
              child: Semantics(
                button: true,
                selected: opciones[i].valor == valor,
                child: AnimatedContainer(
                  duration: duracion,
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    color: opciones[i].valor == valor ? colores.tinta : colores.sup2,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(15),
                      onTap: opciones[i].valor == valor ? null : () => alCambiar(opciones[i].valor),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        child: AnimatedDefaultTextStyle(
                          duration: duracion,
                          style: estilo.copyWith(
                            color: opciones[i].valor == valor ? colores.fondo : colores.tinta,
                          ),
                          child: Text(opciones[i].texto),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
