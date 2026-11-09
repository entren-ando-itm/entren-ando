import 'package:entren_ando/core/componentes/galeria_componentes.dart';
import 'package:entren_ando/core/diseno.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pruebas del diseño (no necesitan emulador):
///   flutter test
///
/// La galería dibuja todos los componentes; si alguno se sale de su espacio
/// o truena, la prueba falla.
void main() {
  final temas = {
    'claro': TemaEntrenAndo.claro(),
    'oscuro': TemaEntrenAndo.oscuro(),
  };

  for (final entrada in temas.entries) {
    testWidgets('La galería de componentes se dibuja sin errores en modo ${entrada.key}',
        (tester) async {
      // Pantalla alta para que se dibuje toda la galería de una vez.
      tester.view.physicalSize = const Size(2400, 30000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(theme: entrada.value, home: const GaleriaComponentes()));
      await tester.pump();
      expect(find.text('COMPONENTES'), findsOneWidget);

      await tester.tap(find.text('ABRIR HOJA DE EJEMPLO'));
      await tester.pumpAndSettle();
      expect(find.text('Completo'), findsWidgets);
      expect(find.text('CANCELAR'), findsNothing);
      expect(find.text('Cancelar'), findsOneWidget);
    });
  }

  test('Los colores del tema son los del lienzo', () {
    final claro = TemaEntrenAndo.claro();
    final oscuro = TemaEntrenAndo.oscuro();
    expect(claro.extension<ColoresEntrenAndo>()?.fondo, const Color(0xFFE8E6E2));
    expect(oscuro.extension<ColoresEntrenAndo>()?.fondo, const Color(0xFF121212));
    expect(claro.scaffoldBackgroundColor, const Color(0xFFE8E6E2));
    expect(claro.colorScheme.primary, const Color(0xFF1A1A1A));
    expect(oscuro.colorScheme.primary, const Color(0xFFF1EFEB));
  });

  test('Estados del semáforo desde la base', () {
    expect(EstadoDia.deSesion('completa'), EstadoDia.completo);
    expect(EstadoDia.deSesion('parcial'), EstadoDia.parcial);
    expect(EstadoDia.deSesion('descanso'), EstadoDia.descanso);
    expect(EstadoDia.deSesion(null), EstadoDia.sinActividad);
    expect(ColoresSemaforo.nombreDeEstado(null), 'Sin actividad');
  });

  test('Iniciales del avatar', () {
    expect(AvatarIniciales.iniciales('Usuario Demo'), 'UD');
    expect(AvatarIniciales.iniciales('  paola  '), 'P');
    expect(AvatarIniciales.iniciales(''), '?');
  });
}
