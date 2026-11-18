import 'package:entren_ando/core/diseno.dart';
import 'package:entren_ando/features/rutinas/pantalla_ciclo.dart';
import 'package:entren_ando/features/rutinas/pantalla_ciclos.dart';
import 'package:entren_ando/features/rutinas/pantalla_editor_dia.dart';
import 'package:entren_ando/features/rutinas/rutinas_repositorio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class _BdFalsa extends Fake implements Database {}

/// Repositorio en memoria: un ciclo activo (plan Gratuito lleno) y uno archivado.
class _RepositorioFalso extends RutinasRepositorio {
  _RepositorioFalso() : super(_BdFalsa(), 'demo');

  final List<Ciclo> lista = [
    const Ciclo(
      idCiclo: 'c1', nombre: 'Semestre agosto-diciembre', fechaInicio: '2026-08-10',
      fechaFin: '2026-12-11', estado: 'activo', origen: 'manual', diasEntrenamiento: 1,
    ),
    const Ciclo(
      idCiclo: 'c0', nombre: 'Semestre enero-junio', fechaInicio: '2026-01-12',
      fechaFin: '2026-06-26', estado: 'archivado', origen: 'ia',
    ),
  ];
  List<EjercicioProgramado> ejercicios = [
    const EjercicioProgramado(
      idProgramado: 'p1', idDia: 'd1', idEjercicio: 1, nombre: 'Sentadilla con barra',
      nombreOficial: 'Sentadilla con barra', grupoMuscular: 'Pierna', orden: 0, series: 4,
      repeticiones: 8, pesoKg: 60, descansoSeg: 120,
    ),
    const EjercicioProgramado(
      idProgramado: 'p2', idDia: 'd1', idEjercicio: 2, nombre: 'Levantamiento de garrafón',
      nombreOficial: 'Peso muerto rumano', grupoMuscular: 'Pierna', orden: 1, series: 3,
      repeticiones: 10, descansoSeg: 90,
    ),
  ];
  final List<String> movimientos = [];

  @override
  Future<List<Ciclo>> ciclos() async => List.of(lista);

  @override
  Future<Ciclo?> ciclo(String idCiclo) async => lista.where((c) => c.idCiclo == idCiclo).firstOrNull;

  @override
  Future<LimiteCiclos> limite() async =>
      LimiteCiclos(plan: 'Gratuito', activos: lista.where((c) => c.activo).length, maximo: 1);

  @override
  Future<List<DiaRutina>> dias(String idCiclo) async => [
        for (var d = 1; d <= 7; d++)
          DiaRutina(
            idDia: 'd$d', idCiclo: idCiclo, diaSemana: d,
            nombre: d == 1 ? 'Pierna' : 'Descanso', esDescanso: d != 1, ejercicios: d == 1 ? 2 : 0,
          ),
      ];

  @override
  Future<DiaRutina?> dia(String idDia) async =>
      const DiaRutina(idDia: 'd1', idCiclo: 'c1', diaSemana: 1, nombre: 'Pierna', esDescanso: false, ejercicios: 2);

  @override
  Future<List<EjercicioProgramado>> ejerciciosDelDia(String idDia) async => List.of(ejercicios);

  @override
  Future<void> moverEjercicio(String idProgramado, int posicion) async {
    movimientos.add('$idProgramado→$posicion');
    final ids = RutinasRepositorio.reordenar(ejercicios.map((e) => e.idProgramado).toList(), idProgramado, posicion);
    ejercicios = [for (final id in ids) ejercicios.firstWhere((e) => e.idProgramado == id)];
  }
}

Future<_RepositorioFalso> _abrir(WidgetTester tester, Widget pantalla, ThemeData tema) async {
  tester.view.physicalSize = const Size(1200, 3600);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final repositorio = _RepositorioFalso();
  await tester.pumpWidget(ProviderScope(
    overrides: [rutinasRepositorioProvider.overrideWith((ref) async => repositorio)],
    child: MaterialApp(theme: tema, home: pantalla),
  ));
  await tester.pumpAndSettle();
  return repositorio;
}

void main() {
  setUpAll(() => initializeDateFormatting('es'));
  final temas = {'claro': TemaEntrenAndo.claro(), 'oscuro': TemaEntrenAndo.oscuro()};

  for (final entrada in temas.entries) {
    testWidgets('Mis ciclos: límite del plan al crear otro (${entrada.key})', (tester) async {
      await _abrir(tester, const PantallaCiclos(), entrada.value);
      expect(find.text('Plan Gratuito · 1 de 1 ciclo activo'), findsOneWidget);
      expect(find.text('Semestre agosto-diciembre'), findsOneWidget);
      expect(find.text('Semestre enero-junio'), findsOneWidget);

      await tester.tap(find.text('NUEVO CICLO'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Semestre enero-junio 2027');
      await tester.tap(find.text('CREAR CICLO'));
      await tester.pumpAndSettle();

      // Criterio 3: pide archivar el actual o ver Premium.
      expect(find.text('LÍMITE DE TU PLAN'), findsOneWidget);
      expect(find.text('Archivar «Semestre agosto-diciembre»'), findsOneWidget);
      expect(find.text('Ver Premium'), findsOneWidget);
    });

    testWidgets('Ciclo archivado: solo lectura y botón Reactivar (${entrada.key})', (tester) async {
      await _abrir(tester, const PantallaCiclo(idCiclo: 'c0'), entrada.value);
      expect(find.text('REACTIVAR CICLO'), findsOneWidget);
      expect(find.text('Editar nombre y fechas'), findsNothing);
      expect(find.text('LUNES'), findsOneWidget);
      expect(find.text('DOMINGO'), findsOneWidget);
    });

    testWidgets('Editor del día: alias y reordenar (${entrada.key})', (tester) async {
      final repositorio = await _abrir(tester, const PantallaEditorDia(idCiclo: 'c1', idDia: 'd1'), entrada.value);
      expect(find.text('Levantamiento de garrafón'), findsOneWidget);
      expect(find.text('Peso muerto rumano'), findsOneWidget);
      expect(find.text('4 × 8 · 60 kg · 120 s de descanso'), findsOneWidget);

      await tester.tap(find.byTooltip('Subir').last);
      await tester.pumpAndSettle();
      expect(repositorio.movimientos, ['p2→0']);
      expect(repositorio.ejercicios.first.idProgramado, 'p2');
    });
  }
}
