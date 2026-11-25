import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/conectividad/conectividad.dart';
import '../../core/diseno.dart';
import 'cuenta_repositorio.dart';
import 'sesion_cuenta.dart';

/// Inicio de sesión (ENT-41, diseño docs/pantallas/01_inicio_sesion.png y
/// 09_inicio_sesion_sin_red.png). Al entrar, go_router manda solo a Hoy.
class PantallaInicioSesion extends ConsumerStatefulWidget {
  const PantallaInicioSesion({super.key});

  @override
  ConsumerState<PantallaInicioSesion> createState() => _PantallaInicioSesionState();
}

class _PantallaInicioSesionState extends ConsumerState<PantallaInicioSesion> {
  final _formulario = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();
  bool _cargando = false;
  String? _error;
  String? _aviso;

  @override
  void dispose() {
    _correo.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (_cargando || !(_formulario.currentState?.validate() ?? false)) return;
    setState(() {
      _cargando = true;
      _error = null;
      _aviso = null;
    });
    final resultado = await Cuenta.iniciarSesion(_correo.text, _contrasena.text);
    if (!mounted) return;
    setState(() {
      _cargando = false;
      _error = resultado.error;
      _aviso = resultado.aviso;
    });
  }

  Future<void> _recuperar() async {
    final error = ValidarCuenta.correo(_correo.text);
    if (error != null) {
      setState(() => _error = 'Escribe tu correo arriba para mandarte el enlace.');
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
      _aviso = null;
    });
    final resultado = await Cuenta.recuperarContrasena(_correo.text);
    if (!mounted) return;
    setState(() {
      _cargando = false;
      _error = resultado.error;
      _aviso = resultado.aviso;
    });
  }

  Future<void> _entrarComoDemo() async {
    setState(() => _cargando = true);
    await Cuenta.entrarComoDemo();
    if (mounted) setState(() => _cargando = false);
  }

  @override
  Widget build(BuildContext context) {
    final hayRed = ref.watch(hayRedProvider);
    final textos = Theme.of(context).textTheme;
    final error = _error;
    final aviso = _aviso;

    return Scaffold(
      body: Form(
        key: _formulario,
        child: AutofillGroup(
          child: ContenidoPantalla(
            arriba: Medidas.espacio6 * 2,
            children: [
              EncabezadoPantalla(
                titulo: 'Entren-Ando',
                subtitulo: 'Tu entrenamiento, aunque en el gimnasio no haya señal.',
                estiloTitulo: textos.displaySmall,
              ),
              const SizedBox(height: Medidas.espacio6 * 3),
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
                controlador: _contrasena,
                esContrasena: true,
                accionTeclado: TextInputAction.done,
                validar: ValidarCuenta.contrasena,
                alEnviar: (_) => _entrar(),
                autocompletar: const [AutofillHints.password],
                habilitado: !_cargando,
              ),
              if (error != null) ...[
                const SizedBox(height: Medidas.espacio4),
                Aviso(error, icono: Icons.error_outline_rounded),
              ],
              if (aviso != null) ...[
                const SizedBox(height: Medidas.espacio4),
                Aviso(aviso, icono: Icons.mark_email_read_outlined),
              ],
              const SizedBox(height: Medidas.espacio5),
              BotonPrincipal(
                texto: _cargando ? 'Entrando…' : 'Entrar',
                grande: true,
                alPresionar: hayRed && !_cargando ? _entrar : null,
              ),
              if (!hayRed) ...[
                const SizedBox(height: Medidas.espacio4),
                const Aviso.sinRed(MensajesCuenta.sinRedEntrar),
              ],
              const SizedBox(height: Medidas.espacio4),
              BotonTexto(
                texto: 'Crear cuenta',
                anchoCompleto: true,
                alPresionar: _cargando ? null : () => context.go('/registro'),
              ),
              BotonTexto(
                texto: 'Olvidé mi contraseña',
                anchoCompleto: true,
                alPresionar: hayRed && !_cargando ? _recuperar : null,
              ),
              if (kDebugMode)
                BotonTexto(
                  texto: 'Entrar como demo',
                  icono: Icons.science_outlined,
                  anchoCompleto: true,
                  alPresionar: _cargando ? null : _entrarComoDemo,
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

/// "Tus datos de salud se guardan cifrados en tu celular." con su candado.
class NotaCifrado extends StatelessWidget {
  const NotaCifrado({super.key});

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outline_rounded, size: 20, color: colores.tinta2),
        const SizedBox(width: Medidas.espacio2),
        Flexible(
          child: Text(
            'Tus datos de salud se guardan cifrados en tu celular.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
