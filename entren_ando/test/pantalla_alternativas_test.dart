import 'package:entren_ando/core/diseno.dart';
import 'package:entren_ando/features/perfil/catalogo/catalogo_repositorio.dart';
import 'package:entren_ando/features/rutinas/alternativas/alternativas_repositorio.dart';
import 'package:entren_ando/features/rutinas/alternativas/pantalla_alternativas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class _BdFalsa extends Fake implements Database {}

/// Alternativas en memoria: "Sentadilla con barra" con 3 alternativas.
class _AlternativasFalsas extends AlternativasRepositorio {
  _AlternativasFalsas() : super(_BdFalsa(), 'demo');

  List<Alternativa> lista = [
    for (final (i, id, nombre) in [(1, 2, 'Prensa de piernas'), (2, 3, 'Sentadilla goblet'), (3, 4, 'Zancadas')])
      Alternativa(
        idAlternativa: 'a$id', idProgramado: 'p1', idEjercicio: id, nombre: nombre,
        nombreOficial: nombre, grupoMuscular: 'Pierna', prioridad: i, nombreEquipo: 'Mancuernas',
      ),
  ];

  @override
  Future<EjercicioConAlternativas?> ejercicio(String idProgramado) async => const EjercicioConAlternativas(
        idProgramado: 'p1', idEjercicio: 1, nombre: 'Sentadilla con barra',
        nombreOficial: 'Sentadilla con barra', grupoMuscular: 'Pierna', cicloActivo: true,
      );

  @override
  Future<List<Alternativa>> alternativas(String idProgramado) async => List.of(lista);

  @override
  Future<void> quitar(String idProgramado, String idAlternativa) async {
    lista = [
      for (final (i, a) in lista.where((a) => a.idAlternativa != idAlternativa).indexed)
        Alternativa(
          idAlternativa: a.idAlternativa, idProgramado: a.idProgramado, idEjercicio: a.idEjercicio,
          nombre: a.nombre, nombreOficial: a.nombreOficial, grupoMuscular: a.grupoMuscular,
          prioridad: i + 1, nombreEquipo: a.nombreEquipo,
        ),
    ];
  }
}

/// Catálogo en memoria con el ejercicio principal, una alternativa ya elegida y una nueva.
class _CatalogoFalso extends CatalogoRepositorio {
  _CatalogoFalso() : super(_BdFalsa(), 'demo');

  String? ultimoGrupo;

  @override
  Future<List<EjercicioCatalogo>> buscar({String texto = '', String? grupo, FiltroEquipo equipo = FiltroEquipo.todos}) async {
    ultimoGrupo = grupo;
    return [
      for (final (id, nombre) in [(1, 'Sentadilla con barra'), (3, 'Sentadilla goblet'), (9, 'Sentadilla búlgara')])
        EjercicioCatalogo(idEjercicio: id, nombreOficial: nombre, grupoMuscular: 'Pierna', tipoMovimiento: 'compuesto'),
    ];
  }
}

void main() {
  final temas = {'claro': TemaEntrenAndo.claro(), 'oscuro': TemaEntrenAndo.oscuro()};

  for (final entrada in temas.entries) {
    testWidgets('Alternativas: máximo 3, quitar y no repetir (${entrada.key})', (tester) async {
      tester.view.physicalSize = const Size(1200, 3600);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      final alternativas = _AlternativasFalsas();
      final catalogo = _CatalogoFalso();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          alternativasRepositorioProvider.overrideWith((ref) async => alternativas),
          catalogoRepositorioProvider.overrideWith((ref) async => catalogo),
        ],
        child: MaterialApp(theme: entrada.value, home: const PantallaAlternativas(idProgramado: 'p1')),
      ));
      await tester.pumpAndSettle();

      // Criterio 1: con 3 ya no deja agregar.
      expect(find.text('Zancadas'), findsOneWidget);
      expect(find.text('Ya tiene 3 alternativas. Quita una para agregar otra.'), findsOneWidget);
      expect(find.text('AGREGAR ALTERNATIVA'), findsNothing);

      // Al quitar una, vuelve el botón.
      await tester.tap(find.byTooltip('Quitar').first);
      await tester.pumpAndSettle();
      expect(find.text('Prensa de piernas'), findsNothing);
      expect(find.text('AGREGAR ALTERNATIVA'), findsOneWidget);

      // Criterio 2 y filtro: el selector busca el mismo grupo y no ofrece el
      // ejercicio principal ni una alternativa ya elegida.
      await tester.tap(find.text('AGREGAR ALTERNATIVA'));
      await tester.pumpAndSettle();
      expect(catalogo.ultimoGrupo, 'Pierna');
      expect(find.text('Sentadilla búlgara'), findsOneWidget);
      expect(find.text('Sentadilla goblet'), findsOneWidget); // la de la lista de fondo, no en la hoja
      expect(find.widgetWithText(FilaOpcion, 'Sentadilla goblet'), findsNothing);
      expect(find.widgetWithText(FilaOpcion, 'Sentadilla con barra'), findsNothing);
    });
  }
}
