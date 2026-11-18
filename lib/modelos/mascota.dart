/// Tamanos posibles de una mascota.
///
/// Es un enum y no texto libre porque el tamano entra en el calculo de la
/// tarifa: con un String, un "Grande" con mayuscula o un "grandote" romperian
/// el calculo en silencio. Con enum, el compilador obliga a cubrir los tres.
enum Tamano {
  pequeno('Pequeño', 1.00),
  mediano('Mediano', 1.15),
  grande('Grande', 1.30);

  const Tamano(this.etiqueta, this.factorTarifa);

  /// Como se muestra en pantalla.
  final String etiqueta;

  /// Cuanto encarece el paseo. Viene del documento de requerimientos original:
  /// la tarifa depende del "peso y complexion de la mascota".
  final double factorTarifa;

  /// Reconstruye el enum desde lo guardado en SQLite.
  ///
  /// Si el valor no coincide con ninguno se devuelve [mediano] en vez de
  /// lanzar: un dato viejo o corrupto no deberia impedir abrir la app.
  static Tamano desdeTexto(String? valor) {
    return Tamano.values.firstWhere(
      (t) => t.name == valor,
      orElse: () => Tamano.mediano,
    );
  }
}

/// Un perro del usuario.
class Mascota {
  final int? id;
  final String nombre;
  final String raza;
  final Tamano tamano;
  final int edadMeses;

  /// Ruta del archivo de la foto en el telefono. La imagen no se guarda en la
  /// base: solo donde esta, para no inflar el archivo de SQLite.
  final String? fotoPath;

  final String notas;

  const Mascota({
    this.id,
    required this.nombre,
    required this.raza,
    required this.tamano,
    required this.edadMeses,
    this.fotoPath,
    this.notas = '',
  });

  bool get tieneFoto => fotoPath != null && fotoPath!.isNotEmpty;

  /// Edad en un formato legible: "2 anos y 3 meses", "8 meses".
  String get edadLegible {
    final anos = edadMeses ~/ 12;
    final meses = edadMeses % 12;
    if (anos == 0) return '$meses ${meses == 1 ? "mes" : "meses"}';
    if (meses == 0) return '$anos ${anos == 1 ? "año" : "años"}';
    return '$anos ${anos == 1 ? "año" : "años"} y $meses ${meses == 1 ? "mes" : "meses"}';
  }

  Mascota copiarCon({int? id, String? fotoPath}) => Mascota(
        id: id ?? this.id,
        nombre: nombre,
        raza: raza,
        tamano: tamano,
        edadMeses: edadMeses,
        fotoPath: fotoPath ?? this.fotoPath,
        notas: notas,
      );

  // SQLite solo guarda enteros, reales, texto y blobs: el enum viaja como su
  // nombre en texto y se reconstruye al leer.
  Map<String, Object?> aMapa() => {
        'id': id,
        'nombre': nombre,
        'raza': raza,
        'tamano': tamano.name,
        'edad_meses': edadMeses,
        'foto_path': fotoPath,
        'notas': notas,
      };

  factory Mascota.desdeMapa(Map<String, Object?> m) => Mascota(
        id: m['id'] as int?,
        nombre: m['nombre'] as String,
        raza: m['raza'] as String,
        tamano: Tamano.desdeTexto(m['tamano'] as String?),
        edadMeses: m['edad_meses'] as int,
        fotoPath: m['foto_path'] as String?,
        notas: (m['notas'] as String?) ?? '',
      );
}
