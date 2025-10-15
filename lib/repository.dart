// lib/repository.dart
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'db.dart';
import 'models.dart';

class Repository {
  final Database db;
  Repository(this.db);

  static Future<Repository> create() async =>
      Repository(await AppDatabase.instance.database);

  // Ayarları oku/yaz
  Future<AppSettings> getSettings() async {
    final rows = await db.query('settings',
        where: 'key = ?', whereArgs: ['app'], limit: 1);
    if (rows.isEmpty) {
      return AppSettings(
        dwellSeconds: 120,
        boxIntervalsMinutes: const [1440, 2880, 5760, 11520, 23040],
      );
    }
    final value = rows.first['value'] as String;
    return AppSettings.fromMap(jsonDecode(value));
  }

  Future<void> saveSettings(AppSettings s) async {
    await db.insert(
      'settings',
      {'key': 'app', 'value': jsonEncode(s.toMap())},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Kart CRUD
  Future<void> upsertCards(List<CardItem> items) async {
    final batch = db.batch();
    for (final c in items) {
      batch.insert('cards', c.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<CardItem>> getDueCards({DateTime? nowUtc}) async {
    nowUtc ??= DateTime.now().toUtc();
    final rows = await db.query(
      'cards',
      where: 'dueAt <= ?',
      whereArgs: [nowUtc.toIso8601String()],
      orderBy: 'dueAt ASC',
    );
    return rows.map((e) => CardItem.fromMap(e)).toList();
  }

  Future<List<CardItem>> getAllCards() async {
    final rows = await db.query('cards', orderBy: 'dueAt ASC');
    return rows.map((e) => CardItem.fromMap(e)).toList();
  }

  Future<void> updateCard(CardItem c) async {
    await db.update('cards', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
  }

  Future<void> deleteCard(String id) async {
    await db.delete('cards', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAll() async {
    await db.delete('cards');
  }

  // JSON içe aktar: ["url", ...] veya [{url,title,box?,dueAt?}, ...]
  Future<int> importLinksJson(String jsonSource,
      {int initialBox = 0, DateTime? startDueUtc}) async {
    final data = jsonDecode(jsonSource);
    if (data is! List) throw Exception('JSON format should be an array.');
    startDueUtc ??= DateTime.now().toUtc();

    final items = <CardItem>[];
    for (final e in data) {
      if (e is String) {
        items.add(_makeCard(url: e, title: null, dueUtc: startDueUtc!, box: initialBox));
      } else if (e is Map<String, dynamic>) {
        final url = e['url'] as String? ??
            e['link'] as String? ??
            e['href'] as String?;
        if (url == null) continue;
        final title = e['title'] as String?;
        final dueStr = e['dueAt'] as String?;
        final box = e['box'] as int? ?? initialBox;
        final dueUtc = dueStr != null
            ? DateTime.parse(dueStr).toUtc()
            : startDueUtc!;
        items.add(_makeCard(url: url, title: title, dueUtc: dueUtc, box: box));
      }
    }
    await upsertCards(items);
    return items.length;
  }

  CardItem _makeCard({
    required String url,
    String? title,
    required DateTime dueUtc,
    int box = 0,
  }) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    return CardItem(
      id: id,
      url: url,
      title: title,
      box: box,
      dueAt: dueUtc,
      lastSeenAt: null,
    );
  }

  // İlerlemeyi dışa aktar
  Future<String> exportAllJson() async {
    final items = await getAllCards();
    final list = items.map((e) => e.toMap()).toList();
    return jsonEncode({'version': 1, 'cards': list});
  }

  // LEITNER: doğru → bir üst kutu (UTC)
  Future<CardItem> markCorrect(
      CardItem c, List<int> boxIntervalsMinutes) async {
    final nextBox = (c.box + 1).clamp(0, boxIntervalsMinutes.length - 1);
    final delay = Duration(minutes: boxIntervalsMinutes[nextBox]);
    final nowUtc = DateTime.now().toUtc();
    final updated = c.copyWith(
      box: nextBox,
      lastSeenAt: nowUtc,
      dueAt: nowUtc.add(delay),
      correctCount: c.correctCount + 1,
    );
    await updateCard(updated);
    return updated;
  }

  // Elle kutuya düşür (UTC)
  Future<CardItem> forceMoveToBox(
      CardItem c, int targetBox, List<int> boxIntervalsMinutes) async {
    final idx = targetBox.clamp(0, boxIntervalsMinutes.length - 1);
    final delay = Duration(minutes: boxIntervalsMinutes[idx]);
    final nowUtc = DateTime.now().toUtc();
    final updated = c.copyWith(
      box: idx,
      lastSeenAt: nowUtc,
      dueAt: nowUtc.add(delay),
    );
    await updateCard(updated);
    return updated;
  }

  // ——— Kullanım istatistikleri ———

  /// Bir seans kullanım logu ekle (UTC)
  Future<void> addUsageLogUtc({
    required DateTime startUtc,
    required DateTime endUtc,
  }) async {
    final duration = endUtc.difference(startUtc).inSeconds;
    if (duration <= 0) return;
    await db.insert('usage_logs', {
      'startAt': startUtc.toIso8601String(),
      'endAt': endUtc.toIso8601String(),
      'durationSeconds': duration,
    });
  }

  /// Tüm zaman toplam süre (Duration)
  Future<Duration> getTotalUsage() async {
    final rows = await db.rawQuery(
        'SELECT SUM(durationSeconds) AS total FROM usage_logs');
    final secs = (rows.first['total'] as int?) ?? 0;
    return Duration(seconds: secs);
  }

  /// Bugün (cihazın yerel gününe göre) toplam süre
  Future<Duration> getTodayUsageLocal() async {
    final nowLocal = DateTime.now();
    final startLocal = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    final endLocal = startLocal.add(const Duration(days: 1));

    final startUtc = startLocal.toUtc();
    final endUtc = endLocal.toUtc();

    // Basit yaklaşım: başlangıcı bugün aralığında olan kayıtları topla
    final rows = await db.rawQuery(
      'SELECT SUM(durationSeconds) AS total FROM usage_logs '
      'WHERE startAt >= ? AND startAt < ?',
      [startUtc.toIso8601String(), endUtc.toIso8601String()],
    );
    final secs = (rows.first['total'] as int?) ?? 0;
    return Duration(seconds: secs);
  }

  // ——— Rastgele kartlar ———
  Future<CardItem?> getRandomCard() async {
    final rows = await db.rawQuery('SELECT * FROM cards ORDER BY RANDOM() LIMIT 1');
    if (rows.isEmpty) return null;
    return CardItem.fromMap(rows.first);
  }

  Future<CardItem?> getRandomCardExcept(String excludeId) async {
    final rows = await db.rawQuery(
      'SELECT * FROM cards WHERE id <> ? ORDER BY RANDOM() LIMIT 1',
      [excludeId],
    );
    if (rows.isEmpty) return null;
    return CardItem.fromMap(rows.first);
  }
}
