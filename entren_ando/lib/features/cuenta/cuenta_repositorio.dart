/// Reglas para crear la cuenta e iniciar sesión (ENT-41 / ENT-72).
///
/// Cada validación devuelve el mensaje de error para mostrar debajo del campo,
/// o null si está bien. Se usan en `CampoTexto(validar: ...)`.
class ValidarCuenta {
  ValidarCuenta._();

  /// ENT-41: la contraseña lleva al menos 8 caracteres (lo mismo que pide
  /// Supabase Auth por defecto).
  static const int minContrasena = 8;

  /// Supabase no acepta contraseñas de más de 72 caracteres.
  static const int maxContrasena = 72;

  static const int maxNombre = 60;
  static const int maxCorreo = 254;

  /// Algo@algo.algo, sin espacios. No intenta cubrir todos los casos raros:
  /// Supabase revisa el correo de verdad al crear la cuenta.
  static final RegExp _formatoCorreo = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static String? nombre(String? texto) {
    final limpio = texto?.trim() ?? '';
    if (limpio.isEmpty) return 'Escribe tu nombre';
    if (limpio.length > maxNombre) return 'Máximo $maxNombre letras';
    return null;
  }

  static String? correo(String? texto) {
    final limpio = limpiarCorreo(texto);
    if (limpio.isEmpty) return 'Escribe tu correo';
    if (limpio.length > maxCorreo || !_formatoCorreo.hasMatch(limpio)) {
      return 'Revisa tu correo, por ejemplo nombre@correo.com';
    }
    return null;
  }

  /// Para crear la cuenta: al menos [minContrasena] caracteres.
  static String? contrasenaNueva(String? texto) {
    final valor = texto ?? '';
    if (valor.isEmpty) return 'Escribe una contraseña';
    if (valor.length < minContrasena) return 'Usa al menos $minContrasena caracteres';
    if (valor.length > maxContrasena) return 'Máximo $maxContrasena caracteres';
    return null;
  }

  /// Para iniciar sesión solo se pide que no esté vacía: el largo lo revisa
  /// Supabase, y así no se le dice a nadie qué reglas tiene la cuenta.
  static String? contrasena(String? texto) {
    if ((texto ?? '').isEmpty) return 'Escribe tu contraseña';
    return null;
  }

  /// Sin espacios a los lados y en minúsculas, como lo guarda Supabase.
  static String limpiarCorreo(String? texto) => (texto ?? '').trim().toLowerCase();
}

/// Mensajes que ve el usuario cuando algo sale mal al entrar o registrarse.
///
/// Criterio 4 de ENT-41: si el correo o la contraseña están mal, el mensaje es
/// el mismo en los dos casos, para no revelar si un correo tiene cuenta.
/// Palabra que hay que escribir para eliminar la cuenta (ENT-51 criterio 1).
const String palabraEliminar = 'ELIMINAR';

/// true si el texto confirma el borrado (sin espacios a los lados y sin
/// importar mayúsculas, porque el teclado del celular las cambia solo).
bool confirmaEliminar(String? texto) => (texto ?? '').trim().toUpperCase() == palabraEliminar;

class MensajesCuenta {
  MensajesCuenta._();

  static const String datosIncorrectos = 'El correo o la contraseña no son correctos.';
  static const String sinRedEntrar =
      'Sin conexión. Para entrar la primera vez necesitas internet; después la app funciona sin red.';
  static const String sinRedRegistro =
      'Sin conexión. Necesitas internet solo para crear tu cuenta; después la app funciona sin red.';
  static const String errorGeneral = 'No se pudo conectar. Revisa tu internet e intenta otra vez.';
  static const String sinSupabase =
      'Falta conectar la app con Supabase (archivo .env). En modo de prueba puedes entrar como demo.';
  static const String correoSinConfirmar =
      'Confirma tu correo con el enlace que te enviamos y vuelve a intentar.';
  static const String confirmaTuCorreo =
      'Te enviamos un correo para confirmar tu cuenta. Después inicia sesión.';
  static const String correoEnUso = 'No se pudo crear la cuenta con ese correo. Si ya tienes una, inicia sesión.';
  static const String contrasenaDebil = 'Esa contraseña no se puede usar. Prueba con una más larga.';
  static const String eliminarSinRed =
      'Necesita internet. Tu cuenta y tus datos siguen guardados; vuelve a intentarlo con conexión.';
  static const String eliminarDemo = 'El usuario demo no se puede eliminar. Entra con una cuenta de prueba.';
  static const String eliminarError = 'No se pudo eliminar tu cuenta. No se borró nada; intenta de nuevo.';
  static const String correoInvalido = 'Ese correo no es válido. Revisa que esté bien escrito.';
  static const String demasiadosIntentos =
      'Hiciste muchos intentos seguidos. Espera unos minutos y vuelve a intentar.';
  static const String revisaTuCorreo =
      'Si el correo tiene cuenta, te llegará un enlace para cambiar la contraseña.';
}
