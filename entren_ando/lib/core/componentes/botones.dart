import 'package:flutter/material.dart';

import '../tema/colores.dart';
import '../tema/medidas.dart';
import '../tema/tipografia.dart';

/// Botón principal: solo uno por pantalla. Ocupa todo el ancho, así que va
/// dentro de una columna o lista (en una fila, envuélvelo en `Expanded`).
///
///   BotonPrincipal(
///     texto: 'Seguir entrenando',
///     icono: Icons.play_arrow_rounded,
///     alPresionar: () {...},
///   )
class BotonPrincipal extends StatelessWidget {
  const BotonPrincipal({
    super.key,
    required this.texto,
    required this.alPresionar,
    this.icono,
    this.grande = false,
  });

  /// Escríbelo normal; el botón lo pone en mayúsculas.
  final String texto;

  /// null = desactivado (por ejemplo, sin red).
  final VoidCallback? alPresionar;
  final IconData? icono;

  /// 60 de alto, para inicio de sesión y Premium.
  final bool grande;

  @override
  Widget build(BuildContext context) {
    final estilo = FilledButton.styleFrom(
      minimumSize: Size.fromHeight(grande ? Medidas.altoBotonGrande : Medidas.altoBoton),
      textStyle: grande ? TipografiaEntrenAndo.botonGrande : TipografiaEntrenAndo.boton,
    );
    return _botonLleno(estilo, texto, icono, alPresionar);
  }
}

/// Botón secundario: igual de grande que el principal, con fondo de
/// superficie ("Registrar a mano", "Terminar ejercicio").
class BotonSecundario extends StatelessWidget {
  const BotonSecundario({
    super.key,
    required this.texto,
    required this.alPresionar,
    this.icono,
    this.nivel = 1,
    this.grande = false,
  });

  final String texto;
  final VoidCallback? alPresionar;
  final IconData? icono;

  /// Superficie del fondo: 1 (sup1) o 2 (sup2, sobre una tarjeta).
  final int nivel;
  final bool grande;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final estilo = FilledButton.styleFrom(
      backgroundColor: colores.superficie(nivel),
      foregroundColor: colores.tinta,
      minimumSize: Size.fromHeight(grande ? Medidas.altoBotonGrande : Medidas.altoBoton),
      textStyle: grande ? TipografiaEntrenAndo.botonGrande : TipografiaEntrenAndo.boton,
    );
    return _botonLleno(estilo, texto, icono, alPresionar);
  }
}

Widget _botonLleno(ButtonStyle estilo, String texto, IconData? icono, VoidCallback? alPresionar) {
  final etiqueta = Text(texto.toUpperCase(), textAlign: TextAlign.center);
  if (icono == null) {
    return FilledButton(onPressed: alPresionar, style: estilo, child: etiqueta);
  }
  return FilledButton.icon(
    onPressed: alPresionar,
    style: estilo,
    icon: Icon(icono, size: 20),
    label: etiqueta,
  );
}

/// Acción de texto sin fondo: "Crear cuenta", "Cancelar", "Saltar".
class BotonTexto extends StatelessWidget {
  const BotonTexto({
    super.key,
    required this.texto,
    required this.alPresionar,
    this.icono,
    this.anchoCompleto = false,
  });

  final String texto;
  final VoidCallback? alPresionar;
  final IconData? icono;

  /// Ocupa todo el ancho (por ejemplo "Cancelar" al final de una hoja).
  final bool anchoCompleto;

  @override
  Widget build(BuildContext context) {
    final estilo = TextButton.styleFrom(
      minimumSize: anchoCompleto ? const Size.fromHeight(52) : const Size(48, 48),
    );
    final icono = this.icono;
    if (icono == null) {
      return TextButton(onPressed: alPresionar, style: estilo, child: Text(texto));
    }
    return TextButton.icon(
      onPressed: alPresionar,
      style: estilo,
      icon: Icon(icono, size: 20),
      label: Text(texto),
    );
  }
}

/// Botón chico en forma de píldora (44 de alto): "Cambiar solo hoy", "+15 s".
class BotonChico extends StatelessWidget {
  const BotonChico({
    super.key,
    required this.texto,
    required this.alPresionar,
    this.icono,
    this.nivel = 1,
  });

  final String texto;
  final VoidCallback? alPresionar;
  final IconData? icono;

  /// Superficie del fondo: 1 (sup1) o 2 (sup2, dentro de una tarjeta).
  final int nivel;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final estilo = FilledButton.styleFrom(
      backgroundColor: colores.superficie(nivel),
      foregroundColor: colores.tinta,
      minimumSize: const Size(Medidas.altoBotonChico, Medidas.altoBotonChico),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      textStyle: Theme.of(context).textTheme.titleSmall,
    );
    final icono = this.icono;
    if (icono == null) {
      return FilledButton(onPressed: alPresionar, style: estilo, child: Text(texto));
    }
    return FilledButton.icon(
      onPressed: alPresionar,
      style: estilo,
      icon: Icon(icono, size: 18),
      label: Text(texto),
    );
  }
}

/// Botón redondo con ícono (44 × 44), como Volver o Cerrar.
class BotonCircular extends StatelessWidget {
  const BotonCircular({
    super.key,
    required this.icono,
    required this.descripcion,
    required this.alPresionar,
    this.nivel = 1,
    this.tamano = Medidas.altoBotonChico,
  });

  final IconData icono;

  /// Lo que lee el lector de pantalla, por ejemplo "Volver a Hoy".
  final String descripcion;
  final VoidCallback? alPresionar;
  final int nivel;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    return IconButton(
      onPressed: alPresionar,
      tooltip: descripcion,
      icon: Icon(icono, size: 22),
      style: IconButton.styleFrom(
        backgroundColor: colores.superficie(nivel),
        foregroundColor: colores.tinta,
        fixedSize: Size.square(tamano),
        minimumSize: Size.square(tamano),
      ),
    );
  }
}
