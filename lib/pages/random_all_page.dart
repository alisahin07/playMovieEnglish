import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models.dart';
import '../repository.dart';
import '../time_tracker.dart';

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
  bool _loading = true;
  bool _isFav = false;
  bool _isShuffled = false; // 🔹 Rastgele sıralama durumu

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _repo = await Repository.create();
    _settings = await _repo.getSettings();

    final prefs = await SharedPreferences.getInstance();
    final lastIndex = prefs.getInt('last_random_index') ?? 0;

    final all = await _repo.getAllCards();
    if (all.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Kart yok')));
        Navigator.pop(context);
      }
      return;
    }

    _queue = List.of(all);
    if (_isShuffled) {
      _queue.shuffle(Random());
    }

    if (lastIndex < _queue.length) _index = lastIndex;

    _isFav = await _repo.isFavorite(_queue[_index].id);
    _openExternally(_queue[_index].url);
    _startTimer();
    setState(() => _loading = false);
  }

  void _shuffleList() {
    setState(() {
      _queue.shuffle(Random());
      _index = 0;
      _isShuffled = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kartlar rastgele sıralandı')),
      );
    });
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
        await _next();
      }
    });
  }

  Future<void> _next() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_random_index', _index);

    if (_index < _queue.length - 1) {
      setState(() => _index++);
      _openExternally(_queue[_index].url);
      _isFav = await _repo.isFavorite(_queue[_index].id);
      _startTimer();
    } else {
      prefs.remove('last_random_index');
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Tüm videolar tamamlandı')));
      Navigator.pop(context);
    }
  }

  Future<void> _toggleFavorite() async {
    final current = _queue[_index];
    await _repo.toggleFavorite(current.id, !_isFav);
    setState(() => _isFav = !_isFav);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_isFav ? 'Favorilere eklendi' : 'Favorilerden çıkarıldı'),
    ));
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
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

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
                _isFav ? Icons.favorite : Icons.favorite_border,
                color: _isFav ? Colors.red : null,
              ),
              onPressed: _toggleFavorite,
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (current != null)
                Text(
                  current.title ?? current.url,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              const SizedBox(height: 8),
              Text('Kalan: $mm:$ss', style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _next,
                icon: const Icon(Icons.skip_next),
                label: const Text('Next'),
              ),
              const SizedBox(height: 16),
              // 🔹 Yeni buton: Rastgele sırala
              ElevatedButton.icon(
                onPressed: _shuffleList,
                icon: const Icon(Icons.shuffle),
                label: const Text('Rastgele Sırala'),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ValueListenableBuilder<Duration>(
                    valueListenable: TimeTracker.instance.todayNotifier,
                    builder: (_, d, __) =>
                        Chip(label: Text('Bugün: ${TimeTracker.fmt(d)}')),
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<Duration>(
                    valueListenable: TimeTracker.instance.totalNotifier,
                    builder: (_, d, __) =>
                        Chip(label: Text('Toplam: ${TimeTracker.fmt(d)}')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
