import 'dart:convert';

import 'package:entren_ando/features/ia/rutina/rutina_ia_repositorio.dart';
import 'package:entren_ando/features/perfil/catalogo/catalogo_repositorio.dart';
import 'package:entren_ando/features/perfil/perfil_repositorio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pruebas de la rutina con IA (ENT-58). No necesitan emulador ni internet.
void main() {
  final nombres = {
    for (final (id, oficial, alias, grupo) in [
      (1, 'Sentadilla con barra', null, 'Pierna'),
      (2, 'Prensa de piernas', null, 'Pierna'),
      (3, 'Peso muerto rumano', 'Levantamiento de garrafón', 'Pierna'),
    ])
      id: EjercicioCatalogo(
        idEjercicio: id, nombreOficial: oficial, grupoMuscular: grupo, tipoMovimiento: 'compuesto', alias: alias,
      ),
  };

  test('A la IA solo va lo necesario: sin alias, nombre ni correo (decisión 5)', () {
    final entrada = RutinaIaRepositorio.entradaParaIa(
      perfil: const PerfilEntrenamiento(objetivo: 'fuerza', nivel: 'intermedio', diasPorSemana: 4, notasLesiones: '  '),
      medicion: const Medicion(idMedicion: 'm', fecha: '2026-11-20', pesoKg: 74.6, estaturaCm: 175),
      equipo: [2, 5],
      catalogo: [(id: 3, nombreOficial: 'Peso muerto rumano')],
    );
    final texto = jsonEncode(entrada);
    expect(texto, isNot(contains('garrafón')));
    expect(texto, isNot(contains('@')));
    expect(entrada['perfil'], {
      'objetivo': 'fuerza', 'nivel_experiencia': 'intermedio', 'dias_por_semana': 4, 'notas_lesiones': null,
    });
    expect(entrada['catalogo'], [{'id_ejercicio': 3, 'nombre_oficial': 'Peso muerto rumano'}]);
    expect((entrada['medicion'] as Map)['peso_kg'], 74.6);
  });

  test('La respuesta se vuelve una propuesta de 7 días con el alias para mostrar', () {
    final p = RutinaIaRepositorio.propuestaDeRespuesta({
      'id_solicitud': 'sol-1',
      'descartados': [99],
      'rutina': {
        'nombre_ciclo': 'Pierna y torso',
        'dias': [
          {'dia_semana': 1, 'nombre': 'Pierna', 'es_descanso': false, 'ejercicios': [
            {'id_ejercicio': 3, 'series': 4, 'reps': 8, 'peso_kg': 60, 'descanso_seg': 120, 'alternativas': [1, 1, 3, 77, 2]},
            {'id_ejercicio': 99, 'series': 3, 'reps': 10, 'peso_kg': null, 'descanso_seg': 90, 'alternativas': []},
          ]},
          {'dia_semana': 1, 'nombre': 'Repetido', 'es_descanso': false, 'ejercicios': []},
        ],
      },
    }, nombres);
    expect(p.idSolicitud, 'sol-1');
    expect(p.nombreCiclo, 'Pierna y torso');
    expect(p.dias.length, 7);
    expect(p.descartados, 1);
    expect(p.diasEntrenamiento, 1);
    final ej = p.dias.first.ejercicios.single;
    expect(ej.nombre, 'Levantamiento de garrafón');
    expect(ej.nombreOficial, 'Peso muerto rumano');
    expect(ej.alternativas, [1, 2]); // sin repetidas, sin el mismo ni ids desconocidos
    expect(p.dias[1].esDescanso, isTrue);
  });

  test('Respuesta sin id_solicitud o sin rutina: error claro', () {
    expect(() => RutinaIaRepositorio.propuestaDeRespuesta({'rutina': {}}, nombres), throwsA(isA<ErrorRutinaIa>()));
    expect(() => RutinaIaRepositorio.propuestaDeRespuesta({'id_solicitud': 'x'}, nombres), throwsA(isA<ErrorRutinaIa>()));
  });
}
