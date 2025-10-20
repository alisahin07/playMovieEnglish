import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models.dart';
import '../repository.dart';

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

  Future<void> _toggleFavorite() async {
    final current = _queue[_index];
    final newVal = !current.isFavorite;
    await _repo.toggleFavorite(current.id, newVal);
    setState(() => _queue[_index] = current.copyWith(isFavorite: newVal));
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
      await file.writeAsString('0');
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Tüm videolar tamamlandı')));
      Navigator.pop(context);
    }
  }

  Future<void> _openExternally(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _queue.length;
    final done = min(_index + 1, total);
    final f = NumberFormat('00');
    final mm = f.format((_secondsLeft ~/ 60).clamp(0, 59));
    final ss = f.format((_secondsLeft % 60).clamp(0, 59));
    final current = _queue.isNotEmpty ? _queue[_index] : null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Rastgele Tümünü Oynat ($done/$total)'),
        actions: [
          if (current != null)
            IconButton(
              icon: Icon(
                current.isFavorite ? Icons.star : Icons.star_border,
                color: current.isFavorite ? Colors.amber : Colors.grey,
              ),
              onPressed: _toggleFavorite,
            ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Kalan: $mm:$ss', style: const TextStyle(fontSize: 22)),
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
