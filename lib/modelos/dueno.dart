/// La persona que usa la app: el dueno de los perros.
///
/// Solo existe uno por telefono, porque la app no tiene cuentas ni servidor.
/// Por eso su id siempre es 1.
class Dueno {
  final int id;
  final String nombre;

  const Dueno({this.id = 1, required this.nombre});

  /// "Tomas Altamirano" -> "Tomas". Para saludar no hace falta el apellido.
  String get primerNombre => nombre.trim().split(' ').first;

  /// Letra para el circulo del avatar.
  String get inicial =>
      primerNombre.isEmpty ? '?' : primerNombre[0].toUpperCase();

  Map<String, Object?> aMapa() => {'id': id, 'nombre': nombre};

  factory Dueno.desdeMapa(Map<String, Object?> m) =>
      Dueno(id: m['id'] as int, nombre: m['nombre'] as String);
}
