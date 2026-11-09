import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/base_datos.dart';
import '../../core/db/usuario_actual.dart';

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
