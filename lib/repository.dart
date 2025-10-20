// lib/repository.dart
import 'dart:convert';
import 'package:sqflite/sqflite.dart';

import 'db.dart';
import 'models.dart';

class Repository {
  final Database _db;
  Repository._(this._db);

  static Future<Repository> create() async {
    final db = await AppDatabase.instance.database;
    final repo = Repository._(db);
    await repo._ensureFavoriteColumn(); // yoksa ekle
    return repo;
  }

  // ---------------- SETTINGS ----------------
  Future<AppSettings> getSettings() async {
    final rows =
    await _db.query('settings', where: 'key = ?', whereArgs: ['app']);
    if (rows.isEmpty) {
      final def = AppSettings.defaults();
      await saveSettings(def);
      return def;
    }
    final json = jsonDecode(rows.first['value'] as String) as Map<String, dynamic>;
    return AppSettings.fromJson(json);
  }

  Future<void> saveSettings(AppSettings s) async {
    await _db.insert(
      'settings',
      {'key': 'app', 'value': jsonEncode(s.toJson())},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ---------------- CARDS ----------------
  Future<List<CardItem>> getAllCards() async {
    final maps = await _db.query('cards');
    return maps.map(CardItem.fromMap).toList();
  }

  Future<List<CardItem>> getDueCards({DateTime? nowUtc}) async {
    nowUtc ??= DateTime.now().toUtc();
    final maps = await _db.query(
      'cards',
      where: 'dueAt <= ?',
      whereArgs: [nowUtc.toIso8601String()],
    );
    return maps.map(CardItem.fromMap).toList();
  }

  Future<CardItem?> getRandomCard() async {
    final maps = await _db
        .rawQuery('SELECT * FROM cards ORDER BY RANDOM() LIMIT 1');
    if (maps.isEmpty) return null;
    return CardItem.fromMap(maps.first);
  }

  Future<CardItem?> getRandomCardExcept(String excludeId) async {
    final maps = await _db.rawQuery(
      'SELECT * FROM cards WHERE id != ? ORDER BY RANDOM() LIMIT 1',
      [excludeId],
    );
    if (maps.isEmpty) return null;
    return CardItem.fromMap(maps.first);
  }

  Future<int> importLinksJson(String jsonStr) async {
    final List<dynamic> data = jsonDecode(jsonStr);
    int count = 0;
    final batch = _db.batch();

    for (final item in data) {
      if (item is! Map) continue;
      final id = (item['id'] ?? item['url'])?.toString();
      final url = item['url']?.toString();
      if (id == null || url == null) continue;

      final title = item['title']?.toString();
      final now = DateTime.now().toUtc().toIso8601String();

      batch.insert(
        'cards',
        {
          'id': id,
          'url': url,
          'title': title,
          'box': 1,
          'dueAt': now,
          'lastSeenAt': null,
          'correctCount': 0,
          'wrongCount': 0,
          'isFavorite': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      count++;
    }

    await batch.commit(noResult: true);
    return count;
  }

  Future<String> exportAllJson() async {
    final maps = await _db.query('cards');
    return jsonEncode(maps);
  }

  // ---------------- LEITNER ----------------
  Future<CardItem> markCorrect(
      CardItem c, List<int> boxIntervalsMinutes) async {
    final nextBox = (c.box + 1).clamp(1, boxIntervalsMinutes.length);
    final due = DateTime.now()
        .toUtc()
        .add(Duration(minutes: boxIntervalsMinutes[nextBox - 1]));

    final updated = c.copyWith(
      box: nextBox,
      dueAt: due,
      lastSeenAt: DateTime.now().toUtc(),
      correctCount: c.correctCount + 1,
    );

    await _db.update(
      'cards',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [c.id],
    );
    return updated;
  }

  Future<CardItem> moveToBox1(CardItem c, List<int> boxIntervalsMinutes) async {
    final due = DateTime.now()
        .toUtc()
        .add(Duration(minutes: boxIntervalsMinutes[0]));
    final updated = c.copyWith(
      box: 1,
      dueAt: due,
      lastSeenAt: DateTime.now().toUtc(),
      wrongCount: c.wrongCount + 1,
    );
    await _db.update(
      'cards',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [c.id],
    );
    return updated;
  }

  // ---------------- USAGE LOGS ----------------
  Future<void> addUsageLogUtc({
    required DateTime startUtc,
    required DateTime endUtc,
  }) async {
    final durSec = endUtc.difference(startUtc).inSeconds;
    await _db.insert('usage_logs', {
      'startAt': startUtc.toIso8601String(),
      'endAt': endUtc.toIso8601String(),
      'durationSeconds': durSec,
    });
  }

  Future<Duration> getTodayUsageLocal() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    final rows = await _db.query(
      'usage_logs',
      where: 'startAt >= ? AND startAt < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
    );
    final totalSec = rows.fold<int>(
        0, (sum, r) => sum + ((r['durationSeconds'] as int?) ?? 0));
    return Duration(seconds: totalSec);
  }

  Future<Duration> getTotalUsage() async {
    final rows =
    await _db.rawQuery('SELECT SUM(durationSeconds) AS s FROM usage_logs');
    final s = rows.first['s'] as int?;
    return Duration(seconds: s ?? 0);
  }

  // ---------------- FAVORITES ----------------
  Future<void> toggleFavorite(String id, bool isFav) async {
    await _db.update(
      'cards',
      {'isFavorite': isFav ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<bool> isFavorite(String id) async {
    final res = await _db.query('cards',
        columns: ['isFavorite'], where: 'id = ?', whereArgs: [id]);
    if (res.isEmpty) return false;
    return (res.first['isFavorite'] ?? 0) == 1;
  }

  Future<List<CardItem>> getFavoriteCards() async {
    final maps = await _db.query('cards', where: 'isFavorite = 1');
    return maps.map(CardItem.fromMap).toList();
  }

  // ---------------- MIGRATION HELPERS ----------------
  Future<void> _ensureFavoriteColumn() async {
    final info = await _db.rawQuery('PRAGMA table_info(cards)');
    final exists = info.any((c) => c['name'] == 'isFavorite');
    if (!exists) {
      await _db
          .execute('ALTER TABLE cards ADD COLUMN isFavorite INTEGER DEFAULT 0;');
    }
  }
}
