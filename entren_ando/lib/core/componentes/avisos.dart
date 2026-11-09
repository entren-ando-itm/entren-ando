import 'package:flutter/material.dart';

import '../tema/colores.dart';
import '../tema/medidas.dart';

/// Aviso en una caja sólida (sup1) con ícono.
///
/// Sin red (RNF-02) usa `Aviso.sinRed` junto al botón desactivado y di cuál
/// es el otro camino:
///   Aviso.sinRed('Sin conexión. El escaneo con IA vuelve cuando tengas red; '
///       'mientras, regístralo a mano.')
class Aviso extends StatelessWidget {
  const Aviso(this.texto, {super.key, this.icono = Icons.info_outline_rounded});

  const Aviso.sinRed(this.texto, {super.key}) : icono = Icons.wifi_off_rounded;

  final String texto;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final estilo = Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.4);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colores.sup1,
          borderRadius: BorderRadius.circular(Medidas.radioCampo),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, size: 20, color: colores.tinta),
            const SizedBox(width: Medidas.espacio3),
            Expanded(child: Text(texto, style: estilo)),
          ],
        ),
      ),
    );
  }
}

/// Pastilla chica "Sin conexión" para poner a la derecha del encabezado:
///   EncabezadoPantalla(etiqueta: 'Hoy', titulo: 'Comidas', accion: const InsigniaSinRed())
class InsigniaSinRed extends StatelessWidget {
  const InsigniaSinRed({super.key});

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: colores.sup1, borderRadius: BorderRadius.circular(14)),
      child: Text.rich(
        TextSpan(
          children: [
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(Icons.wifi_off_rounded, size: 14, color: colores.tinta),
              ),
            ),
            const TextSpan(text: 'Sin conexión'),
          ],
        ),
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}
