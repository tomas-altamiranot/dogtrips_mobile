import 'package:material_ui/material_ui.dart';

import '../datos/base_datos.dart';
import '../main.dart';
import '../modelos/dueno.dart';

/// Lo primero que ve alguien que abre la app por primera vez.
///
/// No es una ruta propia: la muestra el Inicio cuando todavia no hay dueno
/// registrado. Asi no hace falta decidir en main() a que pantalla entrar.
class PantallaBienvenida extends StatefulWidget {
  const PantallaBienvenida({super.key, required this.alTerminar});

  /// Avisa al Inicio que ya hay dueno, para que se vuelva a cargar.
  final VoidCallback alTerminar;

  @override
  State<PantallaBienvenida> createState() => _PantallaBienvenidaState();
}

class _PantallaBienvenidaState extends State<PantallaBienvenida> {
  // La llave del formulario permite pedirle "valida todos tus campos" de un
  // solo golpe al tocar el boton.
  final _formulario = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  bool _guardando = false;

  @override
  void dispose() {
    // El controlador reserva memoria; si no se libera, se queda ocupada aunque
    // la pantalla ya no exista.
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _comenzar() async {
    if (!_formulario.currentState!.validate()) return;

    setState(() => _guardando = true);
    try {
      await BaseDatos.instancia.guardarDueno(
        Dueno(nombre: _nombre.text.trim()),
      );
      widget.alTerminar();
    } on ErrorDeDatos catch (e) {
      // "mounted" es falso si el usuario salio de la pantalla mientras se
      // guardaba; en ese caso ya no hay donde mostrar el mensaje.
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Form(
              key: _formulario,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // El logo completo ya incluye el slogan: no se repite abajo.
                  Image.asset('assets/imagenes/logo.png', height: 200),
                  const SizedBox(height: 36),
                  const Text(
                    'Cada paseo empieza\ncon confianza',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      height: 1.25,
                      fontWeight: FontWeight.bold,
                      color: ColoresDogTrips.navy,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Antes de buscarle compañía a tu perro, '
                    'queremos conocerte a ti.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.black54),
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _nombre,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _comenzar(),
                    decoration: const InputDecoration(
                      labelText: '¿Cómo te llamas?',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (valor) =>
                        (valor == null || valor.trim().isEmpty)
                        ? 'Escribe tu nombre'
                        : null,
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    // null deshabilita el boton: evita guardar dos veces si el
                    // usuario toca rapido.
                    onPressed: _guardando ? null : _comenzar,
                    child: _guardando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Comenzar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
