import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../time_tracker.dart';
import '../fg_service.dart';
import '../models.dart';
import '../repository.dart' as repo;
import 'settings_page.dart';
import 'session_page.dart';
import 'random_all_page.dart';
import 'favorites_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<repo.Repository> _repoFut;
  AppSettings? _settings;
  List<CardItem> _all = [];
  Duration _today = Duration.zero;
  Duration _total = Duration.zero;

  @override
  void initState() {
    super.initState();
    _repoFut = repo.Repository.create();
    TimeTracker.instance.start();
    startForegroundLeitnerLoop();
    _load();
  }

  String _fmtDur(Duration d) =>
      '${d.inHours}:${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  Future<void> _load() async {
    final r = await _repoFut;
    final settings = await r.getSettings();
    final all = await r.getAllCards();
    final today = await r.getTodayUsageLocal();
    final total = await r.getTotalUsage();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _all = all;
      _today = today;
      _total = total;
    });
  }

  Future<void> _pickJsonAndImport() async {
    final r = await _repoFut;
    final res = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    if (res == null || res.files.single.path == null) return;
    final path = res.files.single.path!;
    final content = await File(path).readAsString();
    final count = await r.importLinksJson(content);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Imported $count links')));
    await _load();
  }

  Future<void> _exportProgress() async {
    final r = await _repoFut;
    final jsonStr = await r.exportAllJson();
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/leitner_export_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(jsonStr);
    await Share.shareXFiles([XFile(file.path)], text: 'Leitner export');
  }

  void _openSettings() async {
    final r = await _repoFut;
    final s = await r.getSettings();
    if (!mounted) return;
    final updated = await Navigator.push<AppSettings>(
      context,
      MaterialPageRoute(builder: (_) => SettingsPage(settings: s)),
    );
    if (updated != null) {
      await r.saveSettings(updated);
      await _load();
    }
  }

  void _startSession() async {
    final r = await _repoFut;
    final due = await r.getDueCards();
    if (!mounted) return;
    if (due.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No cards due now.')));
      return;
    }
    final s = await r.getSettings();
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => SessionPage(initialQueue: due, settings: s)),
    );
    await _load();
  }

  void _startRandomAll() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RandomAllPage()),
    );
    await _load();
  }

  void _openFavorites() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FavoritesPage()),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = _settings;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leitner Player'),
        actions: [
          IconButton(
            icon: const Icon(Icons.star, color: Colors.amber),
            tooltip: 'Favoriler',
            onPressed: _openFavorites,
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          ElevatedButton.icon(
                              onPressed: _pickJsonAndImport,
                              icon: const Icon(Icons.upload_file),
                              label: const Text('JSON Yükle')),
                          ElevatedButton.icon(
                              onPressed: _exportProgress,
                              icon: const Icon(Icons.ios_share),
                              label: const Text('İlerlemeyi Dışa Aktar')),
                          ElevatedButton.icon(
                              onPressed: _openSettings,
                              icon: const Icon(Icons.settings),
                              label: const Text('Ayarlar')),
                          OutlinedButton.icon(
                              onPressed: _startSession,
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Seansa Başla')),
                          OutlinedButton.icon(
                              onPressed: _startRandomAll,
                              icon: const Icon(Icons.play_circle),
                              label: const Text('Rastgele Tümünü Oynat')),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              minimumSize:
                              Size(constraints.maxWidth * 0.9, 45),
                            ),
                            onPressed: () => TimeTracker.instance.start(),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Zaman Sayacını Başlat'),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              minimumSize:
                              Size(constraints.maxWidth * 0.9, 45),
                            ),
                            onPressed: () {
                              TimeTracker.instance.stop();
                              stopForegroundLeitnerLoop();
                            },
                            icon: const Icon(Icons.stop_circle),
                            label: const Text('Zaman Sayacını Durdur'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (s != null)
                        Text(
                          'Kutu aralıkları (dk): ${s.boxIntervalsMinutes.join(', ')} | Bekleme: ${s.dwellSeconds}s',
                          style: const TextStyle(fontSize: 13),
                        ),
                      const SizedBox(height: 8),
                      Text('Toplam kart: ${_all.length}'),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ValueListenableBuilder<Duration>(
                            valueListenable: TimeTracker.instance.todayNotifier,
                            builder: (_, d, __) => Chip(
                                label:
                                Text('Bugün: ${TimeTracker.fmt(d)}')),
                          ),
                          const SizedBox(width: 8),
                          ValueListenableBuilder<Duration>(
                            valueListenable: TimeTracker.instance.totalNotifier,
                            builder: (_, d, __) => Chip(
                                label:
                                Text('Toplam: ${TimeTracker.fmt(d)}')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
