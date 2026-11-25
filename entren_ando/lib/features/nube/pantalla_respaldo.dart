import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/conectividad/boton_con_red.dart';
import '../../core/diseno.dart';
import '../../core/sync/sincronizacion.dart';
import 'indicador_sync.dart';

/// Perfil → Ajustes → Respaldo en la nube (ENT-54).
///
/// Estado del respaldo, fecha y hora de la última sincronización y el botón
/// "Sincronizar ahora", que sube lo pendiente y baja lo nuevo de la nube.
/// Pantalla nueva (no está en docs/pantallas): armada con los componentes de
/// Ajustes (`07_perfil.png`).
class PantallaRespaldo extends ConsumerWidget {
  const PantallaRespaldo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(sincronizacionProvider);
    final pendientes = ref.watch(pendientesSyncProvider).value ?? 0;
    final estado = estadoRespaldo(sync.fase, pendientes);
    final textos = Theme.of(context).textTheme;
    final colores = context.colores;
    final sinConfigurar = sync.fase == FaseSync.apagada || sync.fase == FaseSync.sinSesion;

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
            etiqueta: 'Ajustes',
            titulo: 'Respaldo',
            subtitulo: 'Tus datos en la nube',
          ),
          const SizedBox(height: Medidas.espacio5),
          Tarjeta(
            child: Row(
              children: [
                Icon(
                  IconoSincronizacion.icono(estado),
                  size: 24,
                  color: estado == EstadoRespaldo.error ? colores.error : colores.tinta,
                ),
                const SizedBox(width: Medidas.espacio4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(textoRespaldo(estado, pendientes), style: textos.titleMedium),
                      const SizedBox(height: Medidas.espacio1),
                      Text(textoUltimaVez(sync.ultimaVez), style: textos.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (sync.mensaje != null && sync.fase != FaseSync.subiendo) ...[
            const SizedBox(height: Medidas.espacio3),
            Aviso(
              sync.mensaje!,
              icono: sync.fase == FaseSync.error ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            ),
          ],
          const SizedBox(height: Medidas.espacio5),
          if (sinConfigurar)
            const Aviso(
              'Inicia sesión para respaldar tus datos. Mientras, todo se guarda en tu celular.',
            )
          else
            BotonConRed(
              alPresionar: sync.fase == FaseSync.subiendo
                  ? null
                  : () => ref.read(sincronizacionProvider.notifier).sincronizar(),
              boton: (alPresionar) => BotonPrincipal(
                texto: sync.fase == FaseSync.subiendo ? 'Sincronizando…' : 'Sincronizar ahora',
                icono: Icons.sync_rounded,
                alPresionar: alPresionar,
              ),
              avisoSinRed: 'Sin conexión. Tus cambios están guardados en el celular y se suben '
                  'solos cuando vuelva la red.',
            ),
          const SizedBox(height: Medidas.espacio4),
          Text(
            'Se sincroniza solo al abrir la app, al volver la red y cada 15 minutos, aunque la app '
            'esté cerrada.',
            style: textos.bodySmall,
          ),
        ],
      ),
    );
  }
}
