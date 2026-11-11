import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/db/base_datos.dart';
import '../../core/db/datos_prueba.dart';
import '../../core/diseno.dart';
import 'perfil_repositorio.dart';

/// Pestaña Perfil (módulo perfil).
///
/// Pantalla inicial del proyecto base: la cuenta, el perfil y la última
/// medición desde la base local, con el selector de tema claro/oscuro. La
/// edición la hace ENT-18 y el resto de los ajustes de la cuenta ENT-43.
class PantallaPerfil extends ConsumerWidget {
  const PantallaPerfil({super.key});

  static const Map<String, String> _objetivos = {
    'fuerza': 'Fuerza',
    'hipertrofia': 'Hipertrofia',
    'perdida_grasa': 'Pérdida de grasa',
    'resistencia': 'Resistencia',
    'salud': 'Salud',
  };

  static const Map<String, String> _niveles = {
    'principiante': 'Principiante',
    'intermedio': 'Intermedio',
    'avanzado': 'Avanzado',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumen = ref.watch(resumenPerfilProvider);
    final modo = ref.watch(modoTemaProvider);
    final oscuro = modo == ThemeMode.dark ||
        (modo == ThemeMode.system && Theme.of(context).brightness == Brightness.dark);

    return Scaffold(
      body: resumen.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => MensajeCentrado(
          'No se pudo leer la base local.\n$error',
          icono: Icons.error_outline_rounded,
        ),
        data: (perfil) {
          if (perfil == null) {
            return const MensajeCentrado('Inicia sesión para ver tu perfil.');
          }
          final colores = context.colores;
          final textos = Theme.of(context).textTheme;
          final diasPorSemana = perfil.diasPorSemana;
          final detalles = [
            _objetivos[perfil.objetivo],
            _niveles[perfil.nivel],
            if (diasPorSemana != null) '$diasPorSemana días por semana',
          ].whereType<String>().join(' · ');
          final fechaMedicion = DateTime.tryParse(perfil.fechaMedicion ?? '');

          return ContenidoPantalla(
            children: [
              Row(
                children: [
                  AvatarIniciales(perfil.nombre),
                  const SizedBox(width: Medidas.espacio4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(perfil.nombre, style: textos.headlineSmall),
                        const SizedBox(height: Medidas.espacio1),
                        Text(
                          perfil.correo,
                          style: textos.bodyMedium?.copyWith(fontSize: 14, color: colores.tinta2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Medidas.espacio4),
              Align(
                alignment: Alignment.centerLeft,
                child: Pastilla('Plan ${perfil.plan}', resaltada: true),
              ),
              if (detalles.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: Medidas.espacio2),
                  child: Text(detalles, style: textos.bodyMedium?.copyWith(color: colores.tinta2)),
                ),
              const SizedBox(height: Medidas.espacio4),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _dato(perfil.pesoKg, 'kg', 'Peso')),
                    const SizedBox(width: 10),
                    Expanded(child: _dato(perfil.estaturaCm, 'cm', 'Estatura')),
                    const SizedBox(width: 10),
                    Expanded(child: _dato(perfil.porcentajeGrasa, '%', 'Grasa')),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: Medidas.espacio2),
                child: Text(
                  fechaMedicion == null
                      ? 'Sin mediciones'
                      : 'Medido el ${DateFormat("d 'de' MMMM", 'es').format(fechaMedicion)}',
                  style: textos.bodySmall,
                ),
              ),
              const SizedBox(height: Medidas.espacio5),
              const EtiquetaSeccion('Entrenamiento'),
              const SizedBox(height: 10),
              GrupoFilas(
                filas: [
                  FilaAjuste(
                    titulo: 'Catálogo de ejercicios',
                    icono: Icons.menu_book_outlined,
                    alTocar: () => context.push('/perfil/catalogo'),
                  ),
                ],
              ),
              const SizedBox(height: Medidas.espacio5),
              const EtiquetaSeccion('Ajustes'),
              const SizedBox(height: 10),
              GrupoFilas(
                filas: [
                  FilaAjuste(
                    titulo: 'Tema',
                    fin: SelectorSegmentos<ThemeMode>(
                      opciones: const [
                        OpcionSegmento(valor: ThemeMode.light, texto: 'Claro'),
                        OpcionSegmento(valor: ThemeMode.dark, texto: 'Oscuro'),
                      ],
                      valor: oscuro ? ThemeMode.dark : ThemeMode.light,
                      alCambiar: (nuevo) => ref.read(modoTemaProvider.notifier).cambiar(nuevo),
                    ),
                  ),
                ],
              ),
              if (kDebugMode) ...[
                const SizedBox(height: Medidas.espacio5),
                const EtiquetaSeccion('Modo de prueba'),
                const SizedBox(height: 10),
                Tarjeta(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Estás usando el usuario demo (${DatosPrueba.correoDemo}). '
                        'Reiniciar borra la base del emulador y la crea de nuevo '
                        'con datos de prueba con fechas de hoy.',
                        style: textos.bodyMedium,
                      ),
                      const SizedBox(height: 14),
                      BotonSecundario(
                        texto: 'Reiniciar datos de prueba',
                        nivel: 2,
                        alPresionar: () async {
                          await BaseDatos.reiniciarDatosPrueba();
                          ref.invalidate(baseDatosProvider);
                        },
                      ),
                      const SizedBox(height: Medidas.espacio2),
                      BotonTexto(
                        texto: 'Ver componentes del diseño',
                        icono: Icons.palette_outlined,
                        anchoCompleto: true,
                        alPresionar: () => context.push('/perfil/componentes'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  static Widget _dato(double? valor, String unidad, String etiqueta) {
    if (valor == null) return TarjetaDato(valor: '—', etiqueta: etiqueta);
    final texto = valor % 1 == 0 ? valor.toStringAsFixed(0) : valor.toStringAsFixed(1);
    return TarjetaDato(valor: texto, unidad: unidad, etiqueta: etiqueta);
  }
}
