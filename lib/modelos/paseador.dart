import 'dart:convert';

/// Alguien que ofrece paseos.
///
/// A diferencia de [Mascota] y [Reserva], el usuario no crea paseadores: se
/// siembran en la base la primera vez que la app arranca. En un marketplace
/// real vendrian de un servidor; aqui vienen de un seed local, igual que el
/// proyecto hermano siembra su base de grafos.
class Paseador {
  final int? id;
  final String nombre;

  /// Colonia de Merida donde trabaja.
  final String zona;

  final double latitud;
  final double longitud;

  /// Promedio de 1 a 5.
  final double calificacion;

  /// Cuantos paseos lleva hechos. Da contexto a la calificacion: un 5.0 con
  /// tres paseos no dice lo mismo que un 4.7 con doscientos.
  final int paseosHechos;

  final double tarifaHora;
  final int experienciaMeses;

  /// Documentos revisados por DogTrips. En el documento de requerimientos
  /// original: "se evaluaran los documentos del paseador y su historial penal".
  final bool verificado;

  /// Capacidades acreditadas: "Maneja perros grandes", "Primeros auxilios".
  final List<String> habilidades;

  const Paseador({
    this.id,
    required this.nombre,
    required this.zona,
    required this.latitud,
    required this.longitud,
    required this.calificacion,
    required this.paseosHechos,
    required this.tarifaHora,
    required this.experienciaMeses,
    required this.verificado,
    this.habilidades = const [],
  });

  String get experienciaLegible {
    final anos = experienciaMeses ~/ 12;
    if (anos == 0) return '$experienciaMeses meses de experiencia';
    return '$anos ${anos == 1 ? "año" : "años"} de experiencia';
  }

  // ───────────────────────────────────────────────────────────────────────
  // Serializacion
  // ───────────────────────────────────────────────────────────────────────
  // SQLite no guarda listas. Las habilidades viajan como texto JSON:
  // ["Primeros auxilios","Maneja grupos"]. Se eligio JSON y no un separador
  // como "|" porque JSON ya sabe escapar cualquier caracter: si manana una
  // habilidad trajera ese simbolo, el separador la partiria en dos.

  Map<String, Object?> aMapa() => {
    'id': id,
    'nombre': nombre,
    'zona': zona,
    'latitud': latitud,
    'longitud': longitud,
    'calificacion': calificacion,
    'paseos_hechos': paseosHechos,
    'tarifa_hora': tarifaHora,
    'experiencia_meses': experienciaMeses,
    // SQLite tampoco tiene booleanos: se guardan como 1 y 0.
    'verificado': verificado ? 1 : 0,
    'habilidades': jsonEncode(habilidades),
  };

  factory Paseador.desdeMapa(Map<String, Object?> m) {
    return Paseador(
      id: m['id'] as int?,
      nombre: m['nombre'] as String,
      zona: m['zona'] as String,
      // Un numero puede volver de SQLite como int o double segun el valor que
      // se guardo, asi que se normaliza en vez de castear.
      latitud: (m['latitud'] as num).toDouble(),
      longitud: (m['longitud'] as num).toDouble(),
      calificacion: (m['calificacion'] as num).toDouble(),
      paseosHechos: m['paseos_hechos'] as int,
      tarifaHora: (m['tarifa_hora'] as num).toDouble(),
      experienciaMeses: m['experiencia_meses'] as int,
      verificado: (m['verificado'] as int) == 1,
      habilidades: _leerHabilidades(m['habilidades'] as String?),
    );
  }

  /// Convierte el texto JSON de vuelta en lista.
  ///
  /// Si el texto esta vacio o no es JSON valido, devuelve lista vacia en vez
  /// de lanzar: un dato danado no deberia impedir ver al paseador.
  static List<String> _leerHabilidades(String? texto) {
    if (texto == null || texto.isEmpty) return const [];
    try {
      return List<String>.from(jsonDecode(texto) as List);
    } on FormatException {
      return const [];
    }
  }
}
