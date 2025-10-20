import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._();
  AppDatabase._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final String path = p.join(dir.path, 'leitner_player.db');
    return openDatabase(
      path,
      version: 3, // v3: favoriler sütunu eklendi
      onCreate: (db, version) async {
        await _createV1(db);
        await _migrateToV2(db);
        await _migrateToV3(db);
      },
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) await _migrateToV2(db);
        if (oldV < 3) await _migrateToV3(db);
      },
    );
  }

  Future<void> _createV1(Database db) async {
    await db.execute('''
      CREATE TABLE cards (
        id TEXT PRIMARY KEY,
        url TEXT NOT NULL,
        title TEXT,
        box INTEGER NOT NULL,
        dueAt TEXT NOT NULL,
        lastSeenAt TEXT,
        correctCount INTEGER NOT NULL DEFAULT 0,
        wrongCount INTEGER NOT NULL DEFAULT 0
      );
    ''');
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');
    await db.insert('settings', {
      'key': 'app',
      'value':
      '{"dwellSeconds":120,"boxIntervalsMinutes":[1440,2880,5760,11520,23040]}'
    });
  }

  Future<void> _migrateToV2(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS usage_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        startAt TEXT NOT NULL,
        endAt TEXT NOT NULL,
        durationSeconds INTEGER NOT NULL
      );
    ''');
  }

  Future<void> _migrateToV3(Database db) async {
    await db.execute('ALTER TABLE cards ADD COLUMN isFavorite INTEGER NOT NULL DEFAULT 0;');
  }
}
