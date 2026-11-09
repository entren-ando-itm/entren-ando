import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'datos_prueba.dart';

/// id del usuario que usa la app.
///
/// Mientras no exista el inicio de sesión (ENT-41), en modo debug es el
/// usuario demo y en la app final es null. ENT-41 cambia este proveedor para
/// que devuelva el usuario que inició sesión; las pantallas no cambian.
final usuarioActualIdProvider = Provider<String?>(
  (ref) => kDebugMode ? DatosPrueba.idUsuarioDemo : null,
);
