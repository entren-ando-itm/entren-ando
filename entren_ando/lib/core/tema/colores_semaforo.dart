import 'package:flutter/material.dart';

import 'colores.dart';

/// Colores del calendario semáforo (RF-08). Son los mismos en modo claro y
/// oscuro. Úsalos siempre desde aquí.
class ColoresSemaforo {
  ColoresSemaforo._();

  /// Verde: 100 % completado.
  static const Color completa = Color(0xFF2E7D32);

  /// Naranja: parcial.
  static const Color parcial = Color(0xFFEF6C00);

  /// Azul: descanso.
  static const Color descanso = Color(0xFF1565C0);

  /// Gris: sin actividad.
  static const Color sinActividad = Color(0xFF9E9E9E);

  /// Color de un valor de sesion_entrenamiento.estado (null = sin registro).
  static Color deEstado(String? estado) => switch (estado) {
        'completa' => completa,
        'parcial' => parcial,
        'descanso' => descanso,
        _ => sinActividad,
      };

  /// Texto para mostrar de un estado (null = sin registro).
  static String nombreDeEstado(String? estado) => EstadoDia.deSesion(estado).nombre;

  /// Color de un [EstadoDia]. Hoy y los días que vienen dependen del modo.
  static Color deEstadoDia(EstadoDia estado, ColoresEntrenAndo colores) => switch (estado) {
        EstadoDia.completo => completa,
        EstadoDia.parcial => parcial,
        EstadoDia.descanso => descanso,
        EstadoDia.sinActividad => sinActividad,
        EstadoDia.hoy => colores.tinta,
        EstadoDia.futuro => colores.tenue,
      };
}

/// Cómo se ve un día en el calendario.
enum EstadoDia {
  completo,
  parcial,
  descanso,
  sinActividad,

  /// Hoy, mientras no se termina la rutina.
  hoy,

  /// Un día que todavía no llega.
  futuro;

  /// Convierte sesion_entrenamiento.estado ('completa', 'parcial',
  /// 'descanso' o null) en un estado del calendario.
  static EstadoDia deSesion(String? estado) => switch (estado) {
        'completa' => EstadoDia.completo,
        'parcial' => EstadoDia.parcial,
        'descanso' => EstadoDia.descanso,
        _ => EstadoDia.sinActividad,
      };

  /// Nombre para mostrar ("Completo", "Sin actividad"...).
  String get nombre => switch (this) {
        EstadoDia.completo => 'Completo',
        EstadoDia.parcial => 'Parcial',
        EstadoDia.descanso => 'Descanso',
        EstadoDia.sinActividad => 'Sin actividad',
        EstadoDia.hoy => 'Hoy',
        EstadoDia.futuro => 'Por venir',
      };
}
