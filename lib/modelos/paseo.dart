import 'dart:convert';

/// Un paseo registrado por el paseador.
///
/// La clase no sabe nada de SQLite ni de pantallas: solo representa el dato y
/// sabe convertirse a formatos de almacenamiento y volver. Esa separacion es la
/// que permite cambiar de base de datos sin tocar el resto de la app.
class Paseo {
  /// Null mientras el paseo no se haya guardado. SQLite asigna el id al
  /// insertar, asi que un paseo recien creado en memoria todavia no tiene.
  final int? id;

  final String nombrePerro;
  final DateTime fecha;
  final int duracionMin;
  final String notas;

  /// Ruta del archivo de la foto en el almacenamiento del telefono.
  /// No se guarda la imagen en la base: solo donde esta.
  final String? fotoPath;

  final double? latitud;
  final double? longitud;

  const Paseo({
    this.id,
    required this.nombrePerro,
    required this.fecha,
    required this.duracionMin,
    this.notas = '',
    this.fotoPath,
    this.latitud,
    this.longitud,
  });

  bool get tieneUbicacion => latitud != null && longitud != null;
  bool get tieneFoto => fotoPath != null && fotoPath!.isNotEmpty;

  /// Copia el paseo cambiando solo los campos indicados.
  ///
  /// Hace falta porque los campos son `final`: un objeto inmutable no se
  /// modifica, se reemplaza. Se usa sobre todo para asignar el id que devuelve
  /// SQLite despues de insertar.
  Paseo copiarCon({int? id, String? fotoPath, double? latitud, double? longitud}) {
    return Paseo(
      id: id ?? this.id,
      nombrePerro: nombrePerro,
      fecha: fecha,
      duracionMin: duracionMin,
      notas: notas,
      fotoPath: fotoPath ?? this.fotoPath,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // Serializacion para SQLite
  // ───────────────────────────────────────────────────────────────────────
  // SQLite solo guarda tipos primitivos: enteros, reales, texto y blobs. No
  // sabe que es un DateTime. Por eso la fecha viaja como milisegundos desde
  // 1970 (un entero), que es exacto y se ordena bien sin conversiones.

  Map<String, Object?> aMapa() {
    return {
      'id': id,
      'nombre_perro': nombrePerro,
      'fecha': fecha.millisecondsSinceEpoch,
      'duracion_min': duracionMin,
      'notas': notas,
      'foto_path': fotoPath,
      'latitud': latitud,
      'longitud': longitud,
    };
  }

  factory Paseo.desdeMapa(Map<String, Object?> m) {
    return Paseo(
      id: m['id'] as int?,
      nombrePerro: m['nombre_perro'] as String,
      fecha: DateTime.fromMillisecondsSinceEpoch(m['fecha'] as int),
      duracionMin: m['duracion_min'] as int,
      notas: (m['notas'] as String?) ?? '',
      fotoPath: m['foto_path'] as String?,
      // Los numeros de SQLite pueden llegar como int o double segun el valor
      // guardado, asi que se normalizan con toDouble() en vez de castear.
      latitud: (m['latitud'] as num?)?.toDouble(),
      longitud: (m['longitud'] as num?)?.toDouble(),
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // Serializacion a JSON
  // ───────────────────────────────────────────────────────────────────────
  // Se usa para compartir el reporte del paseo con el dueno del perro, y es
  // tambien el formato con el que la app sincronizaria con la API en la nube.
  // La fecha va en ISO-8601 porque JSON lo leen otros sistemas, y un numero de
  // milisegundos no es legible fuera de esta app.

  Map<String, Object?> aJson() {
    return {
      'perro': nombrePerro,
      'fecha': fecha.toIso8601String(),
      'duracionMin': duracionMin,
      'notas': notas,
      'ubicacion': tieneUbicacion ? {'lat': latitud, 'lon': longitud} : null,
    };
  }

  String aJsonTexto() => const JsonEncoder.withIndent('  ').convert(aJson());

  factory Paseo.desdeJson(Map<String, Object?> j) {
    final u = j['ubicacion'] as Map<String, Object?>?;
    return Paseo(
      nombrePerro: j['perro'] as String,
      fecha: DateTime.parse(j['fecha'] as String),
      duracionMin: j['duracionMin'] as int,
      notas: (j['notas'] as String?) ?? '',
      latitud: (u?['lat'] as num?)?.toDouble(),
      longitud: (u?['lon'] as num?)?.toDouble(),
    );
  }
}
