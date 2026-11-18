import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../datos/seguridad.dart';
import '../main.dart';
import '../modelos/dueno.dart';

/// Pantalla de entrada: pide la huella o el PIN antes de mostrar la cuenta.
///
/// Igual que la bienvenida, no es una ruta: la muestra el Inicio en su lugar
/// mientras la sesion no este abierta.
class PantallaBloqueo extends StatefulWidget {
  const PantallaBloqueo({
    super.key,
    required this.dueno,
    required this.alDesbloquear,
  });

  final Dueno dueno;
  final VoidCallback alDesbloquear;

  @override
  State<PantallaBloqueo> createState() => _PantallaBloqueoState();
}

class _PantallaBloqueoState extends State<PantallaBloqueo> {
  final _pin = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.dueno.usaBiometria) {
      // El dialogo de huella no se puede abrir mientras la pantalla todavia
      // se esta construyendo: se espera al primer cuadro dibujado.
      WidgetsBinding.instance.addPostFrameCallback((_) => _usarHuella());
    }
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  void _entrar() {
    Seguridad.sesionAbierta = true;
    widget.alDesbloquear();
  }

  Future<void> _usarHuella() async {
    final resultado = await Seguridad.pedirBiometria(
      'Entra a tu cuenta de DogTrips',
    );
    if (!mounted) return;
    switch (resultado) {
      case ResultadoBiometria.exito:
        _entrar();
      case ResultadoBiometria.cancelado:
        break; // se queda en la pantalla, con el PIN como alternativa
      case ResultadoBiometria.noDisponible:
        setState(() => _error = 'Huella no disponible. Usa tu PIN.');
      case ResultadoBiometria.bloqueado:
        setState(() => _error = 'Demasiados intentos con huella. Usa tu PIN.');
      case ResultadoBiometria.error:
        setState(() => _error = 'No se pudo leer la huella. Usa tu PIN.');
    }
  }

  /// Se revisa en cuanto se escribe el 4.o digito: no hace falta un boton.
  void _alEscribir(String valor) {
    if (valor.length < 4) {
      if (_error != null) setState(() => _error = null);
      return;
    }
    if (Seguridad.pinCorrecto(valor, widget.dueno)) {
      _entrar();
    } else {
      _pin.clear();
      setState(() => _error = 'PIN incorrecto');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresDogTrips.navy,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const LogoDogTrips(altura: 40),
                const SizedBox(height: 40),
                Text(
                  'Hola, ${widget.dueno.primerNombre}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Escribe tu PIN para entrar',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _pin,
                    autofocus: !widget.dueno.usaBiometria,
                    obscureText: true,
                    obscuringCharacter: '●',
                    maxLength: 4,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 28, letterSpacing: 16),
                    decoration: const InputDecoration(counterText: ''),
                    onChanged: _alEscribir,
                  ),
                ),
                const SizedBox(height: 12),
                // Espacio fijo para el error: asi la pantalla no "brinca"
                // cuando aparece o desaparece el mensaje.
                SizedBox(
                  height: 22,
                  child: Text(
                    _error ?? '',
                    style: const TextStyle(color: ColoresDogTrips.coral),
                  ),
                ),
                if (widget.dueno.usaBiometria) ...[
                  const SizedBox(height: 20),
                  TextButton.icon(
                    onPressed: _usarHuella,
                    icon: const Icon(Icons.fingerprint, size: 32),
                    label: const Text('Usar huella'),
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
