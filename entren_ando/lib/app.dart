import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/componentes/galeria_componentes.dart';
import 'core/diseno.dart';
import 'features/calendario/pantalla_calendario.dart';
import 'features/entrenamiento/pantalla_hoy.dart';
import 'features/nutricion/pantalla_comidas.dart';
import 'features/perfil/catalogo/pantalla_catalogo.dart';
import 'features/perfil/pantalla_perfil.dart';

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
final GoRouter rutas = GoRouter(
  navigatorKey: navegadorRaiz,
  initialLocation: '/hoy',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navegacion) => EsqueletoPestanas(navegacion: navegacion),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/hoy', builder: (context, state) => const PantallaHoy()),
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
              // Solo en modo de prueba: galería con todos los componentes.
              if (kDebugMode)
                GoRoute(
                  path: 'componentes',
                  parentNavigatorKey: navegadorRaiz,
                  builder: (context, state) => const GaleriaComponentes(),
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
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: TemaEntrenAndo.barraDelSistema(Theme.of(context).brightness),
        child: child ?? const SizedBox.shrink(),
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
