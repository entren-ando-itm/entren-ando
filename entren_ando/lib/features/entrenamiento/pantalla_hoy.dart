import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/db/base_datos.dart';
import '../../core/db/fechas.dart';
import '../../core/db/usuario_actual.dart';
import '../../core/diseno.dart';
import 'bitacora/bitacora_repositorio.dart';
import 'hoy_repositorio.dart';

/// Pestaña Hoy: vista del día tipo horario escolar (ENT-20, ENT-39 y ENT-40).
///
/// Diseño: `docs/pantallas/02_hoy.png`. Muestra, de arriba hacia abajo:
/// 1. Encabezado con el ciclo, el día y lo que toca hoy.
/// 2. Los ejercicios de hoy con su avance (completado, "Sigue" o pendiente).
/// 3. El botón "Seguir entrenando", el único botón principal de la pantalla.
/// 4. Franjas con los días que vienen esta semana (la "escalera").
///
/// Todo se lee de la base local, así que funciona en modo avión (RNF-01).
/// "Buenos días", "Buenas tardes" o "Buenas noches" según la hora (ENT-127):
/// 5:00–11:59, 12:00–18:59 y 19:00–4:59, hora de Ciudad de México.
String saludoSegunHora(int hora) {
  if (hora >= 5 && hora < 12) return 'Buenos días';
  if (hora >= 12 && hora < 19) return 'Buenas tardes';
  return 'Buenas noches';
}

/// Primer nombre del usuario actual, para el saludo de Hoy.
final nombreUsuarioProvider = FutureProvider<String?>((ref) async {
  final idUsuario = ref.watch(usuarioActualIdProvider);
  if (idUsuario == null) return null;
  final bd = await ref.watch(baseDatosProvider.future);
  final filas = await bd.rawQuery(
    'SELECT nombre FROM usuario WHERE id_usuario = ? AND eliminado = 0',
    [idUsuario],
  );
  final nombre = (filas.isEmpty ? null : filas.first['nombre'] as String?)?.trim() ?? '';
  if (nombre.isEmpty) return null;
  // El demo se llama "Usuario Demo": con solo el primer nombre diría "Usuario".
  if (ref.watch(sesionActualProvider)?.esDemo ?? false) return nombre;
  return nombre.split(RegExp(r'\s+')).first;
});

/// "Buenas noches, Pablo" arriba del encabezado de Hoy (ENT-127).
class _Saludo extends ConsumerWidget {
  const _Saludo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nombre = ref.watch(nombreUsuarioProvider).value;
    final saludo = saludoSegunHora(Fechas.ahoraCdmx().hour);
    // Mismo estilo que el nombre en Perfil (headlineSmall, tinta) para que se
    // distinga de la etiqueta del ciclo, y más aire antes del encabezado.
    return Padding(
      padding: const EdgeInsets.only(bottom: Medidas.espacio6),
      child: Text(
        nombre == null ? saludo : '$saludo, $nombre',
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: context.colores.tinta),
      ),
    );
  }
}

class PantallaHoy extends ConsumerWidget {
  const PantallaHoy({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diaDeHoy = ref.watch(diaDeHoyProvider);

    return Scaffold(
      body: diaDeHoy.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => MensajeCentrado(
          'No se pudo leer la base local.\n$error',
          icono: Icons.error_outline_rounded,
        ),
        data: (dia) {
          if (dia == null) {
            return const MensajeCentrado('No tienes un ciclo de rutina activo.');
          }
          return ContenidoPantalla(
            children: [
              const _Saludo(),
              _Encabezado(dia),
              const SizedBox(height: Medidas.espacio5),
              ..._cuerpoDelDia(context, dia),
              const SizedBox(height: Medidas.espacio5),
              _FranjasSemana(dia),
            ],
          );
        },
      ),
    );
  }

  /// Ejercicios y botón, o el aviso de descanso / día terminado.
  List<Widget> _cuerpoDelDia(BuildContext context, DiaDeHoy dia) {
    if (dia.esDescanso) {
      return const [
        Aviso('Hoy toca descanso. Recupérate bien.', icono: Icons.bedtime_outlined),
      ];
    }
    if (dia.ejercicios.isEmpty) {
      return const [
        Aviso('Este día de tu rutina todavía no tiene ejercicios.',
            icono: Icons.info_outline_rounded),
      ];
    }

    final siguiente = dia.siguiente;
    return [
      for (final ejercicio in dia.ejercicios)
        _FilaEjercicio(ejercicio, esSiguiente: identical(ejercicio, siguiente)),
      const SizedBox(height: Medidas.espacio5),
      if (siguiente == null)
        const Aviso('¡Terminaste el entrenamiento de hoy!', icono: Icons.check_circle_outline_rounded)
      else
        BotonPrincipal(
          texto: 'Seguir entrenando',
          icono: Icons.play_arrow_rounded,
          alPresionar: () => _abrirEjercicio(context, siguiente),
        ),
      // ENT-50: comentario libre de la sesión (la IA lo usa en el feedback).
      const SizedBox(height: Medidas.espacio2),
      const _ComentarioSesion(),
    ];
  }

  /// Abre la pantalla del ejercicio que sigue.
  void _abrirEjercicio(BuildContext context, EjercicioDelDia ejercicio) {
    context.push('/hoy/ejercicio/${ejercicio.idProgramado}');
  }
}

/// "CICLO DEMO · TORSO Y PIERNA", "LUNES" y "9 de noviembre · Pierna".
class _Encabezado extends StatelessWidget {
  const _Encabezado(this.dia);

  final DiaDeHoy dia;

  @override
  Widget build(BuildContext context) {
    final ahora = Fechas.ahoraCdmx();
    final fecha = DateFormat("d 'de' MMMM", 'es').format(ahora);
    final queToca = dia.esDescanso ? 'Descanso' : dia.nombreDia;
    return EncabezadoPantalla(
      etiqueta: dia.nombreCiclo,
      titulo: nombresDias[ahora.weekday - 1],
      subtitulo: '$fecha · $queToca',
    );
  }
}

/// Un ejercicio de hoy: círculo de estado, nombre (alias) y series × repeticiones.
class _FilaEjercicio extends StatelessWidget {
  const _FilaEjercicio(this.ejercicio, {required this.esSiguiente});

  final EjercicioDelDia ejercicio;

  /// true si es el primer ejercicio sin completar (lleva la marca "Sigue").
  final bool esSiguiente;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final textos = Theme.of(context).textTheme;
    final hecho = ejercicio.completado;

    return Semantics(
      label: hecho ? 'Completado' : (esSiguiente ? 'Sigue' : 'Pendiente'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 46),
        child: Row(
          children: [
            _CirculoEstado(completado: hecho, esSiguiente: esSiguiente),
            const SizedBox(width: Medidas.espacio3),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      ejercicio.nombre,
                      overflow: TextOverflow.ellipsis,
                      style: textos.titleMedium?.copyWith(
                        // Completado: tachado en verde, como en el diseño.
                        color: hecho ? ColoresSemaforo.completa : null,
                        decoration: hecho ? TextDecoration.lineThrough : null,
                        decorationColor: ColoresSemaforo.completa,
                      ),
                    ),
                  ),
                  if (esSiguiente) ...[
                    const SizedBox(width: Medidas.espacio2),
                    const Pastilla('Sigue', resaltada: true, chica: true),
                  ],
                ],
              ),
            ),
            const SizedBox(width: Medidas.espacio2),
            Text(
              _detalle(ejercicio),
              style: textos.bodyMedium?.copyWith(
                color: colores.tinta2,
                fontFeatures: TipografiaEntrenAndo.numerosTabulares,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "4 × 12 · 120 kg", "4 × 8" o "3 × 45 s" para ejercicios por tiempo.
  static String _detalle(EjercicioDelDia e) {
    if (e.trabajoSeg != null) return '${e.series} × ${e.trabajoSeg} s';
    final texto = '${e.series} × ${e.repeticiones}';
    final peso = e.pesoKg;
    if (peso == null) return texto;
    final kg = peso % 1 == 0 ? peso.toStringAsFixed(0) : peso.toStringAsFixed(1);
    return '$texto · $kg kg';
  }
}

/// Círculo de 24: verde con palomita (completado), en tinta (sigue) o gris (pendiente).
class _CirculoEstado extends StatelessWidget {
  const _CirculoEstado({required this.completado, required this.esSiguiente});

  final bool completado;
  final bool esSiguiente;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final color = completado
        ? ColoresSemaforo.completa
        : (esSiguiente ? colores.tinta : colores.sup2);
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: completado
          ? Icon(Icons.check_rounded, size: 16, color: colores.fondo)
          : null,
    );
  }
}

/// Franjas con los días que vienen esta semana ("MARTES · Empuje").
///
/// Cada franja usa una superficie un nivel más oscura (sup1 → sup4) y ocupa todo
/// el ancho de la pantalla, como la "escalera" del diseño.
class _FranjasSemana extends StatelessWidget {
  const _FranjasSemana(this.dia);

  final DiaDeHoy dia;

  static const double _altoFranja = 60;

  @override
  Widget build(BuildContext context) {
    final dias = dia.siguientesDias;
    final nota = _notaSinRutina(dia.diasSinRutina);
    if (dias.isEmpty && nota == null) return const SizedBox.shrink();

    final colores = context.colores;
    final textos = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, restricciones) {
        // ContenidoPantalla deja 28 de margen a cada lado; las franjas lo rebasan
        // para llegar de orilla a orilla.
        final anchoCompleto = restricciones.maxWidth + Medidas.margen * 2;

        Widget franja({required int nivel, required Widget child, double alto = _altoFranja}) {
          return SizedBox(
            height: alto,
            child: OverflowBox(
              minWidth: anchoCompleto,
              maxWidth: anchoCompleto,
              child: Container(
                color: colores.superficie(nivel.clamp(1, 4)),
                padding: const EdgeInsets.symmetric(horizontal: Medidas.margen),
                alignment: Alignment.centerLeft,
                child: child,
              ),
            ),
          );
        }

        return Column(
          children: [
            for (var i = 0; i < dias.length; i++)
              franja(
                nivel: i + 1,
                // Si hay nota, va dentro de la última franja.
                alto: (i == dias.length - 1 && nota != null) ? _altoFranja + 24 : _altoFranja,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            nombresDias[dias[i].diaSemana - 1].toUpperCase(),
                            style: textos.titleLarge,
                          ),
                        ),
                        Text(
                          dias[i].esDescanso ? 'Descanso' : dias[i].nombre,
                          style: textos.bodyMedium,
                        ),
                      ],
                    ),
                    if (i == dias.length - 1 && nota != null)
                      Text(nota, style: textos.bodySmall),
                  ],
                ),
              ),
            // Si no viene ningún día con rutina (por ejemplo, el viernes), solo la nota.
            if (dias.isEmpty && nota != null)
              franja(nivel: 1, child: Text(nota, style: textos.bodySmall)),
          ],
        );
      },
    );
  }

  /// "Sábado y domingo: descanso" para los días que no están en la rutina.
  static String? _notaSinRutina(List<int> dias) {
    if (dias.isEmpty) return null;
    final nombres = [for (final d in dias) nombresDias[d - 1]];
    final lista = nombres.length == 1
        ? nombres.first
        : '${nombres.sublist(0, nombres.length - 1).join(', ')} y ${nombres.last}';
    final texto = lista[0] + lista.substring(1).toLowerCase();
    return '$texto: descanso';
  }
}

/// Estado de la sesión de hoy y su comentario libre (ENT-50 / ENT-90).
///
/// Solo aparece cuando ya hay sesión (se marcó al menos una serie o un ejercicio).
class _ComentarioSesion extends ConsumerWidget {
  const _ComentarioSesion();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sesion = ref.watch(sesionDeHoyProvider).value;
    if (sesion == null || sesion.estado == 'descanso') return const SizedBox.shrink();
    final textos = Theme.of(context).textTheme;
    final completa = sesion.estado == 'completa';
    final comentario = sesion.comentario;

    return Tarjeta(
      alTocar: () => _editar(context, ref, comentario),
      child: Row(
        children: [
          PuntoSemaforo(completa ? EstadoDia.completo : EstadoDia.parcial, tamano: 14),
          const SizedBox(width: Medidas.espacio3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(completa ? 'Sesión completa' : 'Sesión parcial', style: textos.titleMedium),
                Text(
                  comentario ?? 'Agrega un comentario (por ejemplo, "me dolió el hombro")',
                  style: textos.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.edit_outlined, size: 20, color: context.colores.tinta2),
        ],
      ),
    );
  }

  Future<void> _editar(BuildContext context, WidgetRef ref, String? actual) async {
    final texto = await mostrarHojaInferior<String>(
      context: context,
      constructor: (context) => _HojaComentario(inicial: actual ?? ''),
    );
    if (texto == null) return;
    final repositorio = await ref.read(bitacoraRepositorioProvider.future);
    await repositorio?.guardarComentario(texto);
    ref.invalidate(sesionDeHoyProvider);
  }
}

class _HojaComentario extends StatefulWidget {
  const _HojaComentario({required this.inicial});

  final String inicial;

  @override
  State<_HojaComentario> createState() => _HojaComentarioState();
}

class _HojaComentarioState extends State<_HojaComentario> {
  late final TextEditingController _controlador = TextEditingController(text: widget.inicial);

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EncabezadoHoja(titulo: 'Comentario del día', subtitulo: 'Lo verá la IA en tu feedback'),
        const SizedBox(height: Medidas.espacio5),
        CampoTexto(
          etiqueta: 'Comentario',
          controlador: _controlador,
          pista: 'Me dolió el hombro',
          maxLineas: 3,
        ),
        const SizedBox(height: Medidas.espacio5),
        BotonSecundario(
          texto: 'Guardar',
          nivel: 2,
          alPresionar: () => Navigator.pop(context, _controlador.text),
        ),
      ],
    );
  }
}
