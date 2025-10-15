// lib/models.dart
import 'dart:convert';

/// Klasik Leitner planı (gün): 1, 2, 4, 8, 16
/// Dakika: 1440, 2880, 5760, 11520, 23040
const List<int> kClassicLeitnerPlanMinutes = <int>[
  1440, 2880, 5760, 11520, 23040,
];

class CardItem {
  final String id;           // benzersiz id
  final String url;          // playphrase link
  final String? title;       // opsiyonel etiket
  final int box;             // 0..N-1 (Kutu 1 => 0)
  final DateTime dueAt;      // bir sonraki tekrar zamanı (UTC)
  final DateTime? lastSeenAt; // UTC
  final int correctCount;
  final int wrongCount;

  CardItem({
    required this.id,
    required this.url,
    this.title,
    required this.box,
    required this.dueAt,
    this.lastSeenAt,
    this.correctCount = 0,
    this.wrongCount = 0,
  });

  CardItem copyWith({
    String? id,
    String? url,
    String? title,
    int? box,
    DateTime? dueAt,
    DateTime? lastSeenAt,
    int? correctCount,
    int? wrongCount,
  }) {
    return CardItem(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      box: box ?? this.box,
      dueAt: dueAt ?? this.dueAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      correctCount: correctCount ?? this.correctCount,
      wrongCount: wrongCount ?? this.wrongCount,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'url': url,
        'title': title,
        'box': box,
        // Tüm zamanları UTC string olarak sakla
        'dueAt': dueAt.toUtc().toIso8601String(),
        'lastSeenAt': lastSeenAt?.toUtc().toIso8601String(),
        'correctCount': correctCount,
        'wrongCount': wrongCount,
      };

  static CardItem fromMap(Map<String, dynamic> m) => CardItem(
        id: m['id'] as String,
        url: m['url'] as String,
        title: m['title'] as String?,
        box: m['box'] as int,
        dueAt: DateTime.parse(m['dueAt'] as String).toUtc(),
        lastSeenAt: m['lastSeenAt'] == null
            ? null
            : DateTime.parse(m['lastSeenAt'] as String).toUtc(),
        correctCount: m['correctCount'] as int? ?? 0,
        wrongCount: m['wrongCount'] as int? ?? 0,
      );

  String toJson() => jsonEncode(toMap());
  static CardItem fromJson(String s) => fromMap(jsonDecode(s));
}

class AppSettings {
  /// Her linkte bekleme süresi (otomatik geçiş), saniye
  final int dwellSeconds;

  /// Leitner kutu aralıkları (dakika). Kutu 1 => index 0
  final List<int> boxIntervalsMinutes;

  AppSettings({
    required this.dwellSeconds,
    required this.boxIntervalsMinutes,
  });

  AppSettings copyWith({
    int? dwellSeconds,
    List<int>? boxIntervalsMinutes,
  }) {
    return AppSettings(
      dwellSeconds: dwellSeconds ?? this.dwellSeconds,
      boxIntervalsMinutes: boxIntervalsMinutes ?? this.boxIntervalsMinutes,
    );
  }

  Map<String, dynamic> toMap() => {
        'dwellSeconds': dwellSeconds,
        'boxIntervalsMinutes': boxIntervalsMinutes,
      };

  /// JSON’dan okurken değer yoksa klasik planı varsayılan alır
  static AppSettings fromMap(Map<String, dynamic> m) => AppSettings(
        dwellSeconds: m['dwellSeconds'] as int? ?? 120,
        boxIntervalsMinutes:
            (m['boxIntervalsMinutes'] as List?)?.cast<int>() ??
                kClassicLeitnerPlanMinutes,
      );
}
