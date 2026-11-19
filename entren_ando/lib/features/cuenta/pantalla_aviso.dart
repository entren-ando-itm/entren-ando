import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/diseno.dart';

/// Copia de docs/aviso_privacidad.md dentro de la app, para leerlo sin
/// internet (ENT-42 criterio 2). Si cambia el aviso, copia el archivo de nuevo
/// y sube `Cuenta.versionAviso`.
const String rutaAviso = 'assets/legal/aviso_privacidad.md';

final textoAvisoProvider = FutureProvider<String>((ref) => rootBundle.loadString(rutaAviso));

/// Un bloque del aviso ya leído del Markdown.
class BloqueAviso {
  const BloqueAviso(this.tipo, this.texto);

  final TipoBloque tipo;

  /// Sin marcas de Markdown (los ** ya se quitaron).
  final String texto;
}

enum TipoBloque { titulo, subtitulo, parrafo, vineta, numero }

/// Convierte el Markdown sencillo del aviso (títulos, párrafos y listas) en
/// bloques. No se usa un paquete de Markdown para no agregar dependencias.
List<BloqueAviso> leerAviso(String markdown) {
  final bloques = <BloqueAviso>[];
  final parrafo = StringBuffer();
  TipoBloque? tipoLista;
  final lista = StringBuffer();

  String limpiar(String texto) => texto
      .replaceAll('**', '')
      .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]+\)'), (m) => m.group(1)!)
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  void cerrar() {
    if (parrafo.isNotEmpty) {
      bloques.add(BloqueAviso(TipoBloque.parrafo, limpiar(parrafo.toString())));
      parrafo.clear();
    }
    if (tipoLista != null && lista.isNotEmpty) {
      bloques.add(BloqueAviso(tipoLista!, limpiar(lista.toString())));
      lista.clear();
    }
    tipoLista = null;
  }

  for (final linea in markdown.split('\n')) {
    final recortada = linea.trim();
    final vineta = RegExp(r'^[-*] (.*)$').firstMatch(recortada);
    final numero = RegExp(r'^(\d+)\. (.*)$').firstMatch(recortada);
    if (recortada.isEmpty) {
      cerrar();
    } else if (recortada.startsWith('# ')) {
      cerrar();
      bloques.add(BloqueAviso(TipoBloque.titulo, limpiar(recortada.substring(2))));
    } else if (recortada.startsWith('#')) {
      cerrar();
      bloques.add(BloqueAviso(TipoBloque.subtitulo, limpiar(recortada.replaceFirst(RegExp(r'^#+ '), ''))));
    } else if (vineta != null) {
      cerrar();
      tipoLista = TipoBloque.vineta;
      lista.write(vineta.group(1));
    } else if (numero != null) {
      cerrar();
      tipoLista = TipoBloque.numero;
      lista.write('${numero.group(1)}. ${numero.group(2)}');
    } else if (tipoLista != null && linea.startsWith(' ')) {
      // Continuación de la línea anterior de la lista.
      lista.write(' $recortada');
    } else {
      if (tipoLista != null) cerrar();
      parrafo.write(' $recortada');
    }
  }
  cerrar();
  return bloques;
}

/// El aviso de privacidad completo (ENT-42). Se abre desde el registro y
/// desde Perfil → Cuenta y privacidad.
class PantallaAviso extends ConsumerWidget {
  const PantallaAviso({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = Theme.of(context).textTheme;
    final colores = context.colores;
    final aviso = ref.watch(textoAvisoProvider);

    return Scaffold(
      body: aviso.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => const MensajeCentrado(
          'No se pudo abrir el aviso. Vuelve a intentarlo.',
          icono: Icons.error_outline_rounded,
        ),
        data: (markdown) {
          final bloques = leerAviso(markdown);
          return ContenidoPantalla(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: BotonCircular(
                  icono: Icons.arrow_back_rounded,
                  descripcion: 'Volver',
                  alPresionar: () => context.canPop() ? context.pop() : context.go('/entrar'),
                ),
              ),
              const SizedBox(height: Medidas.espacio4),
              EncabezadoPantalla(
                etiqueta: 'Entren-Ando',
                titulo: 'Aviso de privacidad',
                estiloTitulo: textos.headlineMedium,
              ),
              const SizedBox(height: Medidas.espacio5),
              for (final bloque in bloques)
                if (bloque.tipo != TipoBloque.titulo)
                  Padding(
                    padding: EdgeInsets.only(
                      top: bloque.tipo == TipoBloque.subtitulo ? Medidas.espacio5 : 0,
                      bottom: Medidas.espacio3,
                    ),
                    child: switch (bloque.tipo) {
                      TipoBloque.subtitulo => Text(bloque.texto, style: textos.titleLarge),
                      TipoBloque.vineta => Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('•  ', style: textos.bodyMedium?.copyWith(color: colores.tinta2)),
                            Expanded(child: Text(bloque.texto, style: textos.bodyMedium)),
                          ],
                        ),
                      _ => Text(bloque.texto, style: textos.bodyMedium),
                    },
                  ),
            ],
          );
        },
      ),
    );
  }
}
