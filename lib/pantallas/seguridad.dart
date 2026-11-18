import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../datos/base_datos.dart';
import '../datos/seguridad.dart';
import '../main.dart';
import '../modelos/dueno.dart';

/// Crear o cambiar el PIN y elegir si se entra con huella.
///
/// La usan dos caminos: la bienvenida (al crear la cuenta) y "Proteger mi
/// cuenta" en el Inicio (para cuentas que ya existian).
class PantallaSeguridad extends StatefulWidget {
  const PantallaSeguridad({super.key, required this.dueno});

  final Dueno dueno;

  @override
  State<PantallaSeguridad> createState() => _PantallaSeguridadState();
}

class _PantallaSeguridadState extends State<PantallaSeguridad> {
  final _formulario = GlobalKey<FormState>();
  final _pin = TextEditingController();
  final _confirmacion = TextEditingController();

  late bool _usaBiometria = widget.dueno.usaBiometria;

  /// Se averigua al abrir la pantalla: si el telefono no tiene huella
  /// registrada, el interruptor ni siquiera se ofrece.
  late final Future<bool> _hayBiometria = Seguridad.biometriaDisponible();

  bool _guardando = false;

  @override
  void dispose() {
    _pin.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  void _avisar(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  /// Al encender la huella se pide una vez, para comprobar que funciona antes
  /// de depender de ella para entrar.
  Future<void> _cambiarBiometria(bool activar) async {
    if (!activar) {
      setState(() => _usaBiometria = false);
      return;
    }
    final resultado = await Seguridad.pedirBiometria(
      'Confirma tu huella para usarla al entrar a DogTrips',
    );
    if (!mounted) return;
    switch (resultado) {
      case ResultadoBiometria.exito:
        setState(() => _usaBiometria = true);
      case ResultadoBiometria.cancelado:
        break; // el interruptor se queda apagado, sin regaño
      case ResultadoBiometria.noDisponible:
        _avisar('Registra una huella en los ajustes de tu teléfono primero.');
      case ResultadoBiometria.bloqueado:
        _avisar('Demasiados intentos. Espera un momento e intenta de nuevo.');
      case ResultadoBiometria.error:
        _avisar('No se pudo usar la huella.');
    }
  }

  Future<void> _guardar() async {
    if (!_formulario.currentState!.validate()) return;
    setState(() => _guardando = true);

    final protegido = Seguridad.protegerPin(_pin.text);
    try {
      await BaseDatos.instancia.guardarDueno(
        widget.dueno.copiarCon(
          pinHash: protegido.hash,
          pinSal: protegido.sal,
          usaBiometria: _usaBiometria,
        ),
      );
      // Quien acaba de crear su PIN ya demostro quien es: no tiene sentido
      // pedirselo de nuevo en cuanto regrese al Inicio.
      Seguridad.sesionAbierta = true;
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ErrorDeDatos catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      _avisar(e.mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Protege tu cuenta')),
      body: Form(
        key: _formulario,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(
              Icons.lock_outline,
              size: 56,
              color: ColoresDogTrips.coral,
            ),
            const SizedBox(height: 12),
            Text(
              widget.dueno.tienePin
                  ? 'Cambia tu PIN de 4 dígitos'
                  : 'Crea un PIN de 4 dígitos',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: ColoresDogTrips.navy,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Lo pediremos cada vez que abras DogTrips: tu app guarda los '
              'datos de tus perros y dónde los paseas.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            _CampoPin(
              controller: _pin,
              etiqueta: 'PIN',
              validator: (v) =>
                  (v ?? '').length != 4 ? 'El PIN lleva 4 dígitos' : null,
            ),
            const SizedBox(height: 14),
            _CampoPin(
              controller: _confirmacion,
              etiqueta: 'Repite el PIN',
              validator: (v) => v != _pin.text ? 'Los PIN no coinciden' : null,
            ),
            const SizedBox(height: 20),
            FutureBuilder<bool>(
              future: _hayBiometria,
              builder: (context, snapshot) {
                if (snapshot.data != true) {
                  // Mientras se averigua, o si no hay huella: un aviso.
                  return const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.fingerprint, color: Colors.black38),
                    title: Text('Entrar con huella'),
                    subtitle: Text(
                      'Tu teléfono no tiene una huella registrada. Puedes '
                      'agregarla en sus ajustes y activarla aquí después.',
                    ),
                  );
                }
                return SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(
                    Icons.fingerprint,
                    color: ColoresDogTrips.coral,
                  ),
                  title: const Text('Entrar con huella o rostro'),
                  subtitle: const Text('Si falla, siempre puedes usar el PIN.'),
                  value: _usaBiometria,
                  onChanged: _cambiarBiometria,
                );
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _guardando ? null : _guardar,
              child: _guardando
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CampoPin extends StatelessWidget {
  const _CampoPin({
    required this.controller,
    required this.etiqueta,
    required this.validator,
  });

  final TextEditingController controller;
  final String etiqueta;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: etiqueta,
        prefixIcon: const Icon(Icons.pin_outlined),
        counterText: '', // oculta el "0/4" que agrega maxLength
      ),
      obscureText: true, // puntos en vez de numeros, como en un cajero
      keyboardType: TextInputType.number,
      maxLength: 4,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: validator,
    );
  }
}
