// lib/fg_service.dart
import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

import 'models.dart';
import 'repository.dart';

/// ---- Servis bildirimi (sessiz) için kanal sabitleri ----
const String kFgChannelId = 'leitner_timer';
const String kFgChannelName = 'Leitner Sayaç';
const String kFgChannelDesc =
    'Arka planda çalışan sessiz sayaç servisi (Leitner döngüsü)';

/// Foreground servis + periyodik tetik kurulumu
Future<void> startForegroundLeitnerLoop() async {
  // Pil optimizasyonu kapatma isteği
  if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
    await FlutterForegroundTask.requestIgnoreBatteryOptimization();
  }

  // Servis yapılandırması
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: kFgChannelId,
      channelName: kFgChannelName,
      channelDescription: kFgChannelDesc,
      onlyAlertOnce: true,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: false,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(1000),
      autoRunOnBoot: false,
      autoRunOnMyPackageReplaced: false,
      allowWakeLock: true,
      allowWifiLock: true,
    ),

  );

  if (await FlutterForegroundTask.isRunningService) {
    await FlutterForegroundTask.restartService();
  } else {
    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'Leitner çalışma',
      notificationText: 'Sayaç arka planda çalışıyor',
      notificationButtons: const [
        NotificationButton(id: 'stop', text: 'Durdur'),
      ],
      callback: _startCallback,
    );
  }
}

Future<void> stopForegroundLeitnerLoop() =>
    FlutterForegroundTask.stopService();

@pragma('vm:entry-point')
void _startCallback() {
  FlutterForegroundTask.setTaskHandler(_LeitnerTaskHandler());
}

/// TaskHandler — sayaç ve otomatik geçiş mekanizması
class _LeitnerTaskHandler extends TaskHandler {
  Repository? _repo;
  AppSettings? _settings;
  CardItem? _current;
  DateTime? _targetUtc;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _repo = await Repository.create();
    _settings = await _repo!.getSettings();

    // İlk kartı bul
    final due = await _repo!.getDueCards();
    if (due.isNotEmpty) {
      _current = due.first;
    } else {
      _current = await _repo!.getRandomCard();
    }

    if (_current != null && _settings != null) {
      _targetUtc = DateTime.now()
          .toUtc()
          .add(Duration(seconds: _settings!.dwellSeconds));
    }
  }

  // Her 1 saniyede bir tetiklenir
  @override
  void onRepeatEvent(DateTime timestamp) {
    if (_current == null || _targetUtc == null || _settings == null) return;

    final now = DateTime.now().toUtc();
    if (!now.isBefore(_targetUtc!)) {
      _onCycleElapsed(now);
    }
  }

  Future<void> _onCycleElapsed(DateTime nowUtc) async {
    // Sesli bildirim
    try {
      FlutterRingtonePlayer().playNotification();
    } catch (_) {}

    if (_repo == null || _settings == null) return;

    final due = await _repo!.getDueCards();
    if (due.isNotEmpty) {
      // sıradaki due kartı işaretle
      final updated =
      await _repo!.markCorrect(due.first, _settings!.boxIntervalsMinutes);
      _current = updated;
    } else {
      // due yoksa rastgele başka kart seç
      _current = await _repo!.getRandomCardExcept(_current!.id) ??
          await _repo!.getRandomCard();
    }

    // yeni hedef zamanı belirle
    _targetUtc =
        nowUtc.add(Duration(seconds: _settings!.dwellSeconds));
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'stop') {
      FlutterForegroundTask.stopService();
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onNotificationPressed() {}
  @override
  void onNotificationDismissed() {}
  @override
  void onReceiveData(Object data) {}
}
