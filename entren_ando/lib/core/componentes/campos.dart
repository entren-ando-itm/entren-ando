import 'package:flutter/material.dart';

import '../tema/colores.dart';
import '../tema/medidas.dart';
import 'textos.dart';

/// Campo de texto con su etiqueta arriba, sin bordes (fondo sup1, esquinas de 18).
///
///   CampoTexto(
///     etiqueta: 'Correo',
///     controlador: _correo,
///     teclado: TextInputType.emailAddress,
///     autocompletar: const [AutofillHints.email],
///   )
///   CampoTexto(etiqueta: 'Contraseña', controlador: _clave, esContrasena: true)
///
/// Funciona dentro de un `Form`: pasa `validar` para mostrar el error abajo.
class CampoTexto extends StatefulWidget {
  const CampoTexto({
    super.key,
    required this.etiqueta,
    this.controlador,
    this.pista,
    this.esContrasena = false,
    this.teclado,
    this.accionTeclado,
    this.validar,
    this.alCambiar,
    this.alEnviar,
    this.autocompletar,
    this.habilitado = true,
    this.maxLineas = 1,
  });

  final String etiqueta;
  final TextEditingController? controlador;

  /// Texto gris de ejemplo dentro del campo vacío.
  final String? pista;

  /// Oculta el texto y agrega el botón para mostrarlo.
  final bool esContrasena;
  final TextInputType? teclado;
  final TextInputAction? accionTeclado;
  final String? Function(String?)? validar;
  final ValueChanged<String>? alCambiar;
  final ValueChanged<String>? alEnviar;

  /// Ayuda al autocompletado del celular, por ejemplo `[AutofillHints.email]`.
  final Iterable<String>? autocompletar;
  final bool habilitado;
  final int maxLineas;

  @override
  State<CampoTexto> createState() => _CampoTextoState();
}

class _CampoTextoState extends State<CampoTexto> {
  bool _oculto = true;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final esContrasena = widget.esContrasena;
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EtiquetaSeccion(widget.etiqueta),
          const SizedBox(height: 6),
          TextFormField(
            controller: widget.controlador,
            keyboardType: widget.teclado,
            textInputAction: widget.accionTeclado,
            obscureText: esContrasena && _oculto,
            enableSuggestions: !esContrasena,
            autocorrect: !esContrasena,
            validator: widget.validar,
            onChanged: widget.alCambiar,
            onFieldSubmitted: widget.alEnviar,
            autofillHints: widget.autocompletar,
            enabled: widget.habilitado,
            maxLines: esContrasena ? 1 : widget.maxLineas,
            style: Theme.of(context).textTheme.bodyLarge,
            decoration: InputDecoration(
              hintText: widget.pista,
              suffixIcon: esContrasena
                  ? IconButton(
                      tooltip: _oculto ? 'Mostrar contraseña' : 'Ocultar contraseña',
                      icon: Icon(_oculto ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      color: colores.tinta2,
                      onPressed: () => setState(() => _oculto = !_oculto),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Casilla para aceptar algo, como el aviso de privacidad. Es un cuadro
/// sólido sin borde: sup2 si está vacía y tinta con palomita si está marcada.
///
///   Casilla(
///     valor: _acepto,
///     alCambiar: (valor) => setState(() => _acepto = valor),
///     etiqueta: const Text('Acepto el aviso de privacidad'),
///   )
class Casilla extends StatelessWidget {
  const Casilla({
    super.key,
    required this.valor,
    required this.alCambiar,
    required this.etiqueta,
  });

  final bool valor;

  /// null = desactivada.
  final ValueChanged<bool>? alCambiar;

  /// Texto (o texto con enlace) a la derecha.
  final Widget etiqueta;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    final alCambiar = this.alCambiar;
    return Semantics(
      checked: valor,
      enabled: alCambiar != null,
      child: InkWell(
        borderRadius: BorderRadius.circular(Medidas.radioInterno),
        onTap: alCambiar == null ? null : () => alCambiar(!valor),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Medidas.toqueMinimo),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: valor ? colores.tinta : colores.sup2,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: valor ? Icon(Icons.check_rounded, size: 18, color: colores.fondo) : null,
              ),
              const SizedBox(width: Medidas.espacio3),
              Expanded(
                child: DefaultTextStyle.merge(
                  style: Theme.of(context).textTheme.bodyMedium,
                  child: etiqueta,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
