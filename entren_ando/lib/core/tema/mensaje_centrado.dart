import 'package:flutter/material.dart';

import 'colores.dart';
import 'medidas.dart';

/// Mensaje centrado para pantallas vacías o con error.
class MensajeCentrado extends StatelessWidget {
  const MensajeCentrado(this.texto, {super.key, this.icono = Icons.info_outline_rounded});

  final String texto;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Medidas.margen),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 40, color: colores.tinta2),
            const SizedBox(height: Medidas.espacio3),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: colores.tinta2),
            ),
          ],
        ),
      ),
    );
  }
}
