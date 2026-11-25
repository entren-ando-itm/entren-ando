import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/componentes/galeria_componentes.dart';
import 'core/conectividad/aviso_sin_red.dart';
import 'core/db/usuario_actual.dart';
import 'core/diseno.dart';
import 'core/sync/sincronizacion.dart';
import 'features/calendario/pantalla_calendario.dart';
import 'features/cuenta/pantalla_aviso.dart';
import 'features/cuenta/pantalla_cuenta.dart';
import 'features/cuenta/pantalla_inicio_sesion.dart';
import 'features/cuenta/pantalla_registro.dart';
import 'features/entrenamiento/bitacora/pantalla_ejercicio.dart';
import 'features/entrenamiento/pantalla_hoy.dart';
import 'features/nube/pantalla_nube_prueba.dart';
import 'features/nutricion/pantalla_comidas.dart';
import 'features/perfil/catalogo/pantalla_catalogo.dart';
import 'features/perfil/pantalla_editar_perfil.dart';
import 'features/perfil/pantalla_equipo.dart';
import 'features/perfil/pantalla_mediciones.dart';
import 'features/perfil/pantalla_perfil.dart';
import 'features/rutinas/alternativas/pantalla_alternativas.dart';
import 'features/rutinas/pantalla_ciclo.dart';
import 'features/rutinas/pantalla_ciclos.dart';
import 'features/rutinas/pantalla_editor_dia.dart';

/// Navegador de toda la app.
///
/// Las pantallas que se ven sin la barra de abajo (Ejercicio, Premium, inicio
/// de sesión...) van como rutas hijas de su pestaña con
/// `parentNavigatorKey: navegadorRaiz`, por ejemplo:
///   GoRoute(path: 'ejercicio', parentNavigatorKey: navegadorRaiz, builder: ...)
final GlobalKey<NavigatorState> navegadorRaiz = GlobalKey<NavigatorState>(debugLabel: 'raiz');

/// Rutas de la app con go_router.
///
/// Cada pestaña es una rama con su propia pila de pantallas. Para agregar una
/// pantalla de tu módulo, agrega un GoRoute hijo dentro de la rama de tu
/// pestaña (por ejemplo, '/hoy/bitacora').
/// Sin sesión solo se puede estar en estas rutas (ENT-41).
const Set<String> rutasSinSesion = {'/entrar', '/registro', '/aviso'};

/// Manda al inicio de sesión si nadie ha entrado, y a Hoy al entrar.
String? redirigirSegunSesion(SesionActual? sesion, String ubicacion) {
  if (sesion == null) return rutasSinSesion.contains(ubicacion) ? null : '/entrar';
  if (ubicacion == '/entrar' || ubicacion == '/registro') return '/hoy';
  return null;
}

final GoRouter rutas = GoRouter(
  navigatorKey: navegadorRaiz,
  initialLocation: '/hoy',
  // Vuelve a revisar la ruta cada vez que cambia la sesión (entrar o salir).
  refreshListenable: sesionActual,
  redirect: (context, state) => redirigirSegunSesion(sesionActual.value, state.matchedLocation),
  routes: [
    // ENT-41 y ENT-42: cuenta, sin la barra de abajo.
    GoRoute(path: '/entrar', builder: (context, state) => const PantallaInicioSesion()),
    GoRoute(path: '/registro', builder: (context, state) => const PantallaRegistro()),
    GoRoute(path: '/aviso', builder: (context, state) => const PantallaAviso()),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navegacion) => EsqueletoPestanas(navegacion: navegacion),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/hoy',
            builder: (context, state) => const PantallaHoy(),
            routes: [
              // ENT-49: bitácora del ejercicio (sin la barra de abajo).
              GoRoute(
                path: 'ejercicio/:idProgramado',
                parentNavigatorKey: navegadorRaiz,
                builder: (context, state) =>
                    PantallaEjercicio(idProgramado: state.pathParameters['idProgramado']!),
              ),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/calendario', builder: (context, state) => const PantallaCalendario()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/comidas', builder: (context, state) => const PantallaComidas()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/perfil',
            builder: (context, state) => const PantallaPerfil(),
            routes: [
              // ENT-17: catálogo de ejercicios con alias (sin la barra de abajo).
              GoRoute(
                path: 'catalogo',
                parentNavigatorKey: navegadorRaiz,
                builder: (context, state) => const PantallaCatalogo(),
              ),
              // ENT-18: perfil, mediciones y equipo (sin la barra de abajo).
              GoRoute(
                path: 'editar',
                parentNavigatorKey: navegadorRaiz,
                builder: (context, state) => const PantallaEditarPerfil(),
              ),
              GoRoute(
                path: 'mediciones',
                parentNavigatorKey: navegadorRaiz,
                builder: (context, state) => const PantallaMediciones(),
              ),
              GoRoute(
                path: 'equipo',
                parentNavigatorKey: navegadorRaiz,
                builder: (context, state) => const PantallaEquipo(),
              ),
              // ENT-47: ciclos de rutina, sus 7 días y el editor de cada día (sin la barra).
              GoRoute(
                path: 'ciclos',
                parentNavigatorKey: navegadorRaiz,
                builder: (context, state) => const PantallaCiclos(),
                routes: [
                  GoRoute(
                    path: ':idCiclo',
                    parentNavigatorKey: navegadorRaiz,
                    builder: (context, state) => PantallaCiclo(idCiclo: state.pathParameters['idCiclo']!),
                    routes: [
                      GoRoute(
                        path: 'dia/:idDia',
                        parentNavigatorKey: navegadorRaiz,
                        builder: (context, state) => PantallaEditorDia(
                          idCiclo: state.pathParameters['idCiclo']!,
                          idDia: state.pathParameters['idDia']!,
                        ),
                        routes: [
                          // ENT-48: alternativas de un ejercicio programado.
                          GoRoute(
                            path: 'alternativas/:idProgramado',
                            parentNavigatorKey: navegadorRaiz,
                            builder: (context, state) =>
                                PantallaAlternativas(idProgramado: state.pathParameters['idProgramado']!),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              // ENT-43: cuenta, aviso de privacidad y cerrar sesión (sin la barra).
              GoRoute(
                path: 'cuenta',
                parentNavigatorKey: navegadorRaiz,
                builder: (context, state) => const PantallaCuenta(),
              ),
              // Solo en modo de prueba: galería con todos los componentes.
              if (kDebugMode)
                GoRoute(
                  path: 'componentes',
                  parentNavigatorKey: navegadorRaiz,
                  builder: (context, state) => const GaleriaComponentes(),
                ),
              // Solo en modo de prueba: sesión del demo en Supabase y sincronizar
              // a mano (ENT-44).
              if (kDebugMode)
                GoRoute(
                  path: 'nube',
                  parentNavigatorKey: navegadorRaiz,
                  builder: (context, state) => const PantallaNubePrueba(),
                ),
            ],
          ),
        ]),
      ],
    ),
  ],
);

class EntrenAndoApp extends ConsumerWidget {
  const EntrenAndoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Entren-Ando',
      debugShowCheckedModeBanner: false,
      theme: TemaEntrenAndo.claro(),
      darkTheme: TemaEntrenAndo.oscuro(),
      themeMode: ref.watch(modoTemaProvider),
      routerConfig: rutas,
      // Íconos de la barra de estado oscuros en modo claro y claros en oscuro.
      // AvisoSinRed muestra la banda "Sin conexión" arriba de todas las
      // pantallas (ENT-14) y SincronizacionAutomatica sube los pendientes al
      // abrir la app y al volver la red (ENT-44).
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: TemaEntrenAndo.barraDelSistema(Theme.of(context).brightness),
        child: AvisoSinRed(
          child: SincronizacionAutomatica(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
  }
}

/// Las 4 pestañas (Hoy, Calendario, Comidas y Perfil) con la barra en forma
/// de píldora que flota sobre el contenido.
class EsqueletoPestanas extends StatelessWidget {
  const EsqueletoPestanas({super.key, required this.navegacion});

  final StatefulNavigationShell navegacion;

  static const List<DestinoBarra> _destinos = [
    DestinoBarra(icono: IconoPestana.hoy, etiqueta: 'Hoy'),
    DestinoBarra(icono: IconoPestana.calendario, etiqueta: 'Calendario'),
    DestinoBarra(icono: IconoPestana.comidas, etiqueta: 'Comidas'),
    DestinoBarra(icono: IconoPestana.perfil, etiqueta: 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: navegacion,
      bottomNavigationBar: BarraNavegacion(
        destinos: _destinos,
        indice: navegacion.currentIndex,
        alCambiar: (indice) => navegacion.goBranch(
          indice,
          initialLocation: indice == navegacion.currentIndex,
        ),
      ),
    );
  }
}
