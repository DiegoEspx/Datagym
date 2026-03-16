import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('datagym.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, filePath);
    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    // preferences
    await db.execute('''
      CREATE TABLE preferences (
        key    TEXT PRIMARY KEY,
        value  TEXT NOT NULL
      )
    ''');

    // exercise_catalog
    await db.execute('''
      CREATE TABLE exercise_catalog (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        name             TEXT NOT NULL UNIQUE,
        name_normalized  TEXT NOT NULL
      )
    ''');

    // routines
    await db.execute('''
      CREATE TABLE routines (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        name        TEXT NOT NULL,
        created_at  TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // routine_exercises
    await db.execute('''
      CREATE TABLE routine_exercises (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        routine_id  INTEGER NOT NULL REFERENCES routines(id) ON DELETE CASCADE,
        catalog_id  INTEGER NOT NULL REFERENCES exercise_catalog(id),
        order_index INTEGER NOT NULL,
        superset_group INTEGER
      )
    ''');

    // sessions
    await db.execute('''
      CREATE TABLE sessions (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        routine_id  INTEGER REFERENCES routines(id) ON DELETE SET NULL,
        date        TEXT NOT NULL,
        created_at  TEXT NOT NULL DEFAULT (datetime('now')),
        notes       TEXT
      )
    ''');

    // session_exercises
    await db.execute('''
      CREATE TABLE session_exercises (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id   INTEGER NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
        catalog_id   INTEGER NOT NULL REFERENCES exercise_catalog(id),
        order_index  INTEGER NOT NULL,
        superset_id  INTEGER,
        notes        TEXT
      )
    ''');

    // sets
    await db.execute('''
      CREATE TABLE sets (
        id                  INTEGER PRIMARY KEY AUTOINCREMENT,
        session_exercise_id INTEGER NOT NULL REFERENCES session_exercises(id) ON DELETE CASCADE,
        session_id          INTEGER NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
        order_index         INTEGER NOT NULL,
        set_number          INTEGER NOT NULL,
        drop_index          INTEGER NOT NULL DEFAULT 0,
        weight              REAL NOT NULL,
        unit                TEXT NOT NULL DEFAULT 'kg' CHECK(unit IN ('kg', 'lb')),
        reps                INTEGER NOT NULL
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Reserved for legacy migrations from v1.
    }

    if (oldVersion < 3) {
      // Reserved for legacy migrations from v2.
    }

    if (oldVersion < 4) {
      final columns = await db.rawQuery('PRAGMA table_info(routine_exercises)');
      final hasSupersetGroup = columns.any((column) => column['name'] == 'superset_group');
      if (!hasSupersetGroup) {
        await db.execute('ALTER TABLE routine_exercises ADD COLUMN superset_group INTEGER');
      }
    }
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
