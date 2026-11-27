import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/db/base_datos.dart';
import '../../../core/db/usuario_actual.dart';
import '../../nube/cliente_supabase.dart';
import '../../perfil/catalogo/catalogo_repositorio.dart';
import '../../perfil/perfil_repositorio.dart';
import '../../rutinas/rutinas_repositorio.dart';

/// Un ejercicio de la propuesta de la IA. Se edita en memoria: nada se guarda
/// hasta que el usuario confirma (ENT-58).
class EjercicioPropuesto {
  EjercicioPropuesto({
    required this.idEjercicio,
    required this.nombre,
    required this.nombreOficial,
    required this.grupoMuscular,
    required this.series,
    required this.repeticiones,
    required this.descansoSeg,
    this.pesoKg,
    List<int>? alternativas,
  }) : alternativas = alternativas ?? [];

  int idEjercicio;

  /// Alias del usuario o nombre oficial (solo para mostrar).
  String nombre;
  String nombreOficial;
  String grupoMuscular;
  int series;
  int repeticiones;
  double? pesoKg;
  int descansoSeg;
  List<int> alternativas;
}

/// Un día de la propuesta.
class DiaPropuesto {
  DiaPropuesto({required this.diaSemana, required this.nombre, required this.esDescanso, List<EjercicioPropuesto>? ejercicios})
      : ejercicios = ejercicios ?? [];

  final int diaSemana;
  String nombre;
  bool esDescanso;
  List<EjercicioPropuesto> ejercicios;

  String get nombreDiaSemana => nombresDiaSemana[diaSemana - 1];
}

/// La semana que propuso la IA, con el id de la solicitud que la generó.
class PropuestaRutina {
  PropuestaRutina({required this.idSolicitud, required this.nombreCiclo, required this.dias, this.descartados = 0});

  final String idSolicitud;
  String nombreCiclo;

  /// Siempre 7, de lunes a domingo.
  final List<DiaPropuesto> dias;

  /// Cuántos ejercicios inventados descartó la función.
  final int descartados;

  int get diasEntrenamiento => dias.where((d) => !d.esDescanso && d.ejercicios.isNotEmpty).length;
}

/// Error con un mensaje en español para el usuario.
class ErrorRutinaIa implements Exception {
  const ErrorRutinaIa(this.mensaje, {this.irAPerfil = false});

  final String mensaje;

  /// true si falta completar el perfil antes de generar.
  final bool irAPerfil;

  @override
  String toString() => mensaje;
}

abstract final class MensajesRutinaIa {
  static const sinPerfil = 'Primero completa tu objetivo, nivel y días por semana.';
  static const sinNube = 'La IA necesita conexión con la nube. Inicia sesión con tu cuenta (o configura el .env) '
      'y vuelve a intentar; mientras, crea tu rutina a mano.';
  static const tardo = 'La IA tardó demasiado. Intenta de nuevo o crea tu rutina a mano.';
  static const generico = 'No se pudo generar la rutina. Intenta de nuevo o crea tu rutina a mano.';
  static const respuestaRara = 'La IA respondió algo que no se pudo leer. Intenta de nuevo.';
}

/// Llama a la función generar-rutina (ENT-57). Se puede cambiar en pruebas.
abstract class ServicioRutinaIa {
  /// Devuelve el cuerpo de la respuesta: `{id_solicitud, rutina, descartados}`.
  Future<Map<String, dynamic>> generar(Map<String, dynamic> entrada);
}

/// La de verdad: `functions.invoke('generar-rutina')` con la sesión del usuario.
class ServicioRutinaIaSupabase implements ServicioRutinaIa {
  /// La app espera 30 s como máximo (criterio 1).
  static const Duration espera = Duration(seconds: 30);

  @override
  Future<Map<String, dynamic>> generar(Map<String, dynamic> entrada) async {
    final cliente = ClienteSupabase.cliente;
    if (cliente == null || cliente.auth.currentSession == null) {
      throw const ErrorRutinaIa(MensajesRutinaIa.sinNube);
    }
    try {
      final respuesta = await cliente.functions.invoke('generar-rutina', body: entrada).timeout(espera);
      final datos = respuesta.data;
      if (datos is! Map) throw const ErrorRutinaIa(MensajesRutinaIa.respuestaRara);
      return Map<String, dynamic>.from(datos);
    } on TimeoutException {
      throw const ErrorRutinaIa(MensajesRutinaIa.tardo);
    } on FunctionException catch (e) {
      // La función responde {error: "mensaje en español"} (ver su LEEME).
      final detalles = e.details;
      final mensaje = detalles is Map && detalles['error'] is String ? detalles['error'] as String : null;
      throw ErrorRutinaIa(mensaje ?? MensajesRutinaIa.generico);
    } on ErrorRutinaIa {
      rethrow;
    } catch (_) {
      throw const ErrorRutinaIa(MensajesRutinaIa.generico);
    }
  }
}

final servicioRutinaIaProvider = Provider<ServicioRutinaIa>((ref) => ServicioRutinaIaSupabase());

/// Arma la rutina con IA y la guarda como ciclo (ENT-58).
class RutinaIaRepositorio {
  RutinaIaRepositorio({
    required this.bd,
    required this.perfil,
    required this.catalogo,
    required this.rutinas,
    required this.servicio,
  });

  final DatabaseExecutor bd;
  final PerfilRepositorio perfil;
  final CatalogoRepositorio catalogo;
  final RutinasRepositorio rutinas;
  final ServicioRutinaIa servicio;

  /// Lo que se manda a la función. Sin alias, nombre ni correo (decisión 5).
  /// Es público y estático para probarlo sin base.
  static Map<String, dynamic> entradaParaIa({
    required PerfilEntrenamiento perfil,
    Medicion? medicion,
    required List<int> equipo,
    required List<({int id, String nombreOficial})> catalogo,
  }) {
    final notas = perfil.notasLesiones?.trim();
    return {
      'perfil': {
        'objetivo': perfil.objetivo,
        'nivel_experiencia': perfil.nivel,
        'dias_por_semana': perfil.diasPorSemana,
        'notas_lesiones': (notas == null || notas.isEmpty) ? null : notas,
      },
      'medicion': medicion == null
          ? null
          : {
              'peso_kg': medicion.pesoKg,
              'estatura_cm': medicion.estaturaCm,
              'porcentaje_grasa': medicion.porcentajeGrasa,
            },
      'equipo': equipo,
      'catalogo': [for (final c in catalogo) {'id_ejercicio': c.id, 'nombre_oficial': c.nombreOficial}],
    };
  }

  /// Catálogo para la IA: ejercicios de peso corporal y los del equipo que
  /// tiene el usuario. Solo id y nombre oficial (nunca el alias).
  Future<List<({int id, String nombreOficial})>> _catalogoParaIa(List<int> equipo) async {
    final marcas = List.filled(equipo.length, '?').join(', ');
    final filas = await bd.rawQuery(
      'SELECT id_ejercicio, nombre_oficial FROM ejercicio '
      'WHERE id_equipo IS NULL${equipo.isEmpty ? '' : ' OR id_equipo IN ($marcas)'} '
      'ORDER BY id_ejercicio',
      equipo,
    );
    return [for (final f in filas) (id: f['id_ejercicio'] as int, nombreOficial: f['nombre_oficial'] as String)];
  }

  /// Pide la propuesta a la IA. No guarda nada.
  Future<PropuestaRutina> generar() async {
    final datosPerfil = await perfil.perfil();
    if (datosPerfil == null) throw const ErrorRutinaIa(MensajesRutinaIa.sinPerfil, irAPerfil: true);
    final mediciones = await perfil.mediciones();
    final equipo = [for (final e in await perfil.equipo()) if (e.loTiene) e.idEquipo];
    final entrada = entradaParaIa(
      perfil: datosPerfil,
      medicion: mediciones.isEmpty ? null : mediciones.first,
      equipo: equipo,
      catalogo: await _catalogoParaIa(equipo),
    );
    final respuesta = await servicio.generar(entrada);
    final nombres = {for (final e in await catalogo.buscar()) e.idEjercicio: e};
    return propuestaDeRespuesta(respuesta, nombres);
  }

  /// Convierte la respuesta de la función en una propuesta editable. Los ids
  /// que no están en el catálogo del celular se ignoran.
  static PropuestaRutina propuestaDeRespuesta(Map<String, dynamic> respuesta, Map<int, EjercicioCatalogo> nombres) {
    final idSolicitud = respuesta['id_solicitud'];
    final rutina = respuesta['rutina'];
    if (idSolicitud is! String || rutina is! Map) throw const ErrorRutinaIa(MensajesRutinaIa.respuestaRara);
    final porDia = <int, DiaPropuesto>{};
    for (final crudo in (rutina['dias'] as List? ?? const [])) {
      if (crudo is! Map) continue;
      final numero = (crudo['dia_semana'] as num?)?.toInt() ?? 0;
      if (numero < 1 || numero > 7 || porDia.containsKey(numero)) continue;
      final ejercicios = <EjercicioPropuesto>[];
      for (final ej in (crudo['ejercicios'] as List? ?? const [])) {
        if (ej is! Map) continue;
        final cat = nombres[(ej['id_ejercicio'] as num?)?.toInt()];
        if (cat == null) continue;
        ejercicios.add(EjercicioPropuesto(
          idEjercicio: cat.idEjercicio,
          nombre: cat.nombreVisible,
          nombreOficial: cat.nombreOficial,
          grupoMuscular: cat.grupoMuscular,
          series: ((ej['series'] as num?)?.toInt() ?? 3).clamp(1, 20),
          repeticiones: ((ej['reps'] as num?)?.toInt() ?? 10).clamp(1, 100),
          pesoKg: (ej['peso_kg'] as num?)?.toDouble(),
          descansoSeg: ((ej['descanso_seg'] as num?)?.toInt() ?? 90).clamp(0, 900),
          alternativas: <int>{
            for (final a in (ej['alternativas'] as List? ?? const []))
              if (a is num && nombres.containsKey(a.toInt()) && a.toInt() != cat.idEjercicio) a.toInt(),
          }.take(3).toList(),
        ));
      }
      final esDescanso = crudo['es_descanso'] == true || ejercicios.isEmpty;
      porDia[numero] = DiaPropuesto(
        diaSemana: numero,
        nombre: esDescanso ? 'Descanso' : ((crudo['nombre'] as String?)?.trim().isNotEmpty == true ? (crudo['nombre'] as String).trim() : 'Entrenamiento'),
        esDescanso: esDescanso,
        ejercicios: esDescanso ? [] : ejercicios,
      );
    }
    final nombre = rutina['nombre_ciclo'];
    return PropuestaRutina(
      idSolicitud: idSolicitud,
      nombreCiclo: nombre is String && nombre.trim().isNotEmpty ? nombre.trim() : 'Rutina con IA',
      dias: [for (var d = 1; d <= 7; d++) porDia[d] ?? DiaPropuesto(diaSemana: d, nombre: 'Descanso', esDescanso: true)],
      descartados: (respuesta['descartados'] as List?)?.length ?? 0,
    );
  }

  /// Guarda la propuesta como ciclo activo con origen 'ia' y su id_solicitud
  /// (criterio 3). Lanza [LimiteCiclosAlcanzado] si el plan no permite otro.
  Future<String> guardar(
    PropuestaRutina propuesta, {
    required String fechaInicio,
    String? fechaFin,
    List<String> archivarAntes = const [],
  }) {
    return rutinas.crearCicloCompleto(
      nombre: propuesta.nombreCiclo,
      fechaInicio: fechaInicio,
      fechaFin: fechaFin,
      origen: 'ia',
      idSolicitud: propuesta.idSolicitud,
      archivarAntes: archivarAntes,
      dias: [
        for (final d in propuesta.dias)
          DiaNuevo(
            diaSemana: d.diaSemana,
            nombre: d.nombre,
            esDescanso: d.esDescanso,
            ejercicios: [
              for (final e in d.ejercicios)
                EjercicioNuevo(
                  idEjercicio: e.idEjercicio,
                  series: e.series,
                  repeticiones: e.repeticiones,
                  pesoKg: e.pesoKg,
                  descansoSeg: e.descansoSeg,
                  alternativas: e.alternativas,
                ),
            ],
          ),
      ],
    );
  }
}

/// Repositorio de la rutina con IA para el usuario actual (null sin sesión).
final rutinaIaRepositorioProvider = FutureProvider<RutinaIaRepositorio?>((ref) async {
  final idUsuario = ref.watch(usuarioActualIdProvider);
  if (idUsuario == null) return null;
  final bd = await ref.watch(baseDatosProvider.future);
  return RutinaIaRepositorio(
    bd: bd,
    perfil: PerfilRepositorio(bd, idUsuario),
    catalogo: CatalogoRepositorio(bd, idUsuario),
    rutinas: RutinasRepositorio(bd, idUsuario),
    servicio: ref.watch(servicioRutinaIaProvider),
  );
});
