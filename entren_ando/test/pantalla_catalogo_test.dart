import 'package:entren_ando/core/diseno.dart';
import 'package:entren_ando/features/perfil/catalogo/catalogo_repositorio.dart';
import 'package:entren_ando/features/perfil/catalogo/pantalla_catalogo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class _BdFalsa extends Fake implements DatabaseExecutor {}

/// Repositorio en memoria para dibujar la pantalla sin base de datos.
class _RepositorioFalso extends CatalogoRepositorio {
  _RepositorioFalso() : super(_BdFalsa(), 'demo');

  final Map<int, String> alias = {1: 'Levantamiento de garrafón'};

  static const _ejercicios = [
    (1, 'Peso muerto', 'Espalda', 2, 'Barra olímpica'),
    (2, 'Sentadilla con barra', 'Pierna', 2, 'Barra olímpica'),
    (3, 'Lagartijas', 'Pecho', null, null),
  ];

  @override
  Future<List<EjercicioCatalogo>> buscar({
    String texto = '',
    String? grupo,
    FiltroEquipo equipo = FiltroEquipo.todos,
  }) async {
    return [
      for (final (id, nombre, grupoMuscular, idEquipo, nombreEquipo) in _ejercicios)
        if ((grupo == null || grupo == grupoMuscular) &&
            (texto.isEmpty ||
                nombre.toLowerCase().contains(texto.toLowerCase()) ||
                (alias[id]?.toLowerCase().contains(texto.toLowerCase()) ?? false)))
          EjercicioCatalogo(
            idEjercicio: id,
            nombreOficial: nombre,
            grupoMuscular: grupoMuscular,
            tipoMovimiento: 'compuesto',
            idEquipo: idEquipo,
            nombreEquipo: nombreEquipo,
            alias: alias[id],
          ),
    ];
  }

  @override
  Future<List<String>> gruposMusculares() async => ['Espalda', 'Pecho', 'Pierna'];

  @override
  Future<List<EquipoCatalogo>> equipos() async =>
      [const EquipoCatalogo(idEquipo: 2, nombre: 'Barra olímpica')];

  @override
  Future<void> guardarAlias(int idEjercicio, String nuevo) async => alias[idEjercicio] = nuevo.trim();

  @override
  Future<void> quitarAlias(int idEjercicio) async => alias.remove(idEjercicio);
}

void main() {
  final temas = {'claro': TemaEntrenAndo.claro(), 'oscuro': TemaEntrenAndo.oscuro()};

  for (final entrada in temas.entries) {
    testWidgets('El catálogo muestra alias y nombre oficial en modo ${entrada.key}', (tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final repositorio = _RepositorioFalso();
      await tester.pumpWidget(ProviderScope(
        overrides: [catalogoRepositorioProvider.overrideWith((ref) async => repositorio)],
        child: MaterialApp(theme: entrada.value, home: const PantallaCatalogo()),
      ));
      await tester.pumpAndSettle();

      // Criterio 2: el alias grande y el nombre oficial chico debajo.
      expect(find.text('Levantamiento de garrafón'), findsOneWidget);
      expect(find.text('Peso muerto'), findsOneWidget);
      expect(find.text('3 ejercicios'), findsOneWidget);

      // Criterio 1: el buscador también encuentra por alias.
      await tester.enterText(find.byType(TextFormField), 'garraf');
      await tester.pumpAndSettle();
      expect(find.text('1 ejercicio'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '');
      await tester.pumpAndSettle();

      // Criterio 3: al quitar el alias vuelve el nombre oficial.
      await tester.tap(find.text('Levantamiento de garrafón'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quitar alias'));
      await tester.pumpAndSettle();
      expect(find.text('Levantamiento de garrafón'), findsNothing);
      expect(find.text('Peso muerto'), findsOneWidget);
      expect(repositorio.alias, isEmpty);
    });
  }
}
