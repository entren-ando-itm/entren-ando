import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/conectividad/boton_con_red.dart';
import '../../core/diseno.dart';
import 'premium.dart';

class PantallaPremium extends ConsumerStatefulWidget {
  const PantallaPremium({super.key});

  @override
  ConsumerState<PantallaPremium> createState() => _PantallaPremiumState();
}

class _PantallaPremiumState extends ConsumerState<PantallaPremium> {
  bool _activando = false;
  String? _aviso;

  Future<void> _activar() async {
    if (_activando) return;
    setState(() {
      _activando = true;
      _aviso = null;
    });
    try {
      await ref.read(activarPremiumProvider)();
    } on ErrorPremium catch (e) {
      if (mounted) setState(() => _aviso = e.mensaje);
    } catch (_) {
      if (mounted) setState(() => _aviso = 'No se pudo confirmar el plan. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _activando = false);
    }
  }

  /// ENT-95: confirma y vuelve a Gratuito de inmediato.
  Future<void> _cancelar() async {
    if (_activando) return;
    final seguro = await mostrarHojaInferior<bool>(
      context: context,
      constructor: (contexto) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const EncabezadoHoja(
            titulo: 'Cancelar Premium',
            subtitulo: 'Vuelves al plan Gratuito ahora. Si tienes más ciclos activos de los que permite, '
                'se archivan y se queda activo el más reciente. Puedes volver a probar Premium cuando quieras.',
          ),
          const SizedBox(height: Medidas.espacio5),
          BotonSecundario(texto: 'Sí, cancelar', alPresionar: () => Navigator.pop(contexto, true)),
          const SizedBox(height: Medidas.espacio2),
          BotonTexto(texto: 'No, seguir con Premium', anchoCompleto: true, alPresionar: () => Navigator.pop(contexto)),
        ],
      ),
    );
    if (seguro != true || !mounted) return;
    setState(() {
      _activando = true;
      _aviso = null;
    });
    try {
      await ref.read(cancelarPremiumProvider)();
    } on ErrorPremium catch (e) {
      if (mounted) setState(() => _aviso = e.mensaje);
    } catch (_) {
      if (mounted) setState(() => _aviso = 'No se pudo cancelar Premium. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _activando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final planes = ref.watch(comparacionPlanesProvider);
    final textos = Theme.of(context).textTheme;
    final zona = MediaQuery.paddingOf(context);
    final alto = MediaQuery.sizeOf(context).height - zona.vertical - Medidas.espacio5 * 2;
    return Scaffold(
      body: ContenidoPantalla(
        arriba: Medidas.espacio5,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: alto.clamp(0.0, double.infinity).toDouble()),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: BotonCircular(
                        icono: Icons.close_rounded,
                        descripcion: 'Cerrar',
                        alPresionar: () => context.pop(),
                      ),
                    ),
                    const SizedBox(height: Medidas.espacio4),
                    EncabezadoPantalla(
                      etiqueta: 'Entren-Ando',
                      titulo: 'Premium',
                      estiloTitulo: textos.displaySmall,
                    ),
                    const SizedBox(height: Medidas.espacio3),
                    planes.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (_, _) => const Aviso('No se pudieron leer los planes en este celular.'),
                      data: (datos) => _comparacion(datos),
                    ),
                  ],
                ),
                if (planes.value case final datos?)
                  Padding(
                    padding: const EdgeInsets.only(top: Medidas.espacio6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (datos.activo) ...[
                          if (_aviso case final aviso?) ...[
                            Aviso(aviso),
                            const SizedBox(height: Medidas.espacio3),
                          ],
                          const Aviso('Tu plan Premium está activo.'),
                          const SizedBox(height: Medidas.espacio3),
                          BotonConRed(
                            alPresionar: _activando ? null : _cancelar,
                            avisoSinRed: 'Conéctate para cancelar Premium. Mientras tanto lo sigues usando.',
                            boton: (accion) => BotonSecundario(
                              texto: _activando ? 'Cancelando…' : 'Cancelar Premium',
                              alPresionar: accion,
                            ),
                          ),
                        ] else ...[
                          if (_aviso case final aviso?) ...[
                            Aviso(aviso),
                            const SizedBox(height: Medidas.espacio3),
                          ],
                          BotonConRed(
                            alPresionar: _activando ? null : _activar,
                            avisoSinRed:
                                'Conéctate para activar Premium. Mientras tanto puedes seguir entrenando.',
                            boton: (accion) => BotonPrincipal(
                              texto: _activando ? 'Activando…' : 'Probar Premium',
                              grande: true,
                              alPresionar: accion,
                            ),
                          ),
                          const SizedBox(height: Medidas.espacio2),
                          Text(
                            'Prueba de 30 días. Es una compra simulada y no se cobra nada.',
                            textAlign: TextAlign.center,
                            style: textos.bodySmall,
                          ),
                        ],
                        const SizedBox(height: Medidas.espacio2),
                        BotonTexto(
                          texto: datos.activo ? 'Volver' : 'Seguir con el plan Gratuito',
                          alPresionar: () => context.pop(),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _comparacion(ComparacionPlanes datos) {
    final textos = Theme.of(context).textTheme;
    final (g, p) = (datos.gratuito, datos.premium);
    String limite(int? n, [String sufijo = '']) => n == null ? 'Sin límite' : '$n$sufijo';
    String frecuencia(String valor) => valor == 'mensual' ? 'Mensual' : 'Semanal';
    Widget columnas(Widget nombre, Widget gratuito, Widget premium) => Row(
      children: [
        Expanded(flex: 14, child: nombre),
        Expanded(flex: 10, child: gratuito),
        Expanded(flex: 7, child: premium),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NumeroConUnidad(
          numero: '\$${p.precio.toStringAsFixed(p.precio % 1 == 0 ? 0 : 2)}',
          unidad: 'MXN al mes',
          tamano: textos.headlineMedium!.fontSize!,
        ),
        const SizedBox(height: Medidas.espacio5),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Medidas.espacio4),
          child: columnas(
            const SizedBox.shrink(),
            const EtiquetaSeccion('Gratuito'),
            const EtiquetaSeccion('Premium'),
          ),
        ),
        const SizedBox(height: Medidas.espacio4),
        for (final (nombre, gratis, premium) in [
          ('Ciclos de rutina activos', limite(g.ciclos), limite(p.ciclos)),
          ('Escaneos de comida con IA', limite(g.escaneos, ' al día'), limite(p.escaneos, ' al día')),
          ('Feedback de la IA', frecuencia(g.frecuencia), frecuencia(p.frecuencia)),
        ]) ...[
          Tarjeta(
            radio: Medidas.radioCampo,
            child: columnas(
              Padding(
                padding: const EdgeInsets.only(right: Medidas.espacio2),
                child: Text(nombre, style: textos.bodyMedium),
              ),
              Text(gratis, style: textos.bodyMedium?.copyWith(color: context.colores.tinta2)),
              Text(premium, style: textos.titleSmall),
            ),
          ),
          const SizedBox(height: Medidas.espacio2),
        ],
      ],
    );
  }
}
