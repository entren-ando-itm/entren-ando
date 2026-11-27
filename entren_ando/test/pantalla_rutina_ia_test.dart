import 'package:entren_ando/core/diseno.dart';
import 'package:entren_ando/features/ia/rutina/pantalla_rutina_ia.dart';
import 'package:entren_ando/features/ia/rutina/rutina_ia_repositorio.dart';
import 'package:entren_ando/features/perfil/catalogo/catalogo_repositorio.dart';
import 'package:entren_ando/features/perfil/perfil_repositorio.dart';
import 'package:entren_ando/features/rutinas/rutinas_repositorio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class _BdFalsa extends Fake implements Database {}

class _ServicioSinUso implements ServicioRutinaIa {
  @override
  Future<Map<String, dynamic>> generar(Map<String, dynamic> entrada) => throw UnimplementedError();
}

/// Rutinas en memoria: plan Gratuito con [activos] ciclos activos.
class _RutinasFalsas extends RutinasRepositorio {
  _RutinasFalsas(this.activos) : super(_BdFalsa(), 'demo');

  final int activos;

  @override
  Future<LimiteCiclos> limite() async => LimiteCiclos(plan: 'Gratuito', activos: activos, maximo: 1);

  @override
  Future<List<Ciclo>> ciclos() async => [
        if (activos > 0)
          const Ciclo(idCiclo: 'c1', nombre: 'Ciclo demo', fechaInicio: '2026-09-01', estado: 'activo', origen: 'ia'),
      ];
}

/// Repositorio de IA falso: [generar] devuelve una propuesta fija o un error.
class _RutinaIaFalsa extends RutinaIaRepositorio {
  _RutinaIaFalsa({this.error, int activos = 0})
      : super(
          bd: _BdFalsa(),
          perfil: PerfilRepositorio(_BdFalsa(), 'demo'),
          catalogo: CatalogoRepositorio(_BdFalsa(), 'demo'),
          rutinas: _RutinasFalsas(activos),
          servicio: _ServicioSinUso(),
        );

  final ErrorRutinaIa? error;
  PropuestaRutina? guardada;
  List<String>? archivadosAlGuardar;

  @override
  Future<PropuestaRutina> generar() async {
    if (error != null) throw error!;
    return PropuestaRutina(
      idSolicitud: 'sol-1',
      nombreCiclo: 'Torso y pierna',
      descartados: 1,
      dias: [
        DiaPropuesto(diaSemana: 1, nombre: 'Pierna', esDescanso: false, ejercicios: [
          EjercicioPropuesto(
            idEjercicio: 1, nombre: 'Sentadilla con barra', nombreOficial: 'Sentadilla con barra',
            grupoMuscular: 'Pierna', series: 4, repeticiones: 8, pesoKg: 60, descansoSeg: 120, alternativas: [2],
          ),
          EjercicioPropuesto(
            idEjercicio: 3, nombre: 'Levantamiento de garrafón', nombreOficial: 'Peso muerto rumano',
            grupoMuscular: 'Pierna', series: 3, repeticiones: 10, descansoSeg: 90,
          ),
        ]),
        for (var d = 2; d <= 7; d++) DiaPropuesto(diaSemana: d, nombre: 'Descanso', esDescanso: true),
      ],
    );
  }

  @override
  Future<String> guardar(PropuestaRutina propuesta,
      {required String fechaInicio, String? fechaFin, List<String> archivarAntes = const []}) async {
    guardada = propuesta;
    archivadosAlGuardar = archivarAntes;
    return 'nuevo';
  }
}

Future<void> _abrir(WidgetTester tester, _RutinaIaFalsa repo, ThemeData tema) async {
  tester.view.physicalSize = const Size(1200, 4200);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final rutas = GoRouter(initialLocation: '/ia', routes: [
    GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('INICIO'))),
    GoRoute(path: '/ia', builder: (_, _) => const PantallaRutinaIa()),
    GoRoute(path: '/perfil/ciclos/:id', builder: (_, s) => Scaffold(body: Text('CICLO ${s.pathParameters['id']}'))),
    GoRoute(path: '/perfil/editar', builder: (_, _) => const Scaffold(body: Text('EDITAR PERFIL'))),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [rutinaIaRepositorioProvider.overrideWith((ref) async => repo)],
    child: MaterialApp.router(theme: tema, routerConfig: rutas),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('es'));
  final temas = {'claro': TemaEntrenAndo.claro(), 'oscuro': TemaEntrenAndo.oscuro()};

  for (final entrada in temas.entries) {
    testWidgets('Editar la propuesta en memoria y guardar al confirmar (${entrada.key})', (tester) async {
      final repo = _RutinaIaFalsa();
      await _abrir(tester, repo, entrada.value);
      expect(find.text('TU SEMANA'), findsOneWidget);
      expect(find.text('Se quitaron 1 ejercicios que no están en el catálogo.'), findsOneWidget);
      expect(find.textContaining('Levantamiento de garrafón · 3 × 10'), findsOneWidget);

      // Criterio 2: quitar un ejercicio en el día, sin guardar nada todavía.
      await tester.tap(find.text('LUNES'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Levantamiento de garrafón').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quitar del día'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('LISTO'));
      await tester.pumpAndSettle();
      expect(repo.guardada, isNull);
      expect(find.textContaining('Levantamiento de garrafón'), findsNothing);

      // Criterio 3: al confirmar se guarda con su id_solicitud.
      await tester.ensureVisible(find.text('GUARDAR RUTINA'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GUARDAR RUTINA'));
      await tester.pumpAndSettle();
      expect(repo.guardada?.idSolicitud, 'sol-1');
      expect(repo.guardada?.dias.first.ejercicios.map((e) => e.idEjercicio), [1]);
      expect(find.text('CICLO nuevo'), findsOneWidget);
    });

    testWidgets('Con el plan Gratuito lleno manda a Premium sin archivar (${entrada.key})', (tester) async {
      final repo = _RutinaIaFalsa(activos: 1);
      await _abrir(tester, repo, entrada.value);
      await tester.ensureVisible(find.text('GUARDAR RUTINA'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GUARDAR RUTINA'));
      await tester.pumpAndSettle();
      expect(find.text('LÍMITE DE TU PLAN'), findsOneWidget);
      expect(find.text('Archivar «Ciclo demo»'), findsNothing);
      expect(find.text('Ver Premium'), findsOneWidget);
      expect(repo.guardada, isNull);
    });

    testWidgets('Sin perfil manda a completarlo (${entrada.key})', (tester) async {
      await _abrir(tester, _RutinaIaFalsa(error: const ErrorRutinaIa(MensajesRutinaIa.sinPerfil, irAPerfil: true)), entrada.value);
      expect(find.text(MensajesRutinaIa.sinPerfil), findsOneWidget);
      await tester.tap(find.text('COMPLETAR MI PERFIL'));
      await tester.pumpAndSettle();
      expect(find.text('EDITAR PERFIL'), findsOneWidget);
    });
  }
}
