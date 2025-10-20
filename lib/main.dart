import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'fg_service.dart';
import 'models.dart';
import 'repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LeitnerApp());
}

class LeitnerApp extends StatelessWidget {
  const LeitnerApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Leitner Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<Repository> _repoFut;
  AppSettings? _settings;
  List<CardItem> _all = [];
  Duration _today = Duration.zero;
  Duration _total = Duration.zero;

  @override
  void initState() {
    super.initState();
    _repoFut = Repository.create();
    _load();
  }

  String _fmtDur(Duration d) =>
      '${d.inHours}:${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  Future<void> _load() async {
    final repo = await _repoFut;
    final settings = await repo.getSettings();
    final all = await repo.getAllCards();
    final today = await repo.getTodayUsageLocal();
    final total = await repo.getTotalUsage();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _all = all;
      _today = today;
      _total = total;
    });
  }

  Future<void> _pickJsonAndImport() async {
    final repo = await _repoFut;
    final res = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    if (res == null || res.files.single.path == null) return;
    final path = res.files.single.path!;
    final content = await File(path).readAsString();
    final count = await repo.importLinksJson(content);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Imported $count links')));
    await _load();
  }

  Future<void> _exportProgress() async {
    final repo = await _repoFut;
    final jsonStr = await repo.exportAllJson();
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/leitner_export_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(jsonStr);
    await Share.shareXFiles([XFile(file.path)], text: 'Leitner export');
  }

  void _openSettings() async {
    final repo = await _repoFut;
    final s = await repo.getSettings();
    if (!mounted) return;
    final updated = await Navigator.push<AppSettings>(
      context,
      MaterialPageRoute(builder: (_) => SettingsPage(settings: s)),
    );
    if (updated != null) {
      await repo.saveSettings(updated);
      await _load();
    }
  }

  void _startSession() async {
    final repo = await _repoFut;
    final due = await repo.getDueCards();
    if (!mounted) return;
    if (due.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No cards due now.')));
      return;
    }
    final s = await repo.getSettings();
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

  @override
  Widget build(BuildContext context) {
    final s = _settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Leitner Player')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
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
                ],
              ),
              const SizedBox(height: 16),
              if (s != null)
                Text(
                    'Kutu aralıkları (dk): ${s.boxIntervalsMinutes.join(', ')} | Bekleme: ${s.dwellSeconds}s'),
              const SizedBox(height: 8),
              Text('Toplam kart: ${_all.length}'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Chip(label: Text('Bugün: ${_fmtDur(_today)}')),
                  const SizedBox(width: 8),
                  Chip(label: Text('Toplam: ${_fmtDur(_total)}')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- SETTINGS PAGE ----------------
class SettingsPage extends StatefulWidget {
  final AppSettings settings;
  const SettingsPage({super.key, required this.settings});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _dwell;
  late List<int> _plan;

  @override
  void initState() {
    super.initState();
    _dwell =
        TextEditingController(text: widget.settings.dwellSeconds.toString());
    _plan = List<int>.from(widget.settings.boxIntervalsMinutes);
  }

  void _save() {
    final dwell = int.tryParse(_dwell.text.trim());
    if (dwell == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geçerli bekleme süresi girin')));
      return;
    }
    Navigator.pop(
        context, AppSettings(dwellSeconds: dwell, boxIntervalsMinutes: _plan));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(
              controller: _dwell,
              keyboardType: TextInputType.number,
              decoration:
              const InputDecoration(labelText: 'Bekleme süresi (sn)')),
          const Spacer(),
          ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Kaydet')),
        ]),
      ),
    );
  }
}

// ---------------- SESSION PAGE ----------------
class SessionPage extends StatefulWidget {
  final List<CardItem> initialQueue;
  final AppSettings settings;
  const SessionPage({super.key, required this.initialQueue, required this.settings});
  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> {
  late Repository _repo;
  late List<CardItem> _queue;
  int _index = 0;
  int _secondsLeft = 0;
  Timer? _timer;
  Duration _today = Duration.zero;
  Duration _total = Duration.zero;
  late DateTime _startTime;

  @override
  void initState() {
    super.initState();
    _queue = widget.initialQueue;
    _secondsLeft = widget.settings.dwellSeconds;
    _startTime = DateTime.now();
    _initRepo();
    _openExternally(_current.url);
    _startTimer();
    _updateUsage();
  }

  Future<void> _initRepo() async {
    _repo = await Repository.create();
    await _updateUsage();
  }

  Future<void> _updateUsage() async {
    final today = await _repo.getTodayUsageLocal();
    final total = await _repo.getTotalUsage();
    if (mounted) {
      setState(() {
        _today = today;
        _total = total;
      });
    }
  }

  CardItem get _current => _queue[_index];

  void _startTimer() {
    _timer?.cancel();
    _secondsLeft = widget.settings.dwellSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        FlutterRingtonePlayer().playNotification();
        t.cancel();
        await _nextCard();
      }
    });
  }

  Future<void> _nextCard() async {
    final updated =
    await _repo.markCorrect(_current, widget.settings.boxIntervalsMinutes);
    _queue[_index] = updated;

    if (_index < _queue.length - 1) {
      setState(() => _index++);
      _openExternally(_current.url);
      _startTimer();
    } else {
      final end = DateTime.now();
      await _repo.addUsageLogUtc(
          startUtc: _startTime.toUtc(), endUtc: end.toUtc());
      Navigator.pop(context);
    }
    await _updateUsage();
  }

  Future<void> _openExternally(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() {
    final end = DateTime.now();
    _repo.addUsageLogUtc(startUtc: _startTime.toUtc(), endUtc: end.toUtc());
    _timer?.cancel();
    super.dispose();
  }

  String _fmtDur(Duration d) =>
      '${d.inHours}:${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final f = NumberFormat('00');
    final mm = f.format((_secondsLeft ~/ 60).clamp(0, 59));
    final ss = f.format((_secondsLeft % 60).clamp(0, 59));
    return Scaffold(
      appBar: AppBar(title: Text('Seans ${_index + 1}/${_queue.length}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Kalan: $mm:$ss', style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Chip(label: Text('Bugün: ${_fmtDur(_today)}')),
                const SizedBox(width: 8),
                Chip(label: Text('Toplam: ${_fmtDur(_total)}')),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _nextCard,
              icon: const Icon(Icons.skip_next),
              label: const Text('Next'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- RANDOM ALL PAGE ----------------
class RandomAllPage extends StatefulWidget {
  const RandomAllPage({super.key});
  @override
  State<RandomAllPage> createState() => _RandomAllPageState();
}

class _RandomAllPageState extends State<RandomAllPage> {
  late Repository _repo;
  List<CardItem> _queue = [];
  int _index = 0;
  int _secondsLeft = 0;
  Timer? _timer;
  late AppSettings _settings;
  Duration _today = Duration.zero;
  Duration _total = Duration.zero;
  late DateTime _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _init();
  }

  Future<void> _init() async {
    _repo = await Repository.create();
    _settings = await _repo.getSettings();
    await _updateUsage();
    final all = await _repo.getAllCards();
    if (all.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Kart bulunamadı')));
      Navigator.pop(context);
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/random_all_index.txt');
    if (await file.exists()) {
      _index = int.tryParse(await file.readAsString()) ?? 0;
    }
    if (_index >= all.length) _index = 0;
    _queue = List.of(all)..shuffle(Random());
    _openExternally(_queue[_index].url);
    _startTimer();
  }

  Future<void> _updateUsage() async {
    final today = await _repo.getTodayUsageLocal();
    final total = await _repo.getTotalUsage();
    if (mounted) {
      setState(() {
        _today = today;
        _total = total;
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsLeft = _settings.dwellSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        FlutterRingtonePlayer().playNotification();
        t.cancel();
        await _nextCard();
      }
    });
  }

  Future<void> _nextCard() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/random_all_index.txt');
    await file.writeAsString((_index + 1).toString());

    if (_index < _queue.length - 1) {
      setState(() => _index++);
      _openExternally(_queue[_index].url);
      _startTimer();
    } else {
      final end = DateTime.now();
      await _repo.addUsageLogUtc(
          startUtc: _startTime.toUtc(), endUtc: end.toUtc());
      await file.writeAsString('0');
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Tüm videolar tamamlandı')));
      Navigator.pop(context);
    }
    await _updateUsage();
  }

  Future<void> _openExternally(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() {
    final end = DateTime.now();
    _repo.addUsageLogUtc(startUtc: _startTime.toUtc(), endUtc: end.toUtc());
    _timer?.cancel();
    super.dispose();
  }

  String _fmtDur(Duration d) =>
      '${d.inHours}:${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final totalCards = _queue.length;
    final done = min(_index + 1, totalCards);
    return Scaffold(
      appBar: AppBar(title: Text('Rastgele Tümünü Oynat ($done/$totalCards)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Kalan süre: $_secondsLeft sn', style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Chip(label: Text('Bugün: ${_fmtDur(_today)}')),
                const SizedBox(width: 8),
                Chip(label: Text('Toplam: ${_fmtDur(_total)}')),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _nextCard,
              icon: const Icon(Icons.skip_next),
              label: const Text('Next'),
            ),
          ],
        ),
      ),
    );
  }
}
