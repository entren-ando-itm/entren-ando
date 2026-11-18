import 'package:flutter/material.dart';

import '../../core/diseno.dart';
import 'rutinas_repositorio.dart';

/// Lo que elige el usuario cuando su plan ya no permite otro ciclo activo.
sealed class EleccionLimite {
  const EleccionLimite();
}

/// Archivar ese ciclo activo para hacerle lugar al nuevo.
class ArchivarCiclo extends EleccionLimite {
  const ArchivarCiclo(this.idCiclo);
  final String idCiclo;
}

/// Ver el plan Premium (ENT-52).
class VerPremium extends EleccionLimite {
  const VerPremium();
}

/// Hoja del límite RN-01: "Tu plan Gratuito permite 1 ciclo activo".
///
/// Ofrece archivar uno de los ciclos activos o ver Premium. Devuelve null si
/// el usuario la cierra.
Future<EleccionLimite?> mostrarHojaLimiteCiclos(
  BuildContext context, {
  required LimiteCiclos limite,
  required List<Ciclo> activos,
}) {
  final maximo = limite.maximo ?? 0;
  return mostrarHojaInferior<EleccionLimite>(
    context: context,
    constructor: (contexto) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EncabezadoHoja(
          titulo: 'Límite de tu plan',
          subtitulo: 'Tu plan ${limite.plan} permite $maximo ciclo${maximo == 1 ? '' : 's'} activo'
              '${maximo == 1 ? '' : 's'}. Archiva uno para activar otro: no se borra y lo puedes '
              'reactivar después.',
        ),
        const SizedBox(height: Medidas.espacio5),
        for (final ciclo in activos) ...[
          FilaOpcion(
            titulo: 'Archivar «${ciclo.nombre}»',
            descripcion: 'Deja de verse en Hoy',
            inicio: Icon(Icons.inventory_2_outlined, size: 22, color: contexto.colores.tinta),
            alTocar: () => Navigator.pop(contexto, ArchivarCiclo(ciclo.idCiclo)),
          ),
          const SizedBox(height: Medidas.espacio2),
        ],
        FilaOpcion(
          titulo: 'Ver Premium',
          descripcion: 'Ciclos activos sin límite',
          inicio: Icon(Icons.workspace_premium_outlined, size: 22, color: contexto.colores.tinta),
          alTocar: () => Navigator.pop(contexto, const VerPremium()),
        ),
      ],
    ),
  );
}

/// Mientras no exista la pantalla Premium (ENT-52), avisa que llega pronto.
Future<void> mostrarPremiumPronto(BuildContext context) {
  return mostrarHojaInferior<void>(
    context: context,
    constructor: (contexto) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EncabezadoHoja(titulo: 'Premium', subtitulo: 'Muy pronto podrás activar Premium desde aquí.'),
        const SizedBox(height: Medidas.espacio5),
        BotonSecundario(texto: 'Entendido', alPresionar: () => Navigator.pop(contexto)),
      ],
    ),
  );
}
