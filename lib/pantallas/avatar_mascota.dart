import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../main.dart';
import '../modelos/mascota.dart';

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
      backgroundImage:
          mascota.tieneFoto ? FileImage(File(mascota.fotoPath!)) : null,
      child: mascota.tieneFoto
          ? null
          : Text(
              mascota.nombre.characters.first.toUpperCase(),
              style: TextStyle(color: Colors.white, fontSize: radio * 0.9),
            ),
    );
  }
}
