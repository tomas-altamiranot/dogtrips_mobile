import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../main.dart';
import '../modelos/mascota.dart';

// Piezas visuales de la mascota que se repiten en varias pantallas.

/// Circulo con la foto de la mascota, o con su inicial si no tiene foto.
///
/// Se usa en el Inicio, en la lista y en el formulario. Vive en su propio
/// archivo para no copiar el mismo codigo en tres pantallas.
class AvatarMascota extends StatelessWidget {
  const AvatarMascota({super.key, required this.mascota, required this.radio});

  final Mascota mascota;
  final double radio;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radio,
      backgroundColor: ColoresDogTrips.navy,
      backgroundImage: mascota.tieneFoto
          ? FileImage(File(mascota.fotoPath!))
          : null,
      child: mascota.tieneFoto
          ? null
          : Text(
              mascota.nombre.characters.first.toUpperCase(),
              style: TextStyle(color: Colors.white, fontSize: radio * 0.9),
            ),
    );
  }
}

/// Chip para elegir un perro (en el Inicio y en la reserva).
///
/// Los dos estados deben distinguirse de un vistazo: elegido va relleno de
/// coral con palomita; no elegido, blanco con borde gris.
class ChipMascota extends StatelessWidget {
  const ChipMascota({
    super.key,
    required this.mascota,
    required this.elegida,
    required this.alCambiar,
  });

  final Mascota mascota;
  final bool elegida;
  final ValueChanged<bool> alCambiar;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      // Con palomita no cabe tambien el avatar: se muestra uno u otro.
      avatar: elegida ? null : AvatarMascota(mascota: mascota, radio: 12),
      label: Text(mascota.nombre),
      selected: elegida,
      onSelected: alCambiar,
      showCheckmark: true,
      checkmarkColor: Colors.white,
      selectedColor: ColoresDogTrips.coral,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: elegida ? Colors.white : ColoresDogTrips.navy,
        fontWeight: elegida ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(color: elegida ? ColoresDogTrips.coral : Colors.black26),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    );
  }
}
