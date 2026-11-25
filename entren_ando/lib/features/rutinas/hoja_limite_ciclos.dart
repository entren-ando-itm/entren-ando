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
/// En Gratuito solo ofrece ver Premium (RN-01 precisada: 1 ciclo en total).
/// Devuelve null si el usuario la cierra. [activos] se conserva por compatibilidad.
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
          subtitulo: 'Tu plan ${limite.plan} incluye $maximo ciclo${maximo == 1 ? '' : 's'}. '
              'Edita el que ya tienes o activa Premium para guardar un ciclo por semestre y '
              'reactivar los archivados. Tu historial de entrenamientos no se pierde.',
        ),
        const SizedBox(height: Medidas.espacio5),
        FilaOpcion(
          titulo: 'Ver Premium',
          descripcion: 'Ciclos sin límite',
          inicio: Icon(Icons.workspace_premium_outlined, size: 22, color: contexto.colores.tinta),
          alTocar: () => Navigator.pop(contexto, const VerPremium()),
        ),
      ],
    ),
  );
}
