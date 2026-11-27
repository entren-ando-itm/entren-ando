import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/db/base_datos.dart';
import '../../core/db/datos_prueba.dart';
import '../../core/db/escritura_local.dart';
import '../../core/db/fechas.dart';
import '../../core/db/usuario_actual.dart';
import '../nube/cliente_supabase.dart';
import 'cuenta_repositorio.dart';

/// Resultado de entrar, registrarse o pedir el cambio de contraseña.
class ResultadoCuenta {
  const ResultadoCuenta.bien({this.aviso}) : error = null;
  const ResultadoCuenta.mal(String this.error) : aviso = null;

  /// Mensaje de error para el usuario, o null si salió bien.
  final String? error;

  /// Mensaje informativo (por ejemplo "revisa tu correo"), si hay.
  final String? aviso;

  bool get bien => error == null;
}

/// Inicio de sesión, registro y cierre de sesión con Supabase Auth
/// (ENT-41, ENT-42 y ENT-43).
///
/// * La contraseña nunca se guarda en el celular: la sesión la guarda
///   `supabase_flutter`, así que después se entra sin internet (criterio 2).
/// * Usa el cliente de Ángel ([ClienteSupabase], ENT-44); no abre otro.
/// * Al entrar se asegura la fila local de `usuario` con el mismo id de Auth.
class Cuenta {
  Cuenta._();

  /// Versión del aviso de privacidad que se acepta al registrarse (ENT-42).
  /// Si cambia docs/aviso_privacidad.md, se sube aquí también.
  static const String versionAviso = '1.0';

  static const FlutterSecureStorage _almacen = FlutterSecureStorage();
  static const String _claveDemo = 'cuenta_modo_demo';

  static const SesionActual _sesionDemo = SesionActual(
    idUsuario: DatosPrueba.idUsuarioDemo,
    correo: DatosPrueba.correoDemo,
    esDemo: true,
  );

  /// Se llama una vez en `main.dart`, después de [ClienteSupabase.iniciar]:
  /// recupera la sesión guardada de Supabase o la del demo (solo debug).
  static Future<void> cargar() async {
    final usuario = ClienteSupabase.cliente?.auth.currentUser;
    if (usuario != null) {
      sesionActual.value = SesionActual(idUsuario: usuario.id, correo: usuario.email ?? '');
      return;
    }
    if (kDebugMode && await _leerDemo()) sesionActual.value = _sesionDemo;
  }

  /// Solo modo de prueba: entra con el usuario demo y sus datos de prueba, sin
  /// internet. Si hay Supabase y DEMO_PASSWORD en el .env, también abre su
  /// sesión en la nube para que se sincronice.
  static Future<void> entrarComoDemo() async {
    if (!kDebugMode) return;
    await _escribirDemo(true);
    bienvenida.value = '¡Hola! Entraste como usuario demo.';
    sesionActual.value = _sesionDemo;
    final cliente = ClienteSupabase.cliente;
    if (cliente == null || ClienteSupabase.contrasenaDemo.isEmpty) return;
    try {
      await cliente.auth.signInWithPassword(
        email: DatosPrueba.correoDemo,
        password: ClienteSupabase.contrasenaDemo,
      );
    } catch (e) {
      debugPrint('Entren-Ando: el demo entró sin la nube: $e');
    }
  }

  /// Mensaje de bienvenida que muestra la app al entrar (lo lee
  /// `EsqueletoPestanas` y lo limpia). null = no hay nada que mostrar.
  static final ValueNotifier<String?> bienvenida = ValueNotifier<String?>(null);

  static String _nombreDe(User usuario, String correo) {
    final nombre = usuario.userMetadata?['nombre'];
    return nombre is String && nombre.trim().isNotEmpty ? nombre.trim() : correo.split('@').first;
  }

  /// Errores de Supabase Auth que no son "datos incorrectos".
  static String? _errorConocido(AuthException e) {
    if (e.code == 'email_address_invalid') return MensajesCuenta.correoInvalido;
    if (e.statusCode == '429' || (e.code ?? '').contains('rate_limit')) return MensajesCuenta.demasiadosIntentos;
    return null;
  }

  static Future<ResultadoCuenta> iniciarSesion(String correo, String contrasena) async {
    final cliente = ClienteSupabase.cliente;
    if (cliente == null) return const ResultadoCuenta.mal(MensajesCuenta.sinSupabase);
    final limpio = ValidarCuenta.limpiarCorreo(correo);
    try {
      final respuesta = await cliente.auth.signInWithPassword(email: limpio, password: contrasena);
      final usuario = respuesta.user;
      if (usuario == null) return const ResultadoCuenta.mal(MensajesCuenta.datosIncorrectos);
      await _asegurarUsuarioLocal(usuario);
      await _escribirDemo(false);
      bienvenida.value = '¡Hola de nuevo, ${_nombreDe(usuario, limpio)}!';
      sesionActual.value = SesionActual(idUsuario: usuario.id, correo: usuario.email ?? limpio);
      return const ResultadoCuenta.bien();
    } on AuthRetryableFetchException {
      return const ResultadoCuenta.mal(MensajesCuenta.errorGeneral);
    } on AuthException catch (e) {
      if (_errorConocido(e) case final conocido?) return ResultadoCuenta.mal(conocido);
      if (e.message.toLowerCase().contains('not confirmed')) {
        return const ResultadoCuenta.mal(MensajesCuenta.correoSinConfirmar);
      }
      // Criterio 4: el mismo mensaje si el correo no existe o la contraseña está mal.
      return const ResultadoCuenta.mal(MensajesCuenta.datosIncorrectos);
    } catch (e) {
      debugPrint('Entren-Ando: error al iniciar sesión: $e');
      return const ResultadoCuenta.mal(MensajesCuenta.errorGeneral);
    }
  }

  /// Crea la cuenta en Supabase Auth con el plan Gratuito y guarda en su
  /// user_metadata la versión y la fecha del aviso aceptado (ENT-42, ENT-76).
  static Future<ResultadoCuenta> registrarse({
    required String nombre,
    required String correo,
    required String contrasena,
  }) async {
    final cliente = ClienteSupabase.cliente;
    if (cliente == null) return const ResultadoCuenta.mal(MensajesCuenta.sinSupabase);
    final limpio = ValidarCuenta.limpiarCorreo(correo);
    final nombreLimpio = nombre.trim();
    try {
      final respuesta = await cliente.auth.signUp(
        email: limpio,
        password: contrasena,
        data: {
          'nombre': nombreLimpio,
          'aviso_version': versionAviso,
          'aviso_aceptado_en': Fechas.ahoraIso(),
        },
      );
      final usuario = respuesta.user;
      if (usuario == null) return const ResultadoCuenta.mal(MensajesCuenta.errorGeneral);
      // Con la confirmación de correo encendida en Supabase no hay sesión todavía.
      if (respuesta.session == null) {
        return const ResultadoCuenta.bien(aviso: MensajesCuenta.confirmaTuCorreo);
      }
      await _asegurarUsuarioLocal(usuario, nombre: nombreLimpio);
      await _escribirDemo(false);
      bienvenida.value = '¡Bienvenido a Entren-Ando, $nombreLimpio! Tu cuenta está lista.';
      sesionActual.value = SesionActual(idUsuario: usuario.id, correo: usuario.email ?? limpio);
      return const ResultadoCuenta.bien();
    } on AuthRetryableFetchException {
      return const ResultadoCuenta.mal(MensajesCuenta.errorGeneral);
    } on AuthException catch (e) {
      if (_errorConocido(e) case final conocido?) return ResultadoCuenta.mal(conocido);
      final mensaje = e.message.toLowerCase();
      if (mensaje.contains('already')) return const ResultadoCuenta.mal(MensajesCuenta.correoEnUso);
      if (mensaje.contains('password')) return const ResultadoCuenta.mal(MensajesCuenta.contrasenaDebil);
      debugPrint('Entren-Ando: error al registrarse: ${e.message}');
      return const ResultadoCuenta.mal(MensajesCuenta.errorGeneral);
    } catch (e) {
      debugPrint('Entren-Ando: error al registrarse: $e');
      return const ResultadoCuenta.mal(MensajesCuenta.errorGeneral);
    }
  }

  /// Envía el correo para cambiar la contraseña (ENT-74). La respuesta es la
  /// misma exista o no la cuenta.
  static Future<ResultadoCuenta> recuperarContrasena(String correo) async {
    final cliente = ClienteSupabase.cliente;
    if (cliente == null) return const ResultadoCuenta.mal(MensajesCuenta.sinSupabase);
    try {
      await cliente.auth.resetPasswordForEmail(ValidarCuenta.limpiarCorreo(correo));
      return const ResultadoCuenta.bien(aviso: MensajesCuenta.revisaTuCorreo);
    } on AuthRetryableFetchException {
      return const ResultadoCuenta.mal(MensajesCuenta.errorGeneral);
    } catch (e) {
      debugPrint('Entren-Ando: error al pedir el cambio de contraseña: $e');
      // Mismo mensaje que si salió bien, para no revelar si el correo existe.
      return const ResultadoCuenta.bien(aviso: MensajesCuenta.revisaTuCorreo);
    }
  }

  /// Cierra la sesión (ENT-43). Los datos se quedan en el celular: se
  /// borrarán al salir cuando exista la bajada desde la nube (ENT-53).
  static Future<void> cerrarSesion() async {
    final cliente = ClienteSupabase.cliente;
    if (cliente != null && cliente.auth.currentSession != null) {
      try {
        await cliente.auth.signOut();
      } catch (e) {
        debugPrint('Entren-Ando: la sesión se cerró solo en el celular: $e');
      }
    }
    await _escribirDemo(false);
    sesionActual.value = null;
  }

  /// La fila del usuario en la base local, con el mismo id de Auth. Si ya
  /// existe (por ejemplo, entró antes en este celular), no la toca.
  static Future<void> _asegurarUsuarioLocal(User usuario, {String? nombre}) async {
    final bd = await BaseDatos.instancia();
    final filas = await bd.rawQuery('SELECT 1 FROM usuario WHERE id_usuario = ?', [usuario.id]);
    if (filas.isNotEmpty) return;
    final correo = usuario.email ?? '';
    final nombreGuardado = usuario.userMetadata?['nombre'];
    await EscrituraLocal(bd).insertar('usuario', {
      'id_usuario': usuario.id,
      'correo': correo,
      'nombre': nombre ?? (nombreGuardado is String && nombreGuardado.isNotEmpty ? nombreGuardado : correo.split('@').first),
      'id_plan': 1,
      'fecha_registro': Fechas.ahoraIso(),
    });
  }

  static Future<bool> _leerDemo() async {
    try {
      return await _almacen.read(key: _claveDemo) == '1';
    } catch (_) {
      return false;
    }
  }

  static Future<void> _escribirDemo(bool activo) async {
    try {
      if (activo) {
        await _almacen.write(key: _claveDemo, value: '1');
      } else {
        await _almacen.delete(key: _claveDemo);
      }
    } catch (_) {
      // Si no se puede guardar, el demo solo dura mientras la app está abierta.
    }
  }
}
