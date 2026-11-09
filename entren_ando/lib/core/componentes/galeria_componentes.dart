import 'package:flutter/material.dart';

import '../diseno.dart';

/// Galería de componentes (solo en modo de prueba): Perfil → "Ver componentes
/// del diseño". Muestra todas las piezas de lib/core/componentes con el tema
/// actual; cambia el tema en Perfil para verlas en claro y en oscuro.
class GaleriaComponentes extends StatefulWidget {
  const GaleriaComponentes({super.key});

  @override
  State<GaleriaComponentes> createState() => _GaleriaComponentesState();
}

class _GaleriaComponentesState extends State<GaleriaComponentes> {
  bool _acepto = true;
  bool _segundoSegmento = false;
  int _pestana = 0;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final textos = Theme.of(context).textTheme;

    final muestras = <(String, Color)>[
      ('fondo', colores.fondo),
      ('sup1', colores.sup1),
      ('sup2', colores.sup2),
      ('sup3', colores.sup3),
      ('sup4', colores.sup4),
      ('tenue', colores.tenue),
      ('medio', colores.medio),
      ('tinta2', colores.tinta2),
      ('tinta', colores.tinta),
    ];
    final estilos = <(String, TextStyle?, String)>[
      ('displayLarge', textos.displayLarge, '9'),
      ('displayMedium', textos.displayMedium, '1410'),
      ('displaySmall', textos.displaySmall, 'PREMIUM'),
      ('headlineLarge', textos.headlineLarge, 'LUNES'),
      ('headlineMedium', textos.headlineMedium, 'PRENSA'),
      ('headlineSmall', textos.headlineSmall, 'Usuario Demo'),
      ('titleLarge', textos.titleLarge, 'MARTES'),
      ('titleMedium', textos.titleMedium, 'Sentadilla con barra'),
      ('titleSmall', textos.titleSmall, 'Cambiar solo hoy'),
      ('bodyLarge', textos.bodyLarge, 'Tu entrenamiento, aunque no haya señal.'),
      ('bodyMedium', textos.bodyMedium, '4 × 8 · 60 kg'),
      ('bodySmall', textos.bodySmall, 'Medido el 25 de octubre'),
      ('labelLarge', textos.labelLarge, 'Crear cuenta'),
      ('labelMedium', textos.labelMedium, 'CORREO'),
      ('labelSmall', textos.labelSmall, 'Sigue'),
    ];

    return Scaffold(
      body: ContenidoPantalla(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: BotonCircular(
              icono: Icons.arrow_back_rounded,
              descripcion: 'Volver',
              alPresionar: () => Navigator.of(context).maybePop(),
            ),
          ),
          const SizedBox(height: Medidas.espacio4),
          const EncabezadoPantalla(
            etiqueta: 'Modo de prueba',
            titulo: 'Componentes',
            subtitulo: 'Todo lo que hay en lib/core/componentes, con el tema actual.',
          ),
          const _Seccion('Colores'),
          Wrap(
            spacing: Medidas.espacio2,
            runSpacing: Medidas.espacio2,
            children: [
              for (final (nombre, color) in muestras) _Muestra(nombre: nombre, color: color),
            ],
          ),
          const SizedBox(height: Medidas.espacio3),
          Wrap(
            spacing: 20,
            runSpacing: 10,
            children: [
              for (final estado in EstadoDia.values)
                ElementoLeyenda(marca: PuntoSemaforo(estado), texto: estado.nombre),
            ],
          ),
          const _Seccion('Tipografía'),
          for (final (nombre, estilo, ejemplo) in estilos) ...[
            Text(nombre, style: textos.bodySmall),
            Text(ejemplo, style: estilo),
            const SizedBox(height: Medidas.espacio3),
          ],
          const _Seccion('Botones'),
          BotonPrincipal(texto: 'Seguir entrenando', icono: Icons.play_arrow_rounded, alPresionar: () {}),
          const SizedBox(height: Medidas.espacio3),
          BotonSecundario(texto: 'Registrar a mano', icono: Icons.edit_outlined, alPresionar: () {}),
          const SizedBox(height: Medidas.espacio3),
          const BotonPrincipal(texto: 'Escanear con cámara', icono: Icons.photo_camera_outlined, alPresionar: null),
          const SizedBox(height: Medidas.espacio3),
          BotonPrincipal(texto: 'Entrar', grande: true, alPresionar: () {}),
          const SizedBox(height: Medidas.espacio3),
          Wrap(
            spacing: Medidas.espacio2,
            runSpacing: Medidas.espacio2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              BotonCircular(icono: Icons.close_rounded, descripcion: 'Cerrar', alPresionar: () {}),
              BotonChico(texto: 'Cambiar solo hoy', icono: Icons.swap_horiz_rounded, alPresionar: () {}),
              BotonChico(texto: '+15 s', nivel: 2, alPresionar: () {}),
              BotonTexto(texto: 'Saltar', alPresionar: () {}),
            ],
          ),
          const _Seccion('Superficies'),
          Tarjeta(
            alTocar: () {},
            child: Row(
              children: [
                Expanded(child: Text('Avena con plátano y leche', style: textos.titleMedium)),
                const NumeroConUnidad(numero: '420', unidad: 'kcal', tamano: 22),
              ],
            ),
          ),
          const SizedBox(height: Medidas.espacio3),
          const Wrap(
            spacing: Medidas.espacio2,
            runSpacing: Medidas.espacio2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Pastilla('Plan Gratuito', resaltada: true),
              Pastilla('Mancuernas'),
              Pastilla('Poleas'),
              Pastilla('+5', nivel: 2),
              Pastilla('Sigue', resaltada: true, chica: true),
            ],
          ),
          const SizedBox(height: Medidas.espacio3),
          const IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: TarjetaDato(valor: '74.6', unidad: 'kg', etiqueta: 'Peso')),
                SizedBox(width: 10),
                Expanded(child: TarjetaDato(valor: '175', unidad: 'cm', etiqueta: 'Estatura')),
                SizedBox(width: 10),
                Expanded(child: TarjetaDato(valor: '17.8', unidad: '%', etiqueta: 'Grasa')),
              ],
            ),
          ),
          const SizedBox(height: Medidas.espacio3),
          const Row(
            children: [
              AvatarIniciales('Usuario Demo'),
              SizedBox(width: Medidas.espacio4),
              NumeroConUnidad(numero: '1410', unidad: 'kcal', tamano: 64),
            ],
          ),
          const _Seccion('Campos'),
          const CampoTexto(etiqueta: 'Correo', pista: 'tu@correo.com', teclado: TextInputType.emailAddress),
          const SizedBox(height: Medidas.espacio3),
          const CampoTexto(etiqueta: 'Contraseña', esContrasena: true),
          const SizedBox(height: Medidas.espacio2),
          Casilla(
            valor: _acepto,
            alCambiar: (valor) => setState(() => _acepto = valor),
            etiqueta: const Text('Acepto el aviso de privacidad'),
          ),
          const _Seccion('Avisos'),
          const Aviso.sinRed('Sin conexión. El escaneo con IA vuelve cuando tengas red; mientras, regístralo a mano.'),
          const SizedBox(height: Medidas.espacio3),
          const Align(alignment: Alignment.centerLeft, child: InsigniaSinRed()),
          const _Seccion('Semáforo'),
          Wrap(
            spacing: 6,
            runSpacing: 10,
            children: [
              for (final estado in EstadoDia.values)
                CirculoDia(
                  estado: estado,
                  numero: estado == EstadoDia.hoy ? 9 : null,
                  descripcion: estado.nombre,
                  alTocar: () {},
                ),
            ],
          ),
          const _Seccion('Barras'),
          const BarraProgreso(valor: 0.2, descripcion: 'Descanso transcurrido'),
          const SizedBox(height: Medidas.espacio4),
          BarraSegmentos(
            descripcion: 'Proteína 81 gramos, carbohidratos 174 gramos, grasa 37 gramos',
            segmentos: [
              SegmentoBarra(valor: 81, color: colores.tinta),
              SegmentoBarra(valor: 174, color: colores.medio),
              SegmentoBarra(valor: 37, color: colores.sup4),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              ElementoLeyenda(marca: MarcaColor(colores.tinta), texto: 'Proteína 81 g'),
              ElementoLeyenda(marca: MarcaColor(colores.medio), texto: 'Carbohidratos 174 g'),
              ElementoLeyenda(marca: MarcaColor(colores.sup4), texto: 'Grasa 37 g'),
            ],
          ),
          const _Seccion('Filas'),
          GrupoFilas(
            filas: [
              FilaAjuste(
                titulo: 'Ejemplo',
                fin: SelectorSegmentos<bool>(
                  opciones: const [
                    OpcionSegmento(valor: false, texto: 'Uno'),
                    OpcionSegmento(valor: true, texto: 'Dos'),
                  ],
                  valor: _segundoSegmento,
                  alCambiar: (valor) => setState(() => _segundoSegmento = valor),
                ),
              ),
              FilaAjuste(titulo: 'Aviso de privacidad', alTocar: () {}),
              FilaAjuste(titulo: 'Eliminar mi cuenta y mis datos', icono: Icons.delete_outline_rounded, alTocar: () {}),
            ],
          ),
          const _Seccion('Hoja inferior'),
          BotonSecundario(texto: 'Abrir hoja de ejemplo', alPresionar: () => _abrirHoja(context)),
          const _Seccion('Barra de navegación'),
          BarraNavegacion(
            destinos: const [
              DestinoBarra(icono: IconoPestana.hoy, etiqueta: 'Hoy'),
              DestinoBarra(icono: IconoPestana.calendario, etiqueta: 'Calendario'),
              DestinoBarra(icono: IconoPestana.comidas, etiqueta: 'Comidas'),
              DestinoBarra(icono: IconoPestana.perfil, etiqueta: 'Perfil'),
            ],
            indice: _pestana,
            alCambiar: (indice) => setState(() => _pestana = indice),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirHoja(BuildContext context) async {
    final elegido = await mostrarHojaInferior<EstadoDia>(
      context: context,
      constructor: (contexto) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const EncabezadoHoja(
            titulo: 'Martes 3',
            subtitulo: 'Tocaba Empuje · sin registro',
            inicio: CirculoDia(estado: EstadoDia.sinActividad, numero: 3),
          ),
          const SizedBox(height: 20),
          const EtiquetaSeccion('¿Qué pasó ese día?'),
          const SizedBox(height: 10),
          for (final opcion in const [EstadoDia.completo, EstadoDia.parcial, EstadoDia.descanso]) ...[
            FilaOpcion(
              titulo: opcion.nombre,
              inicio: PuntoSemaforo(opcion, tamano: 22),
              alTocar: () => Navigator.pop(contexto, opcion),
            ),
            const SizedBox(height: Medidas.espacio2),
          ],
          BotonTexto(texto: 'Cancelar', anchoCompleto: true, alPresionar: () => Navigator.pop(contexto)),
        ],
      ),
    );
    if (elegido == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Elegiste: ${elegido.nombre}')));
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion(this.titulo);

  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Medidas.espacio6, bottom: Medidas.espacio3),
      child: Text(titulo.toUpperCase(), style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

class _Muestra extends StatelessWidget {
  const _Muestra({required this.nombre, required this.color});

  final String nombre;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 44,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
          ),
          const SizedBox(height: 4),
          Text(nombre, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
