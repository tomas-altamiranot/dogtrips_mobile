import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../datos/base_datos.dart';
import '../main.dart';
import '../modelos/paseo.dart';

/// Formulario para registrar un paseo.
///
/// Guarda SIEMPRE en la base local. El paseador trabaja en la calle, donde la
/// cobertura falla; depender de la red para registrar un paseo seria perder
/// datos justo cuando mas importan.
class PantallaNuevoPaseo extends StatefulWidget {
  const PantallaNuevoPaseo({super.key});

  @override
  State<PantallaNuevoPaseo> createState() => _PantallaNuevoPaseoState();
}

class _PantallaNuevoPaseoState extends State<PantallaNuevoPaseo> {
  final _formulario = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _duracion = TextEditingController(text: '30');
  final _notas = TextEditingController();

  String? _fotoPath;
  double? _lat;
  double? _lon;
  bool _buscandoUbicacion = false;
  bool _guardando = false;

  @override
  void dispose() {
    // Los controladores retienen memoria y escuchas mientras viven. Sin este
    // dispose se filtran cada vez que se abre y cierra la pantalla.
    _nombre.dispose();
    _duracion.dispose();
    _notas.dispose();
    super.dispose();
  }

  void _avisar(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  // ───────────────────────────────────────────────────────────────────────
  // Camara y galeria
  // ───────────────────────────────────────────────────────────────────────

  Future<void> _tomarFoto(ImageSource origen) async {
    try {
      final archivo = await ImagePicker().pickImage(
        source: origen,
        // Las fotos de camara pesan varios MB. Reducirlas al guardarlas evita
        // llenar el telefono y hace que la lista cargue rapido.
        maxWidth: 1280,
        imageQuality: 80,
      );
      // archivo es null cuando el usuario cancela. No es un error.
      if (archivo == null) return;
      setState(() => _fotoPath = archivo.path);
    } catch (e) {
      _avisar('No se pudo acceder a la camara o la galeria.');
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
              title: const Text('Elegir de la galeria'),
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
  // Ubicacion
  // ───────────────────────────────────────────────────────────────────────

  /// Captura la ubicacion actual.
  ///
  /// Maneja los tres casos en que puede fallar, que es lo que distingue una app
  /// que no truena: el GPS apagado, el permiso negado una vez, y el permiso
  /// negado para siempre (ahi ya no sirve volver a pedirlo).
  Future<void> _capturarUbicacion() async {
    setState(() => _buscandoUbicacion = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _avisar('Activa la ubicacion del telefono para registrar el punto.');
        return;
      }

      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.deniedForever) {
        _avisar('El permiso de ubicacion esta bloqueado. '
            'Actívalo desde los ajustes del telefono.');
        return;
      }
      if (permiso == LocationPermission.denied) {
        _avisar('Sin permiso de ubicacion. El paseo se guardara sin el punto.');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          // Sin limite de tiempo, un GPS sin senal deja la pantalla colgada.
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lon = pos.longitude;
      });
      _avisar('Ubicacion capturada.');
    } catch (e) {
      _avisar('No se pudo obtener la ubicacion. Intenta al aire libre.');
    } finally {
      if (mounted) setState(() => _buscandoUbicacion = false);
    }
  }

  // ───────────────────────────────────────────────────────────────────────
  // Guardado
  // ───────────────────────────────────────────────────────────────────────

  Future<void> _guardar() async {
    if (!_formulario.currentState!.validate()) return;

    setState(() => _guardando = true);
    try {
      final paseo = Paseo(
        nombrePerro: _nombre.text.trim(),
        fecha: DateTime.now(),
        duracionMin: int.parse(_duracion.text),
        notas: _notas.text.trim(),
        fotoPath: _fotoPath,
        latitud: _lat,
        longitud: _lon,
      );
      await BaseDatos.instancia.insertar(paseo);
      if (!mounted) return;
      // true le dice a la lista que recargue; false o null significa que el
      // usuario se salio sin guardar.
      Navigator.pop(context, true);
    } on ErrorDeDatos catch (e) {
      _avisar(e.mensaje);
    } catch (e) {
      _avisar('Ocurrio un error inesperado al guardar.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar paseo')),
      body: Form(
        key: _formulario,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _BotonFoto(ruta: _fotoPath, alTocar: _elegirOrigenFoto),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nombre,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre del perro',
                prefixIcon: Icon(Icons.pets),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Escribe el nombre del perro'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _duracion,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Duracion en minutos',
                prefixIcon: Icon(Icons.timer_outlined),
              ),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null) return 'Escribe un numero';
                if (n <= 0 || n > 480) return 'Entre 1 y 480 minutos';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _notas,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notas del paseo',
                hintText: 'Como se porto, con quien se llevo bien...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            _FilaUbicacion(
              lat: _lat,
              lon: _lon,
              cargando: _buscandoUbicacion,
              alTocar: _capturarUbicacion,
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _guardando ? null : _guardar,
                icon: _guardando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_guardando ? 'Guardando...' : 'Guardar paseo'),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'El paseo se guarda en este telefono, aunque no haya senal.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _BotonFoto extends StatelessWidget {
  const _BotonFoto({this.ruta, required this.alTocar});

  final String? ruta;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final hayFoto = ruta != null && ruta!.isNotEmpty;

    return GestureDetector(
      onTap: alTocar,
      child: Container(
        height: 190,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: ColoresDogTrips.navy.withValues(alpha: 0.25),
            style: hayFoto ? BorderStyle.solid : BorderStyle.none,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: hayFoto
            ? Image.file(File(ruta!), fit: BoxFit.cover, width: double.infinity)
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined,
                      size: 42, color: ColoresDogTrips.coral),
                  SizedBox(height: 10),
                  Text('Agregar foto del paseo'),
                  SizedBox(height: 3),
                  Text('Camara o galeria',
                      style: TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
      ),
    );
  }
}

class _FilaUbicacion extends StatelessWidget {
  const _FilaUbicacion({
    this.lat,
    this.lon,
    required this.cargando,
    required this.alTocar,
  });

  final double? lat;
  final double? lon;
  final bool cargando;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final hay = lat != null && lon != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ColoresDogTrips.navy.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(
            hay ? Icons.place : Icons.place_outlined,
            color: hay ? ColoresDogTrips.coral : Colors.black38,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hay ? 'Ubicacion capturada' : 'Sin ubicacion',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  hay
                      ? '${lat!.toStringAsFixed(5)}, ${lon!.toStringAsFixed(5)}'
                      : 'Opcional, pero ayuda al dueno',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          cargando
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : TextButton(
                  onPressed: alTocar,
                  child: Text(hay ? 'Actualizar' : 'Capturar'),
                ),
        ],
      ),
    );
  }
}
