import 'package:flutter/material.dart';

import '../tema/colores.dart';
import '../tema/medidas.dart';
import '../tema/tipografia.dart';
import 'textos.dart';

/// Superficie sólida, sin borde ni sombra. Úsala para agrupar contenido.
///
///   Tarjeta(child: Text('Avena con plátano'))
///   Tarjeta(nivel: 2, alTocar: () {...}, child: ...)
class Tarjeta extends StatelessWidget {
  const Tarjeta({
    super.key,
    this.nivel = 1,
    this.padding = const EdgeInsets.all(Medidas.espacio4),
    this.radio = Medidas.radioTarjeta,
    this.alTocar,
    this.color,
    required this.child,
  });

  /// 1 a 4: de sup1 (lo normal) a sup4 (lo más marcado).
  final int nivel;
  final EdgeInsetsGeometry padding;
  final double radio;

  /// Si no es null, la tarjeta se puede tocar.
  final VoidCallback? alTocar;

  /// Solo para casos especiales, por ejemplo la serie actual (`colores.boton`).
  final Color? color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final contenido = Padding(padding: padding, child: child);
    final alTocar = this.alTocar;
    return Material(
      color: color ?? context.colores.superficie(nivel),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radio)),
      clipBehavior: Clip.antiAlias,
      child: alTocar == null ? contenido : InkWell(onTap: alTocar, child: contenido),
    );
  }
}

/// Pastilla con texto: equipo del usuario, plan, etiquetas.
///
///   Pastilla('Mancuernas')
///   Pastilla('Plan Gratuito', resaltada: true)
///   Pastilla('Sigue', resaltada: true, chica: true)
class Pastilla extends StatelessWidget {
  const Pastilla(
    this.texto, {
    super.key,
    this.resaltada = false,
    this.nivel = 1,
    this.chica = false,
    this.icono,
  });

  final String texto;

  /// Fondo de tinta con letra clara.
  final bool resaltada;

  /// Superficie si no está resaltada (1 a 4).
  final int nivel;

  /// Versión de 20 de alto para marcar algo dentro de una fila.
  final bool chica;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final textos = Theme.of(context).textTheme;
    final fondo = resaltada ? colores.tinta : colores.superficie(nivel);
    final letra = resaltada ? colores.fondo : colores.tinta;
    final estilo = (chica ? textos.labelSmall : textos.titleSmall)?.copyWith(
      color: letra,
      fontWeight: chica || resaltada ? FontWeight.w600 : FontWeight.w500,
    );
    final icono = this.icono;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: chica ? 8 : 14, vertical: chica ? 3 : 8),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(chica ? 10 : 17),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            if (icono != null)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: EdgeInsets.only(right: chica ? 4 : 6),
                  child: Icon(icono, size: chica ? 12 : 16, color: letra),
                ),
              ),
            TextSpan(text: texto),
          ],
        ),
        style: estilo,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Círculo con las iniciales del usuario ("UD").
class AvatarIniciales extends StatelessWidget {
  const AvatarIniciales(this.nombre, {super.key, this.tamano = 64});

  final String nombre;
  final double tamano;

  /// "Usuario Demo" → "UD"; "Paola" → "P".
  static String iniciales(String nombre) {
    final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return '?';
    final primera = partes.first.substring(0, 1);
    final segunda = partes.length > 1 ? partes[1].substring(0, 1) : '';
    return (primera + segunda).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    return Container(
      width: tamano,
      height: tamano,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: colores.sup2, shape: BoxShape.circle),
      child: Text(
        iniciales(nombre),
        style: TextStyle(
          fontFamily: TipografiaEntrenAndo.condensada,
          fontWeight: FontWeight.w700,
          fontSize: tamano * 0.375,
          height: 1,
          color: colores.tinta,
        ),
      ),
    );
  }
}

/// Dato con número grande y su nombre abajo, como en Perfil: "74.6 kg / Peso".
class TarjetaDato extends StatelessWidget {
  const TarjetaDato({super.key, required this.valor, required this.etiqueta, this.unidad});

  final String valor;
  final String? unidad;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    return Tarjeta(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NumeroConUnidad(numero: valor, unidad: unidad),
          const SizedBox(height: 6),
          Text(etiqueta, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
