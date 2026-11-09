import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/tema/modo_tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Nombres de días y meses en español para DateFormat (paquete intl).
  await initializeDateFormatting('es');
  // Modo claro u oscuro que eligió el usuario (Perfil → Ajustes → Tema).
  await ModoTema.cargar();
  runApp(const ProviderScope(child: EntrenAndoApp()));
}
