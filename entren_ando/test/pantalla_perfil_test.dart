import 'package:entren_ando/core/diseno.dart';
import 'package:entren_ando/features/perfil/pantalla_editar_perfil.dart';
import 'package:entren_ando/features/perfil/pantalla_equipo.dart';
import 'package:entren_ando/features/perfil/pantalla_mediciones.dart';
import 'package:entren_ando/features/perfil/perfil_repositorio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class _BdFalsa extends Fake implements DatabaseExecutor {}

/// Repositorio en memoria para dibujar las pantallas sin base de datos.
class _RepositorioFalso extends PerfilRepositorio {
  _RepositorioFalso() : super(_BdFalsa(), 'demo');

  PerfilEntrenamiento? guardado;
  final List<Medicion> lista = [
    const Medicion(idMedicion: 'm1', fecha: '2026-11-09', pesoKg: 74.6, estaturaCm: 175),
  ];
  final Map<int, bool> tiene = {1: true, 2: false};

  @override
  Future<PerfilEntrenamiento?> perfil() async => const PerfilEntrenamiento(
        objetivo: 'fuerza',
        nivel: 'intermedio',
        diasPorSemana: 4,
      );

  @override
  Future<void> guardarPerfil(PerfilEntrenamiento perfil) async => guardado = perfil;

  @override
  Future<List<Medicion>> mediciones() async => List.of(lista);

  @override
  Future<void> agregarMedicion({required double pesoKg, required double estaturaCm, double? porcentajeGrasa}) async =>
      lista.insert(0, Medicion(idMedicion: 'm2', fecha: '2026-11-10', pesoKg: pesoKg, estaturaCm: estaturaCm));

  @override
  Future<List<EquipoUsuario>> equipo() async => [
        EquipoUsuario(idEquipo: 1, nombre: 'Barra olímpica', categoria: 'Pesos libres', loTiene: tiene[1]!),
        EquipoUsuario(idEquipo: 2, nombre: 'Mancuernas', categoria: 'Pesos libres', loTiene: tiene[2]!),
      ];

  @override
  Future<void> cambiarEquipo(int idEquipo, {required bool loTiene}) async => tiene[idEquipo] = loTiene;
}

Future<_RepositorioFalso> _abrir(WidgetTester tester, Widget pantalla, ThemeData tema) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final repositorio = _RepositorioFalso();
  await tester.pumpWidget(ProviderScope(
    overrides: [perfilRepositorioProvider.overrideWith((ref) async => repositorio)],
    child: MaterialApp(theme: tema, home: pantalla),
  ));
  await tester.pumpAndSettle();
  return repositorio;
}

void main() {
  // Igual que main.dart: nombres de días y meses en español.
  setUpAll(() => initializeDateFormatting('es'));

  final temas = {'claro': TemaEntrenAndo.claro(), 'oscuro': TemaEntrenAndo.oscuro()};

  for (final entrada in temas.entries) {
    testWidgets('Perfil: 9 días muestra el error junto al campo (${entrada.key})', (tester) async {
      final repositorio = await _abrir(tester, const PantallaEditarPerfil(), entrada.value);
      expect(find.text('Fuerza'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, '9');
      await tester.tap(find.text('GUARDAR PERFIL'));
      await tester.pumpAndSettle();
      expect(find.text('Elige de 1 a 7 días.'), findsOneWidget);
      expect(repositorio.guardado, isNull);

      await tester.enterText(find.byType(TextFormField).first, '5');
      await tester.tap(find.text('GUARDAR PERFIL'));
      await tester.pumpAndSettle();
      expect(repositorio.guardado?.diasPorSemana, 5);
    });

    testWidgets('Mediciones: peso 0 muestra el error y una buena se agrega (${entrada.key})', (tester) async {
      final repositorio = await _abrir(tester, const PantallaMediciones(), entrada.value);
      // NumeroConUnidad dibuja el número y la unidad juntos (RichText).
      expect(find.textContaining('74.6', findRichText: true), findsOneWidget);

      await tester.tap(find.text('NUEVA MEDICIÓN'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '0');
      await tester.tap(find.text('GUARDAR MEDICIÓN'));
      await tester.pumpAndSettle();
      expect(find.text('El peso debe ser mayor que 0.'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, '73,2');
      await tester.tap(find.text('GUARDAR MEDICIÓN'));
      await tester.pumpAndSettle();
      expect(repositorio.lista.first.pesoKg, 73.2);
      expect(find.textContaining('73.2', findRichText: true), findsOneWidget);
    });

    testWidgets('Equipo: marcar una casilla lo guarda (${entrada.key})', (tester) async {
      final repositorio = await _abrir(tester, const PantallaEquipo(), entrada.value);
      await tester.tap(find.text('Mancuernas'));
      await tester.pumpAndSettle();
      expect(repositorio.tiene[2], isTrue);
    });
  }
}
