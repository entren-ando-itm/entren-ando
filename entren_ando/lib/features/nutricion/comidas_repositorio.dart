import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../core/db/base_datos.dart';
import '../../core/db/escritura_local.dart';
import '../../core/db/fechas.dart';
import '../../core/db/usuario_actual.dart';

/// Una comida registrada (tabla registro_comida).
class Comida {
  const Comida({
    required this.id,
    required this.fechaHora,
    required this.descripcion,
    required this.calorias,
    this.proteinas,
    this.carbohidratos,
    this.grasas,
    required this.porIa,
  });

  final String id;

  /// '2026-11-09T08:00:00-06:00'
  final String fechaHora;
  final String descripcion;
  final int calorias;

  /// Gramos; null si no se capturaron.
  final double? proteinas;
  final double? carbohidratos;
  final double? grasas;

  /// true si vino de un escaneo con IA (ENT-65); false si se capturó a mano.
  final bool porIa;

  /// 'HH:MM'
  String get hora => fechaHora.substring(11, 16);
}

/// Sumas de un día. Las macros que no se capturaron cuentan como 0.
class TotalesDia {
  const TotalesDia({
    this.calorias = 0,
    this.proteinas = 0,
    this.carbohidratos = 0,
    this.grasas = 0,
  });

  final int calorias;
  final double proteinas;
  final double carbohidratos;
  final double grasas;

  /// true si alguna comida del día trae macros (si no, no se dibuja la barra).
  bool get tieneMacros => proteinas + carbohidratos + grasas > 0;
}

/// Comidas de hoy con sus totales.
class ComidasDeHoy {
  const ComidasDeHoy(this.comidas, this.totales);

  final List<Comida> comidas;
  final TotalesDia totales;

  int get totalCalorias => totales.calorias;
}

/// Lo que el usuario captura en "Registrar a mano" o al editar.
class DatosComida {
  const DatosComida({
    required this.descripcion,
    required this.calorias,
    this.proteinas,
    this.carbohidratos,
    this.grasas,
  });

  final String descripcion;
  final int calorias;
  final double? proteinas;
  final double? carbohidratos;
  final double? grasas;

  Map<String, Object?> aFila() => {
        'descripcion': descripcion,
        'calorias': calorias,
        'proteinas_g': proteinas,
        'carbohidratos_g': carbohidratos,
        'grasas_g': grasas,
      };
}

/// Validaciones de la captura (ENT-45). Devuelven el mensaje de error o null.
class ValidarComida {
  ValidarComida._();

  static const int maxDescripcion = 120;
  static const int maxCalorias = 10000;
  static const double maxGramos = 1000;

  static String? descripcion(String? texto) {
    final limpio = texto?.trim() ?? '';
    if (limpio.isEmpty) return 'Escribe qué comiste';
    if (limpio.length > maxDescripcion) return 'Máximo $maxDescripcion letras';
    return null;
  }

  /// Calorías: enteras y de 0 en adelante (CHECK calorias >= 0).
  static String? calorias(String? texto) {
    final limpio = texto?.trim() ?? '';
    if (limpio.isEmpty) return 'Escribe las calorías';
    final valor = int.tryParse(limpio);
    if (valor == null) return 'Solo números enteros, sin decimales';
    if (valor < 0) return 'No pueden ser negativas';
    if (valor > maxCalorias) return 'Revisa la cantidad (máximo $maxCalorias)';
    return null;
  }

  /// Proteínas, carbohidratos o grasas: opcionales, en gramos, con punto o coma.
  static String? gramos(String? texto) {
    final limpio = texto?.trim() ?? '';
    if (limpio.isEmpty) return null;
    final valor = numero(limpio);
    if (valor == null) return 'Escribe solo números';
    if (valor < 0) return 'No pueden ser negativos';
    if (valor > maxGramos) return 'Revisa la cantidad';
    return null;
  }

  /// '72,5' o '72.5' → 72.5, redondeado a un decimal. Vacío → null.
  static double? numero(String? texto) {
    final limpio = texto?.trim().replaceAll(',', '.') ?? '';
    if (limpio.isEmpty) return null;
    final valor = double.tryParse(limpio);
    if (valor == null || valor.isNaN || valor.isInfinite) return null;
    return (valor * 10).roundToDouble() / 10;
  }
}

/// Lectura y escritura de comidas en la base local (ENT-81).
///
/// Funciona igual sin internet: todo va a la base cifrada y el motor de
/// sincronización (ENT-44) lo sube después.
class ComidasRepositorio {
  ComidasRepositorio(this._bd);

  final Database _bd;

  /// Comidas de un día (fecha local de Ciudad de México, 'AAAA-MM-DD') y sus
  /// totales calculados con SUM.
  Future<ComidasDeHoy> delDia(String idUsuario, String fecha) async {
    final filas = await _bd.rawQuery('''
      SELECT id_comida, fecha_hora, descripcion, calorias,
             proteinas_g, carbohidratos_g, grasas_g, origen
      FROM registro_comida
      WHERE id_usuario = ? AND eliminado = 0 AND substr(fecha_hora, 1, 10) = ?
      ORDER BY fecha_hora
    ''', [idUsuario, fecha]);

    final sumas = await _bd.rawQuery('''
      SELECT COALESCE(SUM(calorias), 0)        AS calorias,
             COALESCE(SUM(proteinas_g), 0)     AS proteinas,
             COALESCE(SUM(carbohidratos_g), 0) AS carbohidratos,
             COALESCE(SUM(grasas_g), 0)        AS grasas
      FROM registro_comida
      WHERE id_usuario = ? AND eliminado = 0 AND substr(fecha_hora, 1, 10) = ?
    ''', [idUsuario, fecha]);
    final suma = sumas.first;

    return ComidasDeHoy(
      [
        for (final f in filas)
          Comida(
            id: f['id_comida'] as String,
            fechaHora: f['fecha_hora'] as String,
            descripcion: f['descripcion'] as String,
            calorias: f['calorias'] as int,
            proteinas: (f['proteinas_g'] as num?)?.toDouble(),
            carbohidratos: (f['carbohidratos_g'] as num?)?.toDouble(),
            grasas: (f['grasas_g'] as num?)?.toDouble(),
            porIa: f['origen'] == 'ia',
          ),
      ],
      TotalesDia(
        calorias: (suma['calorias'] as num).toInt(),
        proteinas: (suma['proteinas'] as num).toDouble(),
        carbohidratos: (suma['carbohidratos'] as num).toDouble(),
        grasas: (suma['grasas'] as num).toDouble(),
      ),
    );
  }

  /// Registra una comida a mano con la hora actual. Devuelve su id.
  Future<String> agregar(String idUsuario, DatosComida datos) async {
    final id = await EscrituraLocal(_bd).insertar('registro_comida', {
      ...datos.aFila(),
      'id_usuario': idUsuario,
      'fecha_hora': Fechas.ahoraIso(),
      'origen': 'manual',
    });
    return id!;
  }

  /// Cambia la descripción, calorías y macros. La hora y el origen no cambian.
  Future<void> editar(String idUsuario, String idComida, DatosComida datos) {
    return EscrituraLocal(_bd).actualizar(
      'registro_comida',
      datos.aFila(),
      where: 'id_comida = ? AND id_usuario = ? AND eliminado = 0',
      whereArgs: [idComida, idUsuario],
    );
  }

  /// Borra la comida: la marca eliminado = 1 para que el borrado se sincronice.
  Future<void> borrar(String idUsuario, String idComida) {
    return EscrituraLocal(_bd).marcarEliminado(
      'registro_comida',
      where: 'id_comida = ? AND id_usuario = ?',
      whereArgs: [idComida, idUsuario],
    );
  }
}

final comidasRepositorioProvider = FutureProvider<ComidasRepositorio>((ref) async {
  return ComidasRepositorio(await ref.watch(baseDatosProvider.future));
});

/// Comidas de hoy. Después de guardar, editar o borrar:
/// `ref.invalidate(comidasDeHoyProvider)`.
final comidasDeHoyProvider = FutureProvider<ComidasDeHoy>((ref) async {
  final idUsuario = ref.watch(usuarioActualIdProvider);
  if (idUsuario == null) return const ComidasDeHoy([], TotalesDia());
  final repositorio = await ref.watch(comidasRepositorioProvider.future);
  return repositorio.delDia(idUsuario, Fechas.hoy());
});
