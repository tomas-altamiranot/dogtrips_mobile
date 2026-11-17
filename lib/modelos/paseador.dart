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
    return '$anos ${anos == 1 ? "ano" : "anos"} de experiencia';
  }

  // ───────────────────────────────────────────────────────────────────────
  // Serializacion
  // ───────────────────────────────────────────────────────────────────────
  // SQLite no guarda listas. Las habilidades viajan como texto separado por
  // "|" en vez de JSON: son valores cortos y sin comas, y asi la columna se
  // puede leer de un vistazo al inspeccionar la base durante la demo.

  static const _separador = '|';

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
        'habilidades': habilidades.join(_separador),
      };

  factory Paseador.desdeMapa(Map<String, Object?> m) {
    final texto = (m['habilidades'] as String?) ?? '';
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
      habilidades: texto.isEmpty ? const [] : texto.split(_separador),
    );
  }
}
