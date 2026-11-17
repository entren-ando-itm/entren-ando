import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/conectividad/boton_con_red.dart';
import '../../core/db/datos_prueba.dart';
import '../../core/diseno.dart';
import '../../core/sync/sincronizacion.dart';
import 'cliente_supabase.dart';

/// Solo modo de prueba (ENT-44): iniciar sesión en Supabase con el usuario
/// demo, ver el estado de la sincronización y subir a mano.
///
/// Perfil → Modo de prueba → "Nube y sincronización". El indicador para el
/// usuario final y su botón "Sincronizar ahora" los hace ENT-54.
class PantallaNubePrueba extends ConsumerStatefulWidget {
  const PantallaNubePrueba({super.key});

  @override
  ConsumerState<PantallaNubePrueba> createState() => _PantallaNubePruebaState();
}

class _PantallaNubePruebaState extends ConsumerState<PantallaNubePrueba> {
  bool _ocupado = false;
  String? _error;

  Future<void> _hacer(Future<void> Function() accion) async {
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await accion();
    } on AuthException catch (e) {
      _error = 'Supabase no dejó entrar: ${e.message}';
    } catch (e) {
      _error = 'No se pudo: $e';
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _entrarDemo() => _hacer(() async {
        await ClienteSupabase.cliente!.auth.signInWithPassword(
          email: DatosPrueba.correoDemo,
          password: ClienteSupabase.contrasenaDemo,
        );
      });

  Future<void> _salir() => _hacer(() => ClienteSupabase.cliente!.auth.signOut());

  Future<void> _sincronizar({bool todo = false}) =>
      _hacer(() => ref.read(sincronizacionProvider.notifier).sincronizar(todo: todo));

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(sincronizacionProvider);
    final textos = Theme.of(context).textTheme;
    final cliente = ClienteSupabase.cliente;
    final sesion = cliente?.auth.currentSession;

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
            etiqueta: 'Modo de prueba',
            titulo: 'Nube',
            subtitulo: 'Sincronización con Supabase (ENT-44)',
          ),
          const SizedBox(height: Medidas.espacio5),
          Tarjeta(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_titulo(estado.fase), style: textos.titleMedium),
                if (estado.mensaje != null) ...[
                  const SizedBox(height: Medidas.espacio1),
                  Text(estado.mensaje!, style: textos.bodyMedium),
                ],
                const SizedBox(height: Medidas.espacio2),
                Text(
                  [
                    'Sesión: ${sesion?.user.email ?? 'ninguna'}',
                    if (estado.ultimaVez != null)
                      'Última vez: ${DateFormat('HH:mm:ss').format(estado.ultimaVez!)}'
                          ' · ${estado.subidas} subidas'
                          '${estado.rechazadas > 0 ? ' · ${estado.rechazadas} rechazadas' : ''}',
                  ].join('\n'),
                  style: textos.bodySmall,
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: Medidas.espacio3),
            Aviso(_error!, icono: Icons.error_outline_rounded),
          ],
          const SizedBox(height: Medidas.espacio5),
          if (cliente == null)
            const Aviso(
              'Falta el archivo .env con SUPABASE_URL y SUPABASE_ANON_KEY. '
              'Corre la app con: flutter run --dart-define-from-file=.env',
            )
          else if (sesion == null)
            BotonConRed(
              alPresionar: _ocupado || ClienteSupabase.contrasenaDemo.isEmpty ? null : _entrarDemo,
              boton: (alPresionar) => BotonPrincipal(
                texto: 'Iniciar sesión como demo',
                icono: Icons.login_rounded,
                alPresionar: alPresionar,
              ),
              avisoSinRed: 'Sin conexión. Iniciar sesión necesita internet.',
            )
          else ...[
            BotonConRed(
              alPresionar: _ocupado ? null : _sincronizar,
              boton: (alPresionar) => BotonPrincipal(
                texto: 'Sincronizar ahora',
                icono: Icons.cloud_upload_outlined,
                alPresionar: alPresionar,
              ),
              avisoSinRed: 'Sin conexión. Lo pendiente se sube solo al volver la red.',
            ),
            const SizedBox(height: Medidas.espacio2),
            BotonSecundario(
              texto: 'Subir también los datos de prueba',
              icono: Icons.cloud_sync_outlined,
              alPresionar: _ocupado ? null : () => _sincronizar(todo: true),
            ),
            const SizedBox(height: Medidas.espacio1),
            Text(
              'Los datos de prueba vienen marcados como ya sincronizados. Este botón los '
              'sube una vez para ver la nube con datos.',
              style: textos.bodySmall,
            ),
            const SizedBox(height: Medidas.espacio2),
            BotonTexto(
              texto: 'Cerrar sesión en la nube',
              anchoCompleto: true,
              alPresionar: _ocupado ? null : _salir,
            ),
          ],
          if (cliente != null && sesion == null && ClienteSupabase.contrasenaDemo.isEmpty) ...[
            const SizedBox(height: Medidas.espacio2),
            const Aviso('Falta DEMO_PASSWORD en el archivo .env.'),
          ],
        ],
      ),
    );
  }

  static String _titulo(FaseSync fase) => switch (fase) {
        FaseSync.apagada => 'Nube apagada',
        FaseSync.sinSesion => 'Sin sesión',
        FaseSync.sinRed => 'Esperando internet',
        FaseSync.subiendo => 'Subiendo…',
        FaseSync.lista => 'Todo respaldado',
        FaseSync.error => 'Hubo un problema',
      };
}
