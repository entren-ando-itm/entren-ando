import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../core/db/base_datos.dart';
import '../../core/db/escritura_local.dart';
import '../../core/db/fechas.dart';
import '../../core/db/usuario_actual.dart';

/// Objetivos permitidos por el CHECK de perfil_entrenamiento, con su texto.
const Map<String, String> objetivosPerfil = {
  'fuerza': 'Fuerza',
  'hipertrofia': 'Hipertrofia',
  'perdida_grasa': 'Pérdida de grasa',
  'resistencia': 'Resistencia',
  'salud': 'Salud',
};

/// Niveles permitidos por el CHECK de perfil_entrenamiento, con su texto.
const Map<String, String> nivelesPerfil = {
  'principiante': 'Principiante',
  'intermedio': 'Intermedio',
  'avanzado': 'Avanzado',
};

/// Datos de perfil_entrenamiento del usuario.
class PerfilEntrenamiento {
  const PerfilEntrenamiento({
    required this.objetivo,
    required this.nivel,
    required this.diasPorSemana,
    this.notasLesiones,
  });

  final String objetivo;
  final String nivel;
  final int diasPorSemana;
  final String? notasLesiones;
}

/// Una fila de medicion_biometrica.
class Medicion {
  const Medicion({
    required this.idMedicion,
    required this.fecha,
    required this.pesoKg,
    required this.estaturaCm,
    this.porcentajeGrasa,
  });

  final String idMedicion;
  final String fecha;
  final double pesoKg;
  final double estaturaCm;
  final double? porcentajeGrasa;
}

/// Un equipo del catálogo y si el usuario lo tiene.
class EquipoUsuario {
  const EquipoUsuario({
    required this.idEquipo,
    required this.nombre,
    required this.loTiene,
    this.categoria,
  });

  final int idEquipo;
  final String nombre;
  final String? categoria;
  final bool loTiene;
}

/// Validaciones del perfil: son las mismas reglas que los CHECK del esquema.
/// Devuelven el texto del error o null si el valor está bien.
abstract final class ValidarPerfil {
  /// Convierte "72,5" o "72.5" en número.
  static double? numero(String? texto) =>
      double.tryParse((texto ?? '').trim().replaceAll(',', '.'));

  static String? objetivo(String? valor) =>
      objetivosPerfil.containsKey(valor) ? null : 'Elige tu objetivo.';

  static String? nivel(String? valor) =>
      nivelesPerfil.containsKey(valor) ? null : 'Elige tu nivel.';

  /// CHECK (dias_por_semana BETWEEN 1 AND 7).
  static String? diasPorSemana(String? texto) {
    final dias = int.tryParse((texto ?? '').trim());
    if (dias == null) return 'Escribe un número de días.';
    if (dias < 1 || dias > 7) return 'Elige de 1 a 7 días.';
    return null;
  }

  /// CHECK (peso_kg > 0).
  static String? pesoKg(String? texto) {
    final peso = numero(texto);
    if (peso == null) return 'Escribe tu peso en kg.';
    if (peso <= 0) return 'El peso debe ser mayor que 0.';
    return null;
  }

  /// CHECK (estatura_cm > 0).
  static String? estaturaCm(String? texto) {
    final estatura = numero(texto);
    if (estatura == null) return 'Escribe tu estatura en cm.';
    if (estatura <= 0) return 'La estatura debe ser mayor que 0.';
    return null;
  }

  /// La grasa es opcional; si la escribes, es un porcentaje mayor que 0 y menor que 100.
  static String? porcentajeGrasa(String? texto) {
    if ((texto ?? '').trim().isEmpty) return null;
    final grasa = numero(texto);
    if (grasa == null) return 'Escribe un porcentaje o déjalo vacío.';
    if (grasa <= 0 || grasa >= 100) return 'Debe ser mayor que 0 y menor que 100.';
    return null;
  }
}

/// Lee y guarda el perfil, las mediciones y el equipo del usuario (ENT-18).
///
/// Son datos de salud: solo van a la base local cifrada. No los guardes en
/// SharedPreferences ni los imprimas en logs.
class PerfilRepositorio {
  PerfilRepositorio(this._bd, this._idUsuario);

  final DatabaseExecutor _bd;
  final String _idUsuario;

  Future<PerfilEntrenamiento?> perfil() async {
    final filas = await _bd.rawQuery('''
      SELECT objetivo, nivel_experiencia, dias_por_semana, notas_lesiones
      FROM perfil_entrenamiento
      WHERE id_usuario = ? AND eliminado = 0
    ''', [_idUsuario]);
    if (filas.isEmpty) return null;
    final f = filas.first;
    return PerfilEntrenamiento(
      objetivo: f['objetivo'] as String,
      nivel: f['nivel_experiencia'] as String,
      diasPorSemana: f['dias_por_semana'] as int,
      notasLesiones: f['notas_lesiones'] as String?,
    );
  }

  /// Guarda el perfil (1 a 1 con el usuario): lo actualiza si existe o lo crea.
  Future<void> guardarPerfil(PerfilEntrenamiento perfil) async {
    final error = ValidarPerfil.objetivo(perfil.objetivo) ??
        ValidarPerfil.nivel(perfil.nivel) ??
        ValidarPerfil.diasPorSemana('${perfil.diasPorSemana}');
    if (error != null) throw ArgumentError(error);

    final notas = perfil.notasLesiones?.trim();
    final valores = {
      'objetivo': perfil.objetivo,
      'nivel_experiencia': perfil.nivel,
      'dias_por_semana': perfil.diasPorSemana,
      'notas_lesiones': (notas == null || notas.isEmpty) ? null : notas,
    };
    final escritura = EscrituraLocal(_bd);
    final cambiadas = await escritura.actualizar(
      'perfil_entrenamiento',
      valores,
      where: 'id_usuario = ? AND eliminado = 0',
      whereArgs: [_idUsuario],
    );
    if (cambiadas == 0) {
      await escritura.insertar('perfil_entrenamiento', {'id_usuario': _idUsuario, ...valores});
    }
  }

  /// Historial de mediciones, de la más nueva a la más vieja.
  Future<List<Medicion>> mediciones() async {
    final filas = await _bd.rawQuery('''
      SELECT id_medicion, fecha, peso_kg, estatura_cm, porcentaje_grasa
      FROM medicion_biometrica
      WHERE id_usuario = ? AND eliminado = 0
      ORDER BY fecha DESC, creado_en DESC
    ''', [_idUsuario]);
    return filas
        .map((f) => Medicion(
              idMedicion: f['id_medicion'] as String,
              fecha: f['fecha'] as String,
              pesoKg: (f['peso_kg'] as num).toDouble(),
              estaturaCm: (f['estatura_cm'] as num).toDouble(),
              porcentajeGrasa: (f['porcentaje_grasa'] as num?)?.toDouble(),
            ))
        .toList();
  }

  /// Agrega una medición con la fecha de hoy.
  Future<void> agregarMedicion({
    required double pesoKg,
    required double estaturaCm,
    double? porcentajeGrasa,
  }) async {
    final error = ValidarPerfil.pesoKg('$pesoKg') ??
        ValidarPerfil.estaturaCm('$estaturaCm') ??
        (porcentajeGrasa == null ? null : ValidarPerfil.porcentajeGrasa('$porcentajeGrasa'));
    if (error != null) throw ArgumentError(error);

    await EscrituraLocal(_bd).insertar('medicion_biometrica', {
      'id_usuario': _idUsuario,
      'fecha': Fechas.hoy(),
      'peso_kg': pesoKg,
      'estatura_cm': estaturaCm,
      'porcentaje_grasa': porcentajeGrasa,
    });
  }

  /// Todo el equipo del catálogo, marcando el que tiene el usuario.
  Future<List<EquipoUsuario>> equipo() async {
    final filas = await _bd.rawQuery('''
      SELECT eq.id_equipo, eq.nombre, eq.categoria,
             CASE WHEN ue.id_equipo IS NULL THEN 0 ELSE 1 END AS lo_tiene
      FROM equipo eq
      LEFT JOIN usuario_equipo ue
        ON ue.id_equipo = eq.id_equipo AND ue.id_usuario = ? AND ue.eliminado = 0
      ORDER BY eq.categoria COLLATE NOCASE, eq.nombre COLLATE NOCASE
    ''', [_idUsuario]);
    return filas
        .map((f) => EquipoUsuario(
              idEquipo: f['id_equipo'] as int,
              nombre: f['nombre'] as String,
              categoria: f['categoria'] as String?,
              loTiene: f['lo_tiene'] == 1,
            ))
        .toList();
  }

  /// Marca o desmarca un equipo. Desmarcar es eliminado = 1, nunca DELETE.
  Future<void> cambiarEquipo(int idEquipo, {required bool loTiene}) async {
    final escritura = EscrituraLocal(_bd);
    if (loTiene) {
      // Si ya existía (aunque estuviera eliminado), insertar lo reactiva.
      await escritura.insertar('usuario_equipo', {'id_usuario': _idUsuario, 'id_equipo': idEquipo});
    } else {
      await escritura.marcarEliminado(
        'usuario_equipo',
        where: 'id_usuario = ? AND id_equipo = ? AND eliminado = 0',
        whereArgs: [_idUsuario, idEquipo],
      );
    }
  }
}

/// Repositorio del perfil para el usuario actual (null si no hay usuario).
final perfilRepositorioProvider = FutureProvider<PerfilRepositorio?>((ref) async {
  final idUsuario = ref.watch(usuarioActualIdProvider);
  if (idUsuario == null) return null;
  final bd = await ref.watch(baseDatosProvider.future);
  return PerfilRepositorio(bd, idUsuario);
});

/// Datos de la cuenta, el perfil y la última medición.
class ResumenPerfil {
  const ResumenPerfil({
    required this.nombre,
    required this.correo,
    required this.plan,
    this.objetivo,
    this.nivel,
    this.diasPorSemana,
    this.fechaMedicion,
    this.pesoKg,
    this.estaturaCm,
    this.porcentajeGrasa,
  });

  final String nombre;
  final String correo;
  final String plan;
  final String? objetivo;
  final String? nivel;
  final int? diasPorSemana;
  final String? fechaMedicion;
  final double? pesoKg;
  final double? estaturaCm;
  final double? porcentajeGrasa;
}

/// Resumen del usuario actual (null si no hay usuario).
final resumenPerfilProvider = FutureProvider<ResumenPerfil?>((ref) async {
  final idUsuario = ref.watch(usuarioActualIdProvider);
  if (idUsuario == null) return null;
  final bd = await ref.watch(baseDatosProvider.future);

  final usuarios = await bd.rawQuery('''
    SELECT u.nombre, u.correo, p.nombre AS plan
    FROM usuario u
    JOIN plan p ON p.id_plan = u.id_plan
    WHERE u.id_usuario = ? AND u.eliminado = 0
  ''', [idUsuario]);
  if (usuarios.isEmpty) return null;
  final usuario = usuarios.first;

  final perfiles = await bd.rawQuery('''
    SELECT objetivo, nivel_experiencia, dias_por_semana
    FROM perfil_entrenamiento
    WHERE id_usuario = ? AND eliminado = 0
  ''', [idUsuario]);
  final perfil = perfiles.isEmpty ? null : perfiles.first;

  final mediciones = await bd.rawQuery('''
    SELECT fecha, peso_kg, estatura_cm, porcentaje_grasa
    FROM medicion_biometrica
    WHERE id_usuario = ? AND eliminado = 0
    ORDER BY fecha DESC
    LIMIT 1
  ''', [idUsuario]);
  final medicion = mediciones.isEmpty ? null : mediciones.first;

  return ResumenPerfil(
    nombre: usuario['nombre'] as String,
    correo: usuario['correo'] as String,
    plan: usuario['plan'] as String,
    objetivo: perfil?['objetivo'] as String?,
    nivel: perfil?['nivel_experiencia'] as String?,
    diasPorSemana: perfil?['dias_por_semana'] as int?,
    fechaMedicion: medicion?['fecha'] as String?,
    pesoKg: (medicion?['peso_kg'] as num?)?.toDouble(),
    estaturaCm: (medicion?['estatura_cm'] as num?)?.toDouble(),
    porcentajeGrasa: (medicion?['porcentaje_grasa'] as num?)?.toDouble(),
  );
});
