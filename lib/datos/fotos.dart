import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'base_datos.dart';

/// Guarda y borra las fotos de las mascotas.
///
/// image_picker entrega la foto en la carpeta de cache, y Android puede vaciar
/// esa carpeta cuando necesita espacio: la foto desapareceria sin aviso. Por
/// eso se copia a la carpeta de documentos de la app, que solo se borra si se
/// desinstala la app.
class Fotos {
  Fotos._();

  /// Copia la foto a la carpeta permanente y devuelve su nueva ruta, que es la
  /// que se guarda en SQLite.
  static Future<String> guardar(String rutaTemporal) async {
    try {
      final documentos = await getApplicationDocumentsDirectory();
      final carpeta = Directory(p.join(documentos.path, 'fotos'));
      await carpeta.create(recursive: true);

      // La hora en milisegundos como nombre: nunca se repite, asi una foto
      // nueva no pisa a otra.
      final nombre =
          '${DateTime.now().millisecondsSinceEpoch}${p.extension(rutaTemporal)}';
      final copia = await File(rutaTemporal).copy(p.join(carpeta.path, nombre));
      return copia.path;
    } catch (e) {
      throw ErrorDeDatos('No se pudo guardar la foto.', e);
    }
  }

  /// Borra una foto que ya no se usa. Si falla, no pasa nada grave: solo queda
  /// un archivo huerfano, asi que no se le avisa al usuario.
  static Future<void> borrar(String? ruta) async {
    if (ruta == null || ruta.isEmpty) return;
    try {
      final archivo = File(ruta);
      if (await archivo.exists()) await archivo.delete();
    } catch (_) {}
  }
}
