import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../modelos/paseo.dart';

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
/// Es la unica clase que habla con SQLite. Las pantallas piden paseos aqui y
/// nunca escriben SQL, igual que en el backend de Bases de Datos: una sola
/// puerta de entrada al almacenamiento.
class BaseDatos {
  BaseDatos._();

  /// Instancia unica. Abrir la base es caro y mantiene un archivo abierto, asi
  /// que se reutiliza durante toda la vida de la app.
  static final BaseDatos instancia = BaseDatos._();

  static const _archivo = 'dogtrips.db';
  static const _version = 1;
  static const tabla = 'paseos';

  Database? _db;

  Future<Database> get _base async {
    _db ??= await _abrir();
    return _db!;
  }

  Future<Database> _abrir() async {
    try {
      final ruta = p.join(await getDatabasesPath(), _archivo);
      return await openDatabase(ruta, version: _version, onCreate: _crear);
    } catch (e) {
      throw ErrorDeDatos('No se pudo abrir la base de datos local.', e);
    }
  }

  /// Se ejecuta una sola vez, cuando el archivo de la base aun no existe.
  ///
  /// Si mas adelante hiciera falta cambiar el esquema, se sube [_version] y se
  /// agrega un onUpgrade; asi las instalaciones viejas migran en vez de perder
  /// los datos.
  Future<void> _crear(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tabla (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre_perro  TEXT    NOT NULL,
        fecha         INTEGER NOT NULL,
        duracion_min  INTEGER NOT NULL,
        notas         TEXT    NOT NULL DEFAULT '',
        foto_path     TEXT,
        latitud       REAL,
        longitud      REAL
      )
    ''');
    // La lista de paseos se ordena siempre por fecha descendente. Sin indice,
    // SQLite tendria que recorrer y ordenar toda la tabla en cada consulta.
    await db.execute('CREATE INDEX idx_paseos_fecha ON $tabla (fecha DESC)');
  }

  // ───────────────────────────────────────────────────────────────────────
  // Operaciones
  // ───────────────────────────────────────────────────────────────────────

  Future<List<Paseo>> listar() async {
    try {
      final db = await _base;
      final filas = await db.query(tabla, orderBy: 'fecha DESC');
      return filas.map(Paseo.desdeMapa).toList();
    } on ErrorDeDatos {
      rethrow;
    } catch (e) {
      throw ErrorDeDatos('No se pudieron leer los paseos guardados.', e);
    }
  }

  Future<Paseo?> porId(int id) async {
    try {
      final db = await _base;
      final filas = await db.query(tabla, where: 'id = ?', whereArgs: [id], limit: 1);
      return filas.isEmpty ? null : Paseo.desdeMapa(filas.first);
    } catch (e) {
      throw ErrorDeDatos('No se pudo leer el paseo.', e);
    }
  }

  /// Inserta el paseo y devuelve una copia con el id que asigno SQLite.
  Future<Paseo> insertar(Paseo paseo) async {
    try {
      final db = await _base;
      // El mapa se manda sin el id para que AUTOINCREMENT haga su trabajo.
      final datos = paseo.aMapa()..remove('id');
      final id = await db.insert(tabla, datos);
      return paseo.copiarCon(id: id);
    } catch (e) {
      throw ErrorDeDatos('No se pudo guardar el paseo.', e);
    }
  }

  Future<void> actualizar(Paseo paseo) async {
    if (paseo.id == null) {
      throw ErrorDeDatos('No se puede actualizar un paseo que no se ha guardado.');
    }
    try {
      final db = await _base;
      await db.update(tabla, paseo.aMapa(), where: 'id = ?', whereArgs: [paseo.id]);
    } catch (e) {
      throw ErrorDeDatos('No se pudo actualizar el paseo.', e);
    }
  }

  Future<void> borrar(int id) async {
    try {
      final db = await _base;
      await db.delete(tabla, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw ErrorDeDatos('No se pudo eliminar el paseo.', e);
    }
  }

  Future<int> contar() async {
    try {
      final db = await _base;
      final r = await db.rawQuery('SELECT COUNT(*) AS n FROM $tabla');
      return Sqflite.firstIntValue(r) ?? 0;
    } catch (e) {
      throw ErrorDeDatos('No se pudo contar los paseos.', e);
    }
  }
}
