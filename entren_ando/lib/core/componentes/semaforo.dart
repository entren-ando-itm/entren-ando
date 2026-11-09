import 'package:flutter/material.dart';

import '../tema/colores.dart';
import '../tema/colores_semaforo.dart';
import '../tema/tipografia.dart';

/// Círculo de un día del calendario semáforo (RF-08).
///
/// Completo, parcial y sin actividad son círculos llenos; descanso es un
/// punto azul más chico; hoy va en tinta con su número; los días que vienen,
/// en tenue. En el diseño solo hoy lleva número.
///
///   CirculoDia(
///     estado: EstadoDia.deSesion(sesion.estado),
///     descripcion: '3 de noviembre: sin actividad',
///     alTocar: () {...},
///   )
class CirculoDia extends StatelessWidget {
  const CirculoDia({
    super.key,
    required this.estado,
    this.numero,
    this.tamano = 42,
    this.alTocar,
    this.descripcion,
  });

  final EstadoDia estado;

  /// Número del día. Si es null no se dibuja.
  final int? numero;
  final double tamano;
  final VoidCallback? alTocar;

  /// Lo que lee el lector de pantalla, por ejemplo "3 de noviembre: sin actividad".
  final String? descripcion;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final esPunto = estado == EstadoDia.descanso;
    final fondo = ColoresSemaforo.deEstadoDia(estado, colores);
    final letra = switch (estado) {
      EstadoDia.hoy => colores.fondo,
      EstadoDia.futuro => colores.tinta2,
      EstadoDia.sinActividad => const Color(0xFF1A1A1A),
      _ => const Color(0xFFFFFFFF),
    };
    final lado = esPunto ? tamano * 0.43 : tamano;
    final numero = this.numero;
    final texto = numero == null || esPunto
        ? null
        : Center(
            child: Text(
              '$numero',
              style: TextStyle(
                fontFamily: TipografiaEntrenAndo.condensada,
                fontWeight: FontWeight.w700,
                fontSize: tamano * 0.4,
                height: 1,
                color: letra,
                fontFeatures: TipografiaEntrenAndo.numerosTabulares,
              ),
            ),
          );
    // Ink (y no Container) para que el efecto al tocar se vea encima del color.
    final celda = SizedBox(
      width: tamano,
      height: tamano,
      child: Center(
        child: Ink(
          width: lado,
          height: lado,
          decoration: BoxDecoration(color: fondo, shape: BoxShape.circle),
          child: texto,
        ),
      ),
    );
    final alTocar = this.alTocar;
    return Semantics(
      label: descripcion,
      button: alTocar != null,
      child: Material(
        type: MaterialType.transparency,
        child: alTocar == null
            ? celda
            : InkWell(customBorder: const CircleBorder(), onTap: alTocar, child: celda),
      ),
    );
  }
}

/// Punto de color de un estado, para leyendas y opciones:
///   ElementoLeyenda(marca: PuntoSemaforo(EstadoDia.completo), texto: 'Completo', valor: '2')
class PuntoSemaforo extends StatelessWidget {
  const PuntoSemaforo(this.estado, {super.key, this.tamano = 14});

  final EstadoDia estado;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final lado = estado == EstadoDia.descanso ? tamano * 0.57 : tamano;
    return SizedBox(
      width: tamano,
      height: tamano,
      child: Center(
        child: Container(
          width: lado,
          height: lado,
          decoration: BoxDecoration(
            color: ColoresSemaforo.deEstadoDia(estado, context.colores),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
