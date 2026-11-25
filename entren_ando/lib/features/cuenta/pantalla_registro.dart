import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/conectividad/conectividad.dart';
import '../../core/diseno.dart';
import 'cuenta_repositorio.dart';
import 'pantalla_inicio_sesion.dart';
import 'sesion_cuenta.dart';

/// Crear cuenta (ENT-41 y ENT-42). Se arma con las piezas del inicio de
/// sesión (docs/pantallas/01_inicio_sesion.png). El botón queda desactivado
/// hasta aceptar el aviso de privacidad, y sin internet.
class PantallaRegistro extends ConsumerStatefulWidget {
  const PantallaRegistro({super.key});

  @override
  ConsumerState<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends ConsumerState<PantallaRegistro> {
  final _formulario = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();
  bool _acepto = false;
  bool _cargando = false;
  String? _error;
  String? _aviso;

  @override
  void dispose() {
    _nombre.dispose();
    _correo.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    if (_cargando || !_acepto || !(_formulario.currentState?.validate() ?? false)) return;
    setState(() {
      _cargando = true;
      _error = null;
      _aviso = null;
    });
    final resultado = await Cuenta.registrarse(
      nombre: _nombre.text,
      correo: _correo.text,
      contrasena: _contrasena.text,
    );
    if (!mounted) return;
    setState(() {
      _cargando = false;
      _error = resultado.error;
      _aviso = resultado.aviso;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hayRed = ref.watch(hayRedProvider);
    final error = _error;
    final aviso = _aviso;

    return Scaffold(
      body: Form(
        key: _formulario,
        child: AutofillGroup(
          child: ContenidoPantalla(
            arriba: Medidas.espacio6 * 2,
            children: [
              const EncabezadoPantalla(
                etiqueta: 'Entren-Ando',
                titulo: 'Crear cuenta',
                subtitulo: 'Solo necesitas internet esta vez; después la app funciona sin red.',
              ),
              const SizedBox(height: Medidas.espacio6),
              CampoTexto(
                etiqueta: 'Nombre',
                controlador: _nombre,
                teclado: TextInputType.name,
                accionTeclado: TextInputAction.next,
                validar: ValidarCuenta.nombre,
                autocompletar: const [AutofillHints.name],
                habilitado: !_cargando,
              ),
              const SizedBox(height: Medidas.espacio4),
              CampoTexto(
                etiqueta: 'Correo',
                controlador: _correo,
                teclado: TextInputType.emailAddress,
                accionTeclado: TextInputAction.next,
                validar: ValidarCuenta.correo,
                autocompletar: const [AutofillHints.email],
                habilitado: !_cargando,
              ),
              const SizedBox(height: Medidas.espacio4),
              CampoTexto(
                etiqueta: 'Contraseña',
                pista: 'Al menos ${ValidarCuenta.minContrasena} caracteres',
                controlador: _contrasena,
                esContrasena: true,
                accionTeclado: TextInputAction.done,
                validar: ValidarCuenta.contrasenaNueva,
                autocompletar: const [AutofillHints.newPassword],
                habilitado: !_cargando,
              ),
              const SizedBox(height: Medidas.espacio4),
              Casilla(
                valor: _acepto,
                alCambiar: _cargando ? null : (valor) => setState(() => _acepto = valor),
                etiqueta: const Text('Acepto el aviso de privacidad y el tratamiento de mis datos de salud'),
              ),
              BotonTexto(
                texto: 'Leer el aviso de privacidad',
                icono: Icons.description_outlined,
                anchoCompleto: true,
                alPresionar: () => context.push('/aviso'),
              ),
              if (error != null) ...[
                const SizedBox(height: Medidas.espacio4),
                Aviso(error, icono: Icons.error_outline_rounded),
              ],
              if (aviso != null) ...[
                const SizedBox(height: Medidas.espacio4),
                Aviso(aviso, icono: Icons.mark_email_read_outlined),
              ],
              const SizedBox(height: Medidas.espacio4),
              BotonPrincipal(
                texto: _cargando ? 'Creando…' : 'Crear cuenta',
                grande: true,
                alPresionar: hayRed && _acepto && !_cargando ? _crear : null,
              ),
              if (!hayRed) ...[
                const SizedBox(height: Medidas.espacio4),
                const Aviso.sinRed(MensajesCuenta.sinRedRegistro),
              ],
              const SizedBox(height: Medidas.espacio4),
              BotonTexto(
                texto: 'Ya tengo cuenta',
                anchoCompleto: true,
                alPresionar: _cargando ? null : () => context.go('/entrar'),
              ),
              const SizedBox(height: Medidas.espacio5),
              const NotaCifrado(),
            ],
          ),
        ),
      ),
    );
  }
}
