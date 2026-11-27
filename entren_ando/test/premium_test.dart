import 'dart:async';

import 'package:entren_ando/core/conectividad/conectividad.dart';
import 'package:entren_ando/core/diseno.dart';
import 'package:entren_ando/features/cuenta/pantalla_premium.dart';
import 'package:entren_ando/features/cuenta/premium.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Red extends DetectorRed {
  _Red(this.disponible);
  final bool disponible;
  @override
  bool build() => disponible;
}

void main() {
  const gratis = (ciclos: 1, escaneos: 3, frecuencia: 'mensual', precio: 0);
  const premium = (ciclos: null, escaneos: null, frecuencia: 'semanal', precio: 59);
  for (final conRed in [false, true]) {
    testWidgets('Premium con catálogo local y red $conRed', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final respuesta = Completer<void>();
      var llamadas = 0;
      var activo = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hayRedProvider.overrideWith(() => _Red(conRed)),
            comparacionPlanesProvider.overrideWith(
              (ref) async => (gratuito: gratis, premium: premium, activo: activo),
            ),
            activarPremiumProvider.overrideWith(
              (ref) => () async {
                llamadas++;
                await respuesta.future;
                activo = true;
                ref.invalidate(comparacionPlanesProvider);
              },
            ),
          ],
          child: MaterialApp(
            theme: conRed ? TemaEntrenAndo.claro() : TemaEntrenAndo.oscuro(),
            home: const PantallaPremium(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sin límite'), findsNWidgets(2));
      expect(find.text('3 al día'), findsOneWidget);
      expect(find.text('Semanal'), findsOneWidget);
      final boton = find.byType(BotonPrincipal);
      await tester.ensureVisible(boton);
      if (conRed) {
        await tester.tap(boton);
        await tester.pump();
        expect(tester.widget<BotonPrincipal>(boton).alPresionar, isNull);
        expect(find.text('Tu plan Premium está activo.'), findsNothing);
        respuesta.complete();
        await tester.pumpAndSettle();
        expect(find.text('Tu plan Premium está activo.'), findsOneWidget);
        expect(llamadas, 1);
      } else {
        expect(tester.widget<BotonPrincipal>(boton).alPresionar, isNull);
        expect(find.textContaining('Conéctate para activar'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
