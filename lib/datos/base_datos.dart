import 'dart:math' as math;

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../modelos/mascota.dart';
import '../modelos/paseador.dart';
import '../modelos/reserva.dart';
import 'semilla_paseadores.dart';

/// Error de la capa de datos, con un mensaje que se le puede mostrar al usuario.
///
/// Existe para que las pantallas no tengan que entender excepciones de SQLite:
/// atrapan esto y muestran [mensaje] tal cual.
class ErrorDeDatos implements Exception {
  final String mensaje;
  final Object? causa;
  ErrorDeDatos(this.mensaje, [this.causa]);

  @override
  String toString() => mensaje;
}

/// Acceso a la base de datos local.
///
/// Es la unica clase que habla con SQLite. Las pantallas piden datos aqui y
/// nunca escriben SQL: si manana la app sincronizara con un servidor, el cambio
/// ocurriria dentro de esta clase y ninguna pantalla se enteraria.
class BaseDatos {
  BaseDatos._();

  /// Instancia unica. Abrir la base mantiene un archivo abierto y es caro, asi
  /// que se reutiliza durante toda la vida de la app.
  static final BaseDatos instancia = BaseDatos._();

  static const _archivo = 'dogtrips.db';
  static const _version = 1;

  static const tablaMascotas = 'mascotas';
  static const tablaPaseadores = 'paseadores';
  static const tablaReservas = 'reservas';

  Database? _db;

  Future<Database> get _base async {
    _db ??= await _abrir();
    return _db!;
  }

  Future<Database> _abrir() async {
    try {
      final ruta = p.join(await getDatabasesPath(), _archivo);
      return await openDatabase(
        ruta,
        version: _version,
        onCreate: _crear,
        // SQLite no aplica las llaves foraneas si no se le pide expresamente,
        // y lo hace por conexion, no por base. Sin esta linea se podria guardar
        // una reserva apuntando a una mascota que ya no existe.
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      );
    } catch (e) {
      throw ErrorDeDatos('No se pudo abrir la base de datos local.', e);
    }
  }

  /// Se ejecuta una sola vez, cuando el archivo de la base aun no existe.
  Future<void> _crear(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tablaMascotas (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre     TEXT    NOT NULL,
        raza       TEXT    NOT NULL,
        tamano     TEXT    NOT NULL,
        edad_meses INTEGER NOT NULL,
        foto_path  TEXT,
        notas      TEXT    NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE $tablaPaseadores (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre            TEXT    NOT NULL,
        zona              TEXT    NOT NULL,
        latitud           REAL    NOT NULL,
        longitud          REAL    NOT NULL,
        calificacion      REAL    NOT NULL,
        paseos_hechos     INTEGER NOT NULL,
        tarifa_hora       REAL    NOT NULL,
        experiencia_meses INTEGER NOT NULL,
        verificado        INTEGER NOT NULL,
        habilidades       TEXT    NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE $tablaReservas (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        mascota_id     INTEGER NOT NULL,
        paseador_id    INTEGER NOT NULL,
        fecha_hora     INTEGER NOT NULL,
        duracion_min   INTEGER NOT NULL,
        instrucciones  TEXT    NOT NULL DEFAULT '',
        estado         TEXT    NOT NULL,
        costo_estimado REAL    NOT NULL,
        FOREIGN KEY (mascota_id)  REFERENCES $tablaMascotas (id) ON DELETE CASCADE,
        FOREIGN KEY (paseador_id) REFERENCES $tablaPaseadores (id)
      )
    ''');

    // Las reservas se listan siempre ordenadas por fecha. Sin indice, SQLite
    // tendria que recorrer y ordenar la tabla entera en cada consulta.
    await db.execute(
      'CREATE INDEX idx_reservas_fecha ON $tablaReservas (fecha_hora DESC)',
    );

    await _sembrarPaseadores(db);
  }

  /// Carga los paseadores de ejemplo.
  ///
  /// Se hace dentro de onCreate, asi que ocurre exactamente una vez por
  /// instalacion. Y en una sola transaccion (batch): doce inserciones sueltas
  /// serian doce escrituras al disco.
  Future<void> _sembrarPaseadores(Database db) async {
    final lote = db.batch();
    for (final pas in paseadoresSembrados) {
      lote.insert(tablaPaseadores, pas.aMapa()..remove('id'));
    }
    await lote.commit(noResult: true);
  }

  // ───────────────────────────────────────────────────────────────────────
  // Mascotas
  // ───────────────────────────────────────────────────────────────────────

  Future<List<Mascota>> listarMascotas() async {
    try {
      final db = await _base;
      final filas = await db.query(tablaMascotas, orderBy: 'nombre');
      return filas.map(Mascota.desdeMapa).toList();
    } catch (e) {
      throw ErrorDeDatos('No se pudieron leer tus mascotas.', e);
    }
  }

  Future<Mascota> insertarMascota(Mascota m) async {
    try {
      final db = await _base;
      final id = await db.insert(tablaMascotas, m.aMapa()..remove('id'));
      return m.copiarCon(id: id);
    } catch (e) {
      throw ErrorDeDatos('No se pudo guardar la mascota.', e);
    }
  }

  Future<void> borrarMascota(int id) async {
    try {
      final db = await _base;
      // ON DELETE CASCADE elimina tambien sus reservas: una reserva de una
      // mascota que ya no existe no significa nada.
      await db.delete(tablaMascotas, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw ErrorDeDatos('No se pudo eliminar la mascota.', e);
    }
  }

  // ───────────────────────────────────────────────────────────────────────
  // Paseadores
  // ───────────────────────────────────────────────────────────────────────

  Future<List<Paseador>> listarPaseadores() async {
    try {
      final db = await _base;
      final filas = await db.query(tablaPaseadores, orderBy: 'calificacion DESC');
      return filas.map(Paseador.desdeMapa).toList();
    } catch (e) {
      throw ErrorDeDatos('No se pudieron leer los paseadores.', e);
    }
  }

  /// Paseadores ordenados por cercania a un punto.
  ///
  /// El orden se calcula en Dart y no en SQL porque SQLite no trae funciones
  /// trigonometricas de serie. Con doce paseadores la diferencia es nula; con
  /// miles habria que usar una extension geoespacial o resolverlo en el
  /// servidor.
  Future<List<Paseador>> paseadoresCercaDe(double lat, double lon) async {
    final todos = await listarPaseadores();
    final conDistancia = todos
        .map((pas) => (pas, _distanciaKm(lat, lon, pas.latitud, pas.longitud)))
        .toList()
      ..sort((a, b) => a.$2.compareTo(b.$2));
    return conDistancia.map((par) => par.$1).toList();
  }

  /// Distancia en kilometros entre dos coordenadas (formula de Haversine).
  ///
  /// Haversine calcula la distancia sobre la superficie de la esfera, no la
  /// linea recta que la atraviesa. Para distancias dentro de una ciudad la
  /// diferencia es minima, pero es la formula correcta.
  static double _distanciaKm(double lat1, double lon1, double lat2, double lon2) {
    const radioTierra = 6371.0;
    double aRadianes(double g) => g * math.pi / 180.0;

    final dLat = aRadianes(lat2 - lat1);
    final dLon = aRadianes(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(aRadianes(lat1)) *
            math.cos(aRadianes(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return radioTierra * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  /// Expuesta para que las pantallas muestren "a 2.3 km de ti".
  static double distanciaKm(double lat1, double lon1, double lat2, double lon2) =>
      _distanciaKm(lat1, lon1, lat2, lon2);

  // ───────────────────────────────────────────────────────────────────────
  // Reservas
  // ───────────────────────────────────────────────────────────────────────

  Future<Reserva> insertarReserva(Reserva r) async {
    try {
      final db = await _base;
      final id = await db.insert(tablaReservas, r.aMapa()..remove('id'));
      return r.copiarCon(id: id);
    } catch (e) {
      throw ErrorDeDatos('No se pudo guardar la reserva.', e);
    }
  }

  /// Reservas con su mascota y su paseador ya resueltos.
  ///
  /// La tabla guarda solo los ids, asi que hace falta unir las tres tablas. Se
  /// hace en una sola consulta con JOIN en vez de leer las reservas y luego
  /// consultar mascota y paseador una por una: eso serian 1 + 2N consultas en
  /// vez de una.
  Future<List<ReservaCompleta>> listarReservas() async {
    try {
      final db = await _base;
      final filas = await db.rawQuery('''
        SELECT
          r.id             AS r_id,
          r.mascota_id     AS r_mascota_id,
          r.paseador_id    AS r_paseador_id,
          r.fecha_hora     AS r_fecha_hora,
          r.duracion_min   AS r_duracion_min,
          r.instrucciones  AS r_instrucciones,
          r.estado         AS r_estado,
          r.costo_estimado AS r_costo_estimado,
          m.*,
          p.id                AS p_id,
          p.nombre            AS p_nombre,
          p.zona              AS p_zona,
          p.latitud           AS p_latitud,
          p.longitud          AS p_longitud,
          p.calificacion      AS p_calificacion,
          p.paseos_hechos     AS p_paseos_hechos,
          p.tarifa_hora       AS p_tarifa_hora,
          p.experiencia_meses AS p_experiencia_meses,
          p.verificado        AS p_verificado,
          p.habilidades       AS p_habilidades
        FROM $tablaReservas r
        JOIN $tablaMascotas   m ON m.id = r.mascota_id
        JOIN $tablaPaseadores p ON p.id = r.paseador_id
        ORDER BY r.fecha_hora DESC
      ''');

      return filas.map((f) {
        // Los prefijos r_ y p_ existen porque las tres tablas tienen columnas
        // con el mismo nombre (id, nombre). Sin renombrar, una pisaria a la
        // otra en el mapa de resultados.
        final reserva = Reserva.desdeMapa({
          'id': f['r_id'],
          'mascota_id': f['r_mascota_id'],
          'paseador_id': f['r_paseador_id'],
          'fecha_hora': f['r_fecha_hora'],
          'duracion_min': f['r_duracion_min'],
          'instrucciones': f['r_instrucciones'],
          'estado': f['r_estado'],
          'costo_estimado': f['r_costo_estimado'],
        });
        final paseador = Paseador.desdeMapa({
          'id': f['p_id'],
          'nombre': f['p_nombre'],
          'zona': f['p_zona'],
          'latitud': f['p_latitud'],
          'longitud': f['p_longitud'],
          'calificacion': f['p_calificacion'],
          'paseos_hechos': f['p_paseos_hechos'],
          'tarifa_hora': f['p_tarifa_hora'],
          'experiencia_meses': f['p_experiencia_meses'],
          'verificado': f['p_verificado'],
          'habilidades': f['p_habilidades'],
        });
        return ReservaCompleta(
          reserva: reserva,
          mascota: Mascota.desdeMapa(f),
          paseador: paseador,
        );
      }).toList();
    } catch (e) {
      throw ErrorDeDatos('No se pudieron leer tus reservas.', e);
    }
  }

  Future<void> cambiarEstadoReserva(int id, EstadoReserva estado) async {
    try {
      final db = await _base;
      await db.update(
        tablaReservas,
        {'estado': estado.name},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw ErrorDeDatos('No se pudo actualizar la reserva.', e);
    }
  }

  Future<void> borrarReserva(int id) async {
    try {
      final db = await _base;
      await db.delete(tablaReservas, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw ErrorDeDatos('No se pudo eliminar la reserva.', e);
    }
  }
}
