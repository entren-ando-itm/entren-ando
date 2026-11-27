import 'dart:io';

import 'package:entren_ando/app.dart';
import 'package:entren_ando/core/db/usuario_actual.dart';
import 'package:entren_ando/features/cuenta/cuenta_repositorio.dart';
import 'package:entren_ando/features/cuenta/pantalla_aviso.dart';
import 'package:entren_ando/features/cuenta/sesion_cuenta.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pruebas de las reglas de la cuenta (ENT-72). No necesitan emulador.
void main() {
  test('El nombre es obligatorio y corto', () {
    expect(ValidarCuenta.nombre(''), isNotNull);
    expect(ValidarCuenta.nombre('   '), isNotNull);
    expect(ValidarCuenta.nombre(null), isNotNull);
    expect(ValidarCuenta.nombre('x' * 61), isNotNull);
    expect(ValidarCuenta.nombre('Pablo'), isNull);
  });

  test('El correo necesita el formato nombre@correo.com', () {
    expect(ValidarCuenta.correo(''), isNotNull);
    expect(ValidarCuenta.correo('pablo'), isNotNull);
    expect(ValidarCuenta.correo('pablo@correo'), isNotNull);
    expect(ValidarCuenta.correo('pa blo@correo.com'), isNotNull);
    expect(ValidarCuenta.correo('demo@entrenando.test'), isNull);
    expect(ValidarCuenta.correo('  Demo@Entrenando.TEST  '), isNull);
  });

  test('El correo se guarda sin espacios y en minúsculas', () {
    expect(ValidarCuenta.limpiarCorreo('  Demo@Entrenando.TEST '), 'demo@entrenando.test');
    expect(ValidarCuenta.limpiarCorreo(null), '');
  });

  test('La contraseña nueva lleva al menos 8 caracteres', () {
    expect(ValidarCuenta.contrasenaNueva(''), isNotNull);
    expect(ValidarCuenta.contrasenaNueva('1234567'), isNotNull);
    expect(ValidarCuenta.contrasenaNueva('x' * 73), isNotNull);
    expect(ValidarCuenta.contrasenaNueva('12345678'), isNull);
  });

  test('Al iniciar sesión la contraseña solo no debe estar vacía', () {
    expect(ValidarCuenta.contrasena(''), isNotNull);
    expect(ValidarCuenta.contrasena(null), isNotNull);
    expect(ValidarCuenta.contrasena('abc'), isNull);
  });

  test('El mensaje de datos incorrectos no dice cuál de los dos falló', () {
    final mensaje = MensajesCuenta.datosIncorrectos.toLowerCase();
    expect(mensaje, contains('correo'));
    expect(mensaje, contains('contraseña'));
    expect(mensaje, isNot(contains('no existe')));
    expect(mensaje, isNot(contains('no está registrado')));
  });

  test('Eliminar cuenta: hay que escribir ELIMINAR (ENT-51)', () {
    expect(confirmaEliminar('ELIMINAR'), isTrue);
    expect(confirmaEliminar('  eliminar '), isTrue);
    expect(confirmaEliminar('Eliminar'), isTrue);
    expect(confirmaEliminar('ELIMINA'), isFalse);
    expect(confirmaEliminar('borrar'), isFalse);
    expect(confirmaEliminar(''), isFalse);
    expect(confirmaEliminar(null), isFalse);
    expect(MensajesCuenta.eliminarSinRed, contains('internet'));
  });

  group('Redirección según la sesión (ENT-41)', () {
    const sesion = SesionActual(idUsuario: 'u', correo: 'u@correo.com');

    test('Sin sesión manda al inicio de sesión', () {
      expect(redirigirSegunSesion(null, '/hoy'), '/entrar');
      expect(redirigirSegunSesion(null, '/perfil/cuenta'), '/entrar');
    });

    test('Sin sesión deja ver entrar, registro y el aviso', () {
      expect(redirigirSegunSesion(null, '/entrar'), isNull);
      expect(redirigirSegunSesion(null, '/registro'), isNull);
      expect(redirigirSegunSesion(null, '/aviso'), isNull);
    });

    test('Con sesión, entrar y registro mandan a Hoy', () {
      expect(redirigirSegunSesion(sesion, '/entrar'), '/hoy');
      expect(redirigirSegunSesion(sesion, '/registro'), '/hoy');
      expect(redirigirSegunSesion(sesion, '/comidas'), isNull);
      expect(redirigirSegunSesion(sesion, '/aviso'), isNull);
    });
  });

  group('Aviso de privacidad dentro de la app (ENT-42)', () {
    test('La copia de la app es igual a docs/aviso_privacidad.md', () {
      final app = File(rutaAviso).readAsStringSync();
      final docs = File('../docs/aviso_privacidad.md').readAsStringSync();
      expect(app, docs, reason: 'Copia de nuevo el aviso a assets/legal y sube Cuenta.versionAviso');
    });

    test('La versión aceptada es la del aviso', () {
      final aviso = File(rutaAviso).readAsStringSync();
      expect(aviso, contains('Versión ${Cuenta.versionAviso}'));
    });

    test('Se lee en títulos, párrafos y listas sin marcas de Markdown', () {
      final bloques = leerAviso(File(rutaAviso).readAsStringSync());
      expect(bloques.first.tipo, TipoBloque.titulo);
      expect(bloques.where((b) => b.tipo == TipoBloque.subtitulo).length, greaterThanOrEqualTo(6));
      expect(bloques.any((b) => b.tipo == TipoBloque.vineta), isTrue);
      expect(bloques.any((b) => b.tipo == TipoBloque.numero), isTrue);
      for (final bloque in bloques) {
        expect(bloque.texto, isNot(contains('**')), reason: bloque.texto);
        expect(bloque.texto, isNot(startsWith('#')), reason: bloque.texto);
      }
    });

    test('Una línea de lista que sigue en el renglón de abajo se une', () {
      final bloques = leerAviso('- Primera parte\n  y su final.\n\nOtro párrafo.');
      expect(bloques.map((b) => b.texto), ['Primera parte y su final.', 'Otro párrafo.']);
      expect(bloques.first.tipo, TipoBloque.vineta);
    });
  });
}
