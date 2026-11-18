import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../modelos/dueno.dart';
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

  ErrorDeDatos(this.mensaje, [this.causa]) {
    // Al usuario se le muestra solo [mensaje]; la causa tecnica se escribe en
    // la consola de desarrollo para poder diagnosticar el problema.
    developer.log(mensaje, name: 'DogTrips', error: causa);
  }

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

  /// Version 1: mascotas, paseadores y reservas.
  /// Version 2: se agrega la tabla del dueno.
  /// Version 3: una reserva puede llevar varios perros (tabla reserva_mascotas)
  ///            y las habilidades del paseador pasan a guardarse en JSON.
  /// Version 4: login con PIN y huella (columnas nuevas en la tabla dueno).
  static const _version = 4;

  static const tablaDueno = 'dueno';
  static const tablaMascotas = 'mascotas';
  static const tablaPaseadores = 'paseadores';
  static const tablaReservas = 'reservas';
  static const tablaReservaMascotas = 'reserva_mascotas';

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
        // Si el telefono ya tenia una version anterior de la base, no se borra:
        // solo se le agrega lo que le falta, y las mascotas y reservas siguen ahi.
        onUpgrade: _actualizar,
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

    await _crearTablasReservas(db);
    await _crearTablaDueno(db);
    await _agregarColumnasSeguridad(db);
    await _sembrarPaseadores(db);
  }

  /// Reservas y su "lista de invitados".
  ///
  /// Una reserva puede llevar varios perros y un perro puede ir a muchos
  /// paseos: es una relacion de muchos a muchos, y en una base relacional eso
  /// siempre se resuelve con una tabla intermedia. Cada fila de
  /// reserva_mascotas dice "este perro va a este paseo".
  Future<void> _crearTablasReservas(Database db) async {
    await db.execute('''
      CREATE TABLE $tablaReservas (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        paseador_id    INTEGER NOT NULL,
        fecha_hora     INTEGER NOT NULL,
        duracion_min   INTEGER NOT NULL,
        instrucciones  TEXT    NOT NULL DEFAULT '',
        estado         TEXT    NOT NULL,
        costo_estimado REAL    NOT NULL,
        FOREIGN KEY (paseador_id) REFERENCES $tablaPaseadores (id)
      )
    ''');

    // La llave primaria es la pareja: el mismo perro no puede aparecer dos
    // veces en el mismo paseo. ON DELETE CASCADE borra la fila si se borra la
    // reserva o el perro.
    await db.execute('''
      CREATE TABLE $tablaReservaMascotas (
        reserva_id INTEGER NOT NULL,
        mascota_id INTEGER NOT NULL,
        PRIMARY KEY (reserva_id, mascota_id),
        FOREIGN KEY (reserva_id) REFERENCES $tablaReservas (id) ON DELETE CASCADE,
        FOREIGN KEY (mascota_id) REFERENCES $tablaMascotas (id) ON DELETE CASCADE
      )
    ''');

    // Las reservas se listan siempre ordenadas por fecha. Sin indice, SQLite
    // tendria que recorrer y ordenar la tabla entera en cada consulta.
    await db.execute(
      'CREATE INDEX idx_reservas_fecha ON $tablaReservas (fecha_hora DESC)',
    );
  }

  /// Se ejecuta cuando la base del telefono es mas vieja que [_version].
  /// Cada bloque lleva la base un paso adelante, sin perder lo que ya tenia.
  Future<void> _actualizar(Database db, int anterior, int nueva) async {
    if (anterior < 2) await _crearTablaDueno(db);
    if (anterior < 3) await _migrarAVersion3(db);
    if (anterior < 4) await _agregarColumnasSeguridad(db);
  }

  Future<void> _migrarAVersion3(Database db) async {
    // 1. Habilidades: de "a|b" a JSON ["a","b"].
    final paseadores = await db.query(
      tablaPaseadores,
      columns: ['id', 'habilidades'],
    );
    for (final fila in paseadores) {
      final texto = (fila['habilidades'] as String?) ?? '';
      if (texto.startsWith('[')) continue; // ya estaba en JSON
      final lista = texto.isEmpty ? <String>[] : texto.split('|');
      await db.update(
        tablaPaseadores,
        {'habilidades': jsonEncode(lista)},
        where: 'id = ?',
        whereArgs: [fila['id']],
      );
    }

    // 2. Reservas: la columna mascota_id sale de la tabla y pasa a la tabla
    // intermedia. SQLite no permite quitar una columna en todas las versiones
    // de Android, asi que se hace la receta estandar: renombrar la vieja,
    // crear la nueva, copiar los datos y borrar la vieja.
    await db.execute('DROP INDEX IF EXISTS idx_reservas_fecha');
    await db.execute('ALTER TABLE $tablaReservas RENAME TO reservas_v2');
    await _crearTablasReservas(db);
    await db.execute('''
      INSERT INTO $tablaReservas
        (id, paseador_id, fecha_hora, duracion_min, instrucciones, estado, costo_estimado)
      SELECT id, paseador_id, fecha_hora, duracion_min, instrucciones, estado, costo_estimado
      FROM reservas_v2
    ''');
    await db.execute('''
      INSERT INTO $tablaReservaMascotas (reserva_id, mascota_id)
      SELECT id, mascota_id FROM reservas_v2
    ''');
    await db.execute('DROP TABLE reservas_v2');
  }

  /// CHECK (id = 1) hace que la tabla solo pueda tener una fila: un telefono,
  /// un dueno. Lo garantiza la base misma, no solo el codigo.
  ///
  /// IF NOT EXISTS hace que la migracion se pueda repetir sin romperse: si una
  /// actualizacion se interrumpe a medias, la tabla puede existir aunque la
  /// version no se haya guardado, y el siguiente arranque la intentaria crear
  /// otra vez.
  Future<void> _crearTablaDueno(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tablaDueno (
        id     INTEGER PRIMARY KEY CHECK (id = 1),
        nombre TEXT    NOT NULL
      )
    ''');
  }

  /// Columnas del login (version 4): el hash del PIN, su sal y si el dueno
  /// quiere entrar con huella.
  ///
  /// Antes de agregar cada columna se revisa si ya existe. Asi el paso se puede
  /// repetir sin romperse, la misma leccion que dejo la migracion a medias de
  /// la version 2.
  Future<void> _agregarColumnasSeguridad(Database db) async {
    final columnas = await db.rawQuery('PRAGMA table_info($tablaDueno)');
    final existentes = {for (final c in columnas) c['name'] as String};

    const nuevas = {
      'pin_hash': 'TEXT',
      'pin_sal': 'TEXT',
      'usa_biometria': 'INTEGER NOT NULL DEFAULT 0',
    };
    for (final MapEntry(key: nombre, value: tipo) in nuevas.entries) {
      if (!existentes.contains(nombre)) {
        await db.execute('ALTER TABLE $tablaDueno ADD COLUMN $nombre $tipo');
      }
    }
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
  // Dueno
  // ───────────────────────────────────────────────────────────────────────

  /// Devuelve null si todavia no se registro: es la primera vez que se abre.
  Future<Dueno?> leerDueno() async {
    try {
      final db = await _base;
      final filas = await db.query(tablaDueno, limit: 1);
      return filas.isEmpty ? null : Dueno.desdeMapa(filas.first);
    } catch (e) {
      throw ErrorDeDatos('No se pudo leer tu perfil.', e);
    }
  }

  /// Sirve para crear y para editar: si ya existe la fila 1, la reemplaza.
  Future<void> guardarDueno(Dueno dueno) async {
    try {
      final db = await _base;
      await db.insert(
        tablaDueno,
        dueno.aMapa(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw ErrorDeDatos('No se pudo guardar tu perfil.', e);
    }
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

  Future<void> actualizarMascota(Mascota m) async {
    try {
      final db = await _base;
      await db.update(
        tablaMascotas,
        m.aMapa()..remove('id'),
        where: 'id = ?',
        whereArgs: [m.id],
      );
    } catch (e) {
      throw ErrorDeDatos('No se pudieron guardar los cambios.', e);
    }
  }

  Future<void> borrarMascota(int id) async {
    try {
      final db = await _base;
      // Una transaccion es "todo o nada": si falla el segundo paso, el primero
      // se deshace, y nunca queda la base a medias.
      await db.transaction((txn) async {
        // Primero las reservas en las que iba este perro: es lo que el dialogo
        // de confirmacion le advierte al usuario.
        await txn.delete(
          tablaReservas,
          where:
              'id IN (SELECT reserva_id FROM $tablaReservaMascotas '
              'WHERE mascota_id = ?)',
          whereArgs: [id],
        );
        await txn.delete(tablaMascotas, where: 'id = ?', whereArgs: [id]);
      });
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
      final filas = await db.query(
        tablaPaseadores,
        orderBy: 'calificacion DESC',
      );
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
    final conDistancia =
        todos
            .map(
              (pas) => (pas, _distanciaKm(lat, lon, pas.latitud, pas.longitud)),
            )
            .toList()
          ..sort((a, b) => a.$2.compareTo(b.$2));
    return conDistancia.map((par) => par.$1).toList();
  }

  /// Distancia en kilometros entre dos coordenadas (formula de Haversine).
  ///
  /// Haversine calcula la distancia sobre la superficie de la esfera, no la
  /// linea recta que la atraviesa. Para distancias dentro de una ciudad la
  /// diferencia es minima, pero es la formula correcta.
  static double _distanciaKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const radioTierra = 6371.0;
    double aRadianes(double g) => g * math.pi / 180.0;

    final dLat = aRadianes(lat2 - lat1);
    final dLon = aRadianes(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(aRadianes(lat1)) *
            math.cos(aRadianes(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return radioTierra * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  /// Expuesta para que las pantallas muestren "a 2.3 km de ti".
  static double distanciaKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) => _distanciaKm(lat1, lon1, lat2, lon2);

  // ───────────────────────────────────────────────────────────────────────
  // Reservas
  // ───────────────────────────────────────────────────────────────────────

  /// Guarda la reserva y su lista de perros.
  ///
  /// Va en una transaccion: si se guardara la reserva y fallara la lista de
  /// perros, quedaria un paseo sin perros. Asi, o se guarda todo o nada.
  Future<Reserva> insertarReserva(Reserva r, List<Mascota> mascotas) async {
    try {
      final db = await _base;
      final id = await db.transaction((txn) async {
        final nuevoId = await txn.insert(
          tablaReservas,
          r.aMapa()..remove('id'),
        );
        for (final m in mascotas) {
          await txn.insert(tablaReservaMascotas, {
            'reserva_id': nuevoId,
            'mascota_id': m.id,
          });
        }
        return nuevoId;
      });
      return r.copiarCon(id: id);
    } catch (e) {
      throw ErrorDeDatos('No se pudo guardar la reserva.', e);
    }
  }

  /// Reservas con sus perros y su paseador ya resueltos.
  ///
  /// Son dos consultas: una trae cada reserva unida a su paseador (JOIN), y
  /// otra trae todas las parejas reserva-perro. Despues se agrupan en Dart.
  /// Consultar los perros de cada reserva una por una serian 1 + N consultas.
  Future<List<ReservaCompleta>> listarReservas() async {
    try {
      final db = await _base;

      final enlaces = await db.rawQuery('''
        SELECT rm.reserva_id, m.*
        FROM $tablaReservaMascotas rm
        JOIN $tablaMascotas m ON m.id = rm.mascota_id
        ORDER BY m.nombre
      ''');
      final perrosPorReserva = <int, List<Mascota>>{};
      for (final f in enlaces) {
        perrosPorReserva
            .putIfAbsent(f['reserva_id'] as int, () => [])
            .add(Mascota.desdeMapa(f));
      }

      final filas = await db.rawQuery('''
        SELECT
          r.*,
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
        JOIN $tablaPaseadores p ON p.id = r.paseador_id
        ORDER BY r.fecha_hora DESC
      ''');

      return filas.map((f) {
        // El prefijo p_ existe porque reservas y paseadores tienen una columna
        // con el mismo nombre (id). Sin renombrar, una pisaria a la otra.
        final reserva = Reserva.desdeMapa(f);
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
          mascotas: perrosPorReserva[reserva.id] ?? const [],
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
