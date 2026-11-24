import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/sync/segundo_plano.dart';
import 'core/tema/modo_tema.dart';
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
  // Sincronización cada 15 minutos con red, aunque la app esté cerrada (ENT-53).
  await SegundoPlano.programar();
  runApp(const ProviderScope(child: EntrenAndoApp()));
}
