import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/diseno.dart';
import 'perfil_repositorio.dart';

final _equipoProvider = FutureProvider.autoDispose<List<EquipoUsuario>>((ref) async {
  final repositorio = await ref.watch(perfilRepositorioProvider.future);
  return repositorio?.equipo() ?? const [];
});

/// Marcar el equipo que tiene el usuario; se guarda al tocar (ENT-18).
class PantallaEquipo extends ConsumerStatefulWidget {
  const PantallaEquipo({super.key});

  @override
  ConsumerState<PantallaEquipo> createState() => _PantallaEquipoState();
}

class _PantallaEquipoState extends ConsumerState<PantallaEquipo> {
  /// Cambios ya guardados que todavía no se vuelven a leer de la base.
  final Map<int, bool> _cambios = {};
  final Set<int> _guardando = {};
  String? _error;

  Future<void> _cambiar(EquipoUsuario equipo, bool loTiene) async {
    setState(() {
      _cambios[equipo.idEquipo] = loTiene;
      _guardando.add(equipo.idEquipo);
      _error = null;
    });
    try {
      final repositorio = await ref.read(perfilRepositorioProvider.future);
      await repositorio!.cambiarEquipo(equipo.idEquipo, loTiene: loTiene);
    } catch (_) {
      if (mounted) {
        setState(() {
          _cambios.remove(equipo.idEquipo);
          _error = 'No se pudo guardar "${equipo.nombre}". Intenta de nuevo.';
        });
      }
    } finally {
      if (mounted) setState(() => _guardando.remove(equipo.idEquipo));
    }
  }

  @override
  Widget build(BuildContext context) {
    final equipo = ref.watch(_equipoProvider);
    final error = _error;

    return Scaffold(
      body: ContenidoPantalla(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: BotonCircular(
              icono: Icons.arrow_back_rounded,
              descripcion: 'Volver',
              alPresionar: () => context.pop(),
            ),
          ),
          const SizedBox(height: Medidas.espacio4),
          const EncabezadoPantalla(
            etiqueta: 'Perfil',
            titulo: 'Tu equipo',
            subtitulo: 'Marca lo que tienes para entrenar',
          ),
          if (error != null) ...[
            const SizedBox(height: Medidas.espacio4),
            Aviso(error, icono: Icons.error_outline_rounded),
          ],
          const SizedBox(height: Medidas.espacio5),
          ...equipo.when(
            loading: () => const [Center(child: CircularProgressIndicator())],
            error: (error, _) => const [
              Aviso('No se pudo leer el equipo de la base local.', icono: Icons.error_outline_rounded),
            ],
            data: (lista) {
              final porCategoria = <String, List<EquipoUsuario>>{};
              for (final e in lista) {
                porCategoria.putIfAbsent(e.categoria ?? 'Otros', () => []).add(e);
              }
              return [
                for (final categoria in porCategoria.entries) ...[
                  EtiquetaSeccion(categoria.key),
                  const SizedBox(height: Medidas.espacio2),
                  Tarjeta(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Column(
                      children: [
                        for (final e in categoria.value)
                          Casilla(
                            valor: _cambios[e.idEquipo] ?? e.loTiene,
                            alCambiar: _guardando.contains(e.idEquipo) ? null : (v) => _cambiar(e, v),
                            etiqueta: Text(e.nombre),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Medidas.espacio5),
                ],
              ];
            },
          ),
        ],
      ),
    );
  }
}
