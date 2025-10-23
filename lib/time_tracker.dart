// lib/time_tracker.dart
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kalıcı günlük ve toplam süre sayacı.
/// - Toplam süre: Asla sıfırlanmaz.
/// - Günlük süre: Her gece 00:00'da otomatik sıfırlanır.
/// - Arka planda da devam eder, uygulama kapanınca kaldığı yerden devam eder.
class TimeTracker {
  static final TimeTracker instance = TimeTracker._();
  TimeTracker._();

  final ValueNotifier<Duration> todayNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> totalNotifier = ValueNotifier(Duration.zero);

  Duration _today = Duration.zero;
  Duration _total = Duration.zero;
  DateTime _lastDate = DateTime.now();
  Timer? _timer;
  bool _running = false;

  /// Başlatıcı
  Future<void> start() async {
    if (_running) return;
    _running = true;

    // Prefs yükle
    final prefs = await SharedPreferences.getInstance();
    final todaySecs = prefs.getInt('today_seconds') ?? 0;
    final totalSecs = prefs.getInt('total_seconds') ?? 0;
    final lastDateStr = prefs.getString('last_date');
    if (lastDateStr != null) {
      _lastDate = DateTime.tryParse(lastDateStr) ?? DateTime.now();
    }

    _today = Duration(seconds: todaySecs);
    _total = Duration(seconds: totalSecs);
    todayNotifier.value = _today;
    totalNotifier.value = _total;

    // Her saniye güncelle
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final now = DateTime.now();

      // Gün değiştiyse bugünü sıfırla
      if (now.day != _lastDate.day ||
          now.month != _lastDate.month ||
          now.year != _lastDate.year) {
        _today = Duration.zero;
        _lastDate = now;
      }

      // Sayaçları artır
      _today += const Duration(seconds: 1);
      _total += const Duration(seconds: 1);

      todayNotifier.value = _today;
      totalNotifier.value = _total;

      // Kalıcı kaydet
      await prefs.setInt('today_seconds', _today.inSeconds);
      await prefs.setInt('total_seconds', _total.inSeconds);
      await prefs.setString('last_date', _lastDate.toIso8601String());
    });
  }

  /// Manuel artış (foreground servis tarafından)
  Future<void> increment(Duration d) async {
    final prefs = await SharedPreferences.getInstance();
    _today += d;
    _total += d;
    todayNotifier.value = _today;
    totalNotifier.value = _total;
    await prefs.setInt('today_seconds', _today.inSeconds);
    await prefs.setInt('total_seconds', _total.inSeconds);
  }

  /// Durdur
  void stop() {
    _timer?.cancel();
    _running = false;
  }

  /// Format
  static String fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
