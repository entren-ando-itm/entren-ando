import 'package:entren_ando/features/cuenta/cuenta_repositorio.dart';
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
}
