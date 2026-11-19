import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/tema/modo_tema.dart';
import 'features/cuenta/sesion_cuenta.dart';
import 'features/nube/cliente_supabase.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Nombres de días y meses en español para DateFormat (paquete intl).
  await initializeDateFormatting('es');
  // Modo claro u oscuro que eligió el usuario (Perfil → Ajustes → Tema).
  await ModoTema.cargar();
  // Conexión con Supabase para respaldar en la nube (ENT-44). Sin el archivo
  // .env la app funciona igual, sin sincronizar.
  await ClienteSupabase.iniciar();
  // Sesión guardada: si ya entraste antes, abre directo en Hoy, aun sin
  // internet (ENT-41).
  await Cuenta.cargar();
  runApp(const ProviderScope(child: EntrenAndoApp()));
}
