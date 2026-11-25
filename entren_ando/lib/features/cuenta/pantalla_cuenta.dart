import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/conectividad/conectividad.dart';
import '../../core/db/base_datos.dart';
import '../../core/db/usuario_actual.dart';
import '../../core/diseno.dart';
import '../../core/sync/motor_sync.dart';
import '../../core/sync/sincronizacion.dart';
import '../nube/cliente_supabase.dart';
import 'sesion_cuenta.dart';

/// Nombre del plan del usuario ("Gratuito" o "Premium").
final planUsuarioProvider = FutureProvider<String?>((ref) async {
  final idUsuario = ref.watch(usuarioActualIdProvider);
  if (idUsuario == null) return null;
  final bd = await ref.watch(baseDatosProvider.future);
  final filas = await bd.rawQuery(
    'SELECT p.nombre FROM usuario u JOIN plan p ON p.id_plan = u.id_plan '
    'WHERE u.id_usuario = ? AND u.eliminado = 0',
    [idUsuario],
  );
  return filas.isEmpty ? null : filas.first['nombre'] as String?;
});

/// Cuenta y privacidad (ENT-43): correo, plan, aviso de privacidad, Premium,
/// eliminar cuenta y cerrar sesión. Se abre desde Perfil → Ajustes.
class PantallaCuenta extends ConsumerStatefulWidget {
  const PantallaCuenta({super.key});

  @override
  ConsumerState<PantallaCuenta> createState() => _PantallaCuentaState();
}

class _PantallaCuentaState extends ConsumerState<PantallaCuenta> {
  bool _saliendo = false;

  /// Cambios que aún no se suben a la nube (pendiente_sync = 1).
  Future<int> _pendientes(String idUsuario) async {
    final cliente = ClienteSupabase.cliente;
    if (cliente == null) return 0;
    final bd = await ref.read(baseDatosProvider.future);
    return MotorSync(bd, cliente).contarPendientes(idUsuario);
  }

  Future<void> _cerrarSesion() async {
    final idUsuario = ref.read(usuarioActualIdProvider);
    if (idUsuario == null || _saliendo) return;
    setState(() => _saliendo = true);
    final pendientes = await _pendientes(idUsuario);
    if (!mounted) return;
    final hayRed = ref.read(hayRedProvider);

    // Criterio 2: si hay cambios sin subir, avisa y deja sincronizar primero.
    final eleccion = await mostrarHojaInferior<String>(
      context: context,
      constructor: (contexto) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EncabezadoHoja(
            titulo: 'Cerrar sesión',
            subtitulo: pendientes == 0
                ? 'Tus datos se quedan guardados en este celular.'
                : pendientes == 1
                    ? 'Tienes 1 cambio que todavía no se sube a la nube.'
                    : 'Tienes $pendientes cambios que todavía no se suben a la nube.',
          ),
          const SizedBox(height: Medidas.espacio5),
          if (pendientes > 0) ...[
            FilaOpcion(
              titulo: 'Subir y cerrar sesión',
              descripcion: hayRed ? 'Recomendado' : 'Necesitas internet',
              inicio: const Icon(Icons.cloud_upload_outlined, size: 22),
              alTocar: hayRed ? () => Navigator.pop(contexto, 'subir') : null,
            ),
            const SizedBox(height: Medidas.espacio2),
          ],
          FilaOpcion(
            titulo: pendientes > 0 ? 'Cerrar sin subir' : 'Cerrar sesión',
            descripcion: pendientes > 0 ? 'Se quedan guardados en este celular' : null,
            inicio: const Icon(Icons.logout_rounded, size: 22),
            alTocar: () => Navigator.pop(contexto, 'salir'),
          ),
          const SizedBox(height: Medidas.espacio2),
          BotonTexto(
            texto: 'Cancelar',
            anchoCompleto: true,
            alPresionar: () => Navigator.pop(contexto),
          ),
        ],
      ),
    );

    if (eleccion == 'subir') {
      await ref.read(sincronizacionProvider.notifier).sincronizar();
    }
    if (eleccion == 'subir' || eleccion == 'salir') {
      // go_router manda solo al inicio de sesión al quedar sin sesión.
      await Cuenta.cerrarSesion();
      return;
    }
    if (mounted) setState(() => _saliendo = false);
  }

  /// Premium (ENT-52) y Eliminar cuenta (ENT-51) llegan en el Sprint 3.
  Future<void> _muyPronto(String titulo, String detalle) {
    return mostrarHojaInferior<void>(
      context: context,
      constructor: (contexto) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EncabezadoHoja(titulo: titulo, subtitulo: detalle),
          const SizedBox(height: Medidas.espacio5),
          BotonSecundario(texto: 'Entendido', alPresionar: () => Navigator.pop(contexto)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sesion = ref.watch(sesionActualProvider);
    final plan = ref.watch(planUsuarioProvider).value;

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
          EncabezadoPantalla(
            etiqueta: 'Perfil',
            titulo: 'Cuenta',
            subtitulo: sesion?.esDemo ?? false ? 'Usuario demo (modo de prueba)' : null,
          ),
          const SizedBox(height: Medidas.espacio5),
          const EtiquetaSeccion('Tu cuenta'),
          const SizedBox(height: 10),
          GrupoFilas(
            filas: [
              FilaAjuste(titulo: sesion?.correo ?? '', icono: Icons.mail_outline_rounded),
              FilaAjuste(
                titulo: 'Plan',
                icono: Icons.workspace_premium_outlined,
                fin: plan == null ? null : Pastilla('Plan $plan', chica: true),
              ),
            ],
          ),
          const SizedBox(height: Medidas.espacio5),
          const EtiquetaSeccion('Privacidad y plan'),
          const SizedBox(height: 10),
          GrupoFilas(
            filas: [
              FilaAjuste(
                titulo: 'Aviso de privacidad',
                icono: Icons.description_outlined,
                alTocar: () => context.push('/aviso'),
              ),
              FilaAjuste(
                titulo: 'Premium',
                icono: Icons.star_outline_rounded,
                alTocar: () => _muyPronto('Premium', 'La prueba de Premium llega en el Sprint 3 (ENT-52).'),
              ),
              FilaAjuste(
                titulo: 'Eliminar mi cuenta y mis datos',
                icono: Icons.delete_outline_rounded,
                alTocar: () => _muyPronto(
                  'Eliminar cuenta',
                  'Borrar tu cuenta y todos tus datos llega en el Sprint 3 (ENT-51).',
                ),
              ),
            ],
          ),
          const SizedBox(height: Medidas.espacio6),
          BotonSecundario(
            texto: _saliendo ? 'Cerrando sesión…' : 'Cerrar sesión',
            icono: Icons.logout_rounded,
            alPresionar: _saliendo ? null : _cerrarSesion,
          ),
        ],
      ),
    );
  }
}
