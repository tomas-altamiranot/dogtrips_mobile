import 'dart:io';

import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../datos/base_datos.dart';
import '../datos/fotos.dart';
import '../main.dart';
import '../modelos/mascota.dart';

/// Formulario para registrar un perro nuevo o editar uno existente.
///
/// Es la misma pantalla para las dos cosas: si recibe una mascota, la edita;
/// si recibe null, crea una nueva. Asi no hay dos formularios casi iguales.
class PantallaFormMascota extends StatefulWidget {
  const PantallaFormMascota({super.key, this.mascota});

  final Mascota? mascota;

  @override
  State<PantallaFormMascota> createState() => _PantallaFormMascotaState();
}

class _PantallaFormMascotaState extends State<PantallaFormMascota> {
  final _formulario = GlobalKey<FormState>();

  // Si se esta editando, los campos arrancan con los datos actuales.
  late final _nombre = TextEditingController(text: widget.mascota?.nombre);
  late final _raza = TextEditingController(text: widget.mascota?.raza);
  late final _anos = TextEditingController(
    text: widget.mascota == null ? '' : '${widget.mascota!.edadMeses ~/ 12}',
  );
  late final _meses = TextEditingController(
    text: widget.mascota == null ? '' : '${widget.mascota!.edadMeses % 12}',
  );
  late final _notas = TextEditingController(text: widget.mascota?.notas);
  late Tamano _tamano = widget.mascota?.tamano ?? Tamano.mediano;

  /// Foto recien tomada que aun no se guarda. Mientras sea null, se muestra la
  /// foto que ya tenia la mascota (si tenia).
  String? _fotoNueva;

  bool _guardando = false;

  bool get _editando => widget.mascota != null;

  @override
  void dispose() {
    _nombre.dispose();
    _raza.dispose();
    _anos.dispose();
    _meses.dispose();
    _notas.dispose();
    super.dispose();
  }

  void _avisar(String texto, {SnackBarAction? accion}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(texto), action: accion));
  }

  // ───────────────────────────────────────────────────────────────────────
  // Camara y galeria
  // ───────────────────────────────────────────────────────────────────────

  Future<void> _tomarFoto(ImageSource origen) async {
    try {
      final archivo = await ImagePicker().pickImage(
        source: origen,
        // Las fotos de camara pesan varios MB. Reducirlas evita llenar el
        // telefono y hace que la lista cargue rapido.
        maxWidth: 1080,
        imageQuality: 80,
      );
      // null significa que el usuario cancelo. No es un error.
      if (archivo == null) return;
      setState(() => _fotoNueva = archivo.path);
    } on PlatformException catch (e) {
      // En Android, si el usuario nego el permiso, image_picker lanza una
      // excepcion con este codigo en vez de abrir la camara.
      if (e.code == 'camera_access_denied' || e.code == 'photo_access_denied') {
        _avisar(
          'DogTrips no tiene permiso para usar la cámara.',
          accion: SnackBarAction(
            label: 'Ajustes',
            // Ya negado, la app no puede volver a preguntar: solo el usuario
            // puede activarlo desde los ajustes del telefono.
            onPressed: Geolocator.openAppSettings,
          ),
        );
      } else {
        _avisar('No se pudo abrir la cámara o la galería.');
      }
    }
  }

  void _elegirOrigenFoto() {
    showModalBottomSheet<void>(
      context: context,
      builder: (hoja) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () {
                Navigator.pop(hoja);
                _tomarFoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () {
                Navigator.pop(hoja);
                _tomarFoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // Guardar y borrar
  // ───────────────────────────────────────────────────────────────────────

  Future<void> _guardar() async {
    if (!_formulario.currentState!.validate()) return;
    setState(() => _guardando = true);

    try {
      // La foto nueva se copia a la carpeta permanente antes de guardar.
      var foto = widget.mascota?.fotoPath;
      if (_fotoNueva != null) foto = await Fotos.guardar(_fotoNueva!);

      final mascota = Mascota(
        id: widget.mascota?.id,
        nombre: _nombre.text.trim(),
        raza: _raza.text.trim(),
        tamano: _tamano,
        edadMeses: _edadEnMeses(),
        fotoPath: foto,
        notas: _notas.text.trim(),
      );

      if (_editando) {
        await BaseDatos.instancia.actualizarMascota(mascota);
        // Solo despues de guardar bien se borra la foto vieja: si fallara el
        // guardado, la mascota seguiria apuntando a ella.
        if (_fotoNueva != null) await Fotos.borrar(widget.mascota!.fotoPath);
      } else {
        await BaseDatos.instancia.insertarMascota(mascota);
      }

      if (!mounted) return;
      Navigator.pop(context);
    } on ErrorDeDatos catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      _avisar(e.mensaje);
    }
  }

  Future<void> _borrar() async {
    final m = widget.mascota!;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: Text('¿Borrar a ${m.nombre}?'),
        content: const Text(
          'También se borrarán sus reservas. Esto no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogo, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(dialogo, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    try {
      await BaseDatos.instancia.borrarMascota(m.id!);
      await Fotos.borrar(m.fotoPath);
      if (!mounted) return;
      Navigator.pop(context);
    } on ErrorDeDatos catch (e) {
      _avisar(e.mensaje);
    }
  }

  /// Los campos vacios cuentan como cero.
  int _edadEnMeses() =>
      (int.tryParse(_anos.text) ?? 0) * 12 + (int.tryParse(_meses.text) ?? 0);

  // ───────────────────────────────────────────────────────────────────────
  // Interfaz
  // ───────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar a ${widget.mascota!.nombre}' : 'Nuevo perro'),
        actions: [
          if (_editando)
            IconButton(
              tooltip: 'Borrar',
              icon: const Icon(Icons.delete_outline),
              onPressed: _borrar,
            ),
        ],
      ),
      body: Form(
        key: _formulario,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(child: _selectorFoto()),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nombre,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                prefixIcon: Icon(Icons.pets),
              ),
              validator: _obligatorio('Escribe su nombre'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _raza,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Raza',
                hintText: 'Si no sabes, escribe "Mestizo"',
              ),
              validator: _obligatorio('Escribe su raza'),
            ),
            const SizedBox(height: 20),
            const Text('Tamaño', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<Tamano>(
              segments: [
                for (final t in Tamano.values)
                  ButtonSegment(value: t, label: Text(t.etiqueta)),
              ],
              selected: {_tamano},
              onSelectionChanged: (s) => setState(() => _tamano = s.first),
            ),
            const SizedBox(height: 6),
            const Text(
              'Pequeño: menos de 10 kg · Mediano: 10 a 25 kg · Grande: más de 25 kg.'
              ' El tamaño cambia la tarifa del paseo.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            const Text('Edad', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _anos,
                    decoration: const InputDecoration(labelText: 'Años'),
                    keyboardType: TextInputType.number,
                    // Solo deja escribir digitos: ni letras, ni puntos, ni "-".
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      if ((int.tryParse(v ?? '') ?? 0) > 25) {
                        return 'Máximo 25';
                      }
                      if (_edadEnMeses() == 0) return 'Indica su edad';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _meses,
                    decoration: const InputDecoration(labelText: 'Meses'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) =>
                        (int.tryParse(v ?? '') ?? 0) > 11 ? 'De 0 a 11' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _notas,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Lo que el paseador debe saber (opcional)',
                hintText: 'Le dan miedo los cohetes, jala la correa...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _guardando ? null : _guardar,
              child: _guardando
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_editando ? 'Guardar cambios' : 'Registrar'),
            ),
          ],
        ),
      ),
    );
  }

  /// Devuelve un validador que exige que el campo no este vacio.
  FormFieldValidator<String> _obligatorio(String mensaje) =>
      (v) => (v == null || v.trim().isEmpty) ? mensaje : null;

  Widget _selectorFoto() {
    final ruta = _fotoNueva ?? widget.mascota?.fotoPath;
    final tieneFoto = ruta != null && ruta.isNotEmpty;

    return GestureDetector(
      onTap: _elegirOrigenFoto,
      child: Stack(
        children: [
          Hero(
            // Misma etiqueta que en la lista, para la animacion de entrada.
            tag: 'mascota-${widget.mascota?.id ?? 'nueva'}',
            child: CircleAvatar(
              radius: 60,
              backgroundColor: ColoresDogTrips.navy.withValues(alpha: 0.1),
              backgroundImage: tieneFoto ? FileImage(File(ruta)) : null,
              child: tieneFoto
                  ? null
                  : const Icon(Icons.pets, size: 48, color: ColoresDogTrips.navy),
            ),
          ),
          const Positioned(
            right: 0,
            bottom: 0,
            child: CircleAvatar(
              radius: 20,
              backgroundColor: ColoresDogTrips.coral,
              child: Icon(Icons.photo_camera, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
