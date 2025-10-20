// lib/models.dart
import 'dart:convert';

class AppSettings {
  final int dwellSeconds; // her linkte beklenen süre (saniye)
  final List<int> boxIntervalsMinutes; // Kutu 1..5 tekrar aralıkları (dakika)

  const AppSettings({
    required this.dwellSeconds,
    required this.boxIntervalsMinutes,
  });

  factory AppSettings.defaults() => const AppSettings(
    dwellSeconds: 120,
    // Klasik plan: 1g, 2g, 4g, 8g, 16g (dakika cinsinden)
    boxIntervalsMinutes: [1440, 2880, 5760, 11520, 23040],
  );

  AppSettings copyWith({
    int? dwellSeconds,
    List<int>? boxIntervalsMinutes,
  }) {
    return AppSettings(
      dwellSeconds: dwellSeconds ?? this.dwellSeconds,
      boxIntervalsMinutes: boxIntervalsMinutes ?? this.boxIntervalsMinutes,
    );
  }

  Map<String, dynamic> toJson() => {
    'dwellSeconds': dwellSeconds,
    'boxIntervalsMinutes': boxIntervalsMinutes,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      dwellSeconds: json['dwellSeconds'] as int? ?? 120,
      boxIntervalsMinutes:
      (json['boxIntervalsMinutes'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList() ??
          [1440, 2880, 5760, 11520, 23040],
    );
  }

  @override
  String toString() => jsonEncode(toJson());
}

class CardItem {
  final String id;
  final String url;
  final String? title;

  /// 1..5 arası kutu
  final int box;

  /// bir sonraki çalışma zamanı (UTC ISO-8601 saklanır)
  final DateTime dueAt;

  /// en son görüldüğü (UTC), opsiyonel
  final DateTime? lastSeenAt;

  final int correctCount;
  final int wrongCount;

  /// Favori işareti (DB’de INTEGER 0/1)
  final bool isFavorite;

  const CardItem({
    required this.id,
    required this.url,
    required this.title,
    required this.box,
    required this.dueAt,
    required this.lastSeenAt,
    required this.correctCount,
    required this.wrongCount,
    required this.isFavorite,
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
    bool? isFavorite,
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
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'title': title,
      'box': box,
      'dueAt': dueAt.toIso8601String(),
      'lastSeenAt': lastSeenAt?.toIso8601String(),
      'correctCount': correctCount,
      'wrongCount': wrongCount,
      'isFavorite': isFavorite ? 1 : 0,
    };
  }

  factory CardItem.fromMap(Map<String, dynamic> m) {
    // sqflite bazı alanları int/dynamic döndürebilir; güvenli parse edelim
    String _s(dynamic v) => v?.toString() ?? '';
    int _i(dynamic v, [int d = 0]) =>
        v is int ? v : int.tryParse(v?.toString() ?? '') ?? d;

    DateTime _dt(dynamic v) {
      final s = v?.toString();
      if (s == null || s.isEmpty) return DateTime.now().toUtc();
      return DateTime.tryParse(s)?.toUtc() ?? DateTime.now().toUtc();
    }

    DateTime? _dtN(dynamic v) {
      final s = v?.toString();
      if (s == null || s.isEmpty) return null;
      return DateTime.tryParse(s)?.toUtc();
    }

    return CardItem(
      id: _s(m['id']),
      url: _s(m['url']),
      title: m['title']?.toString(),
      box: _i(m['box'], 1).clamp(1, 5),
      dueAt: _dt(m['dueAt']),
      lastSeenAt: _dtN(m['lastSeenAt']),
      correctCount: _i(m['correctCount'], 0),
      wrongCount: _i(m['wrongCount'], 0),
      isFavorite: _i(m['isFavorite'], 0) == 1,
    );
  }
}
