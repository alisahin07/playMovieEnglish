import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models.dart';
import '../repository.dart';
import '../time_tracker.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  late Repository _repo;
  List<CardItem> _queue = [];
  int _index = 0;
  int _secondsLeft = 0;
  Timer? _timer;
  late AppSettings _settings;
  bool _isFav = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _repo = await Repository.create();
    _settings = await _repo.getSettings();
    final prefs = await SharedPreferences.getInstance();
    final lastIndex = prefs.getInt('last_fav_index') ?? 0;
    final favs = await _repo.getFavoriteCards();

    if (favs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Favori yok')));
        Navigator.pop(context);
      }
      return;
    }

    _queue = favs;
    if (lastIndex < _queue.length) _index = lastIndex;
    _isFav = await _repo.isFavorite(_queue[_index].id);
    _openExternally(_queue[_index].url);
    _startTimer();
    setState(() => _loading = false);
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
    await prefs.setInt('last_fav_index', _index);

    if (_index < _queue.length - 1) {
      setState(() => _index++);
      _openExternally(_queue[_index].url);
      _isFav = await _repo.isFavorite(_queue[_index].id);
      _startTimer();
    } else {
      prefs.remove('last_fav_index');
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Favoriler tamamlandı')));
      Navigator.pop(context);
    }
  }

  Future<void> _toggleFavorite() async {
    await _repo.toggleFavorite(_queue[_index].id, !_isFav);
    setState(() => _isFav = !_isFav);
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
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final total = _queue.length;
    final done = (_index + 1).clamp(1, total);
    final f = NumberFormat('00');
    final mm = f.format((_secondsLeft ~/ 60).clamp(0, 59));
    final ss = f.format((_secondsLeft % 60).clamp(0, 59));
    final current = _queue[_index];

    return Scaffold(
      appBar: AppBar(
        title: Text('Favoriler ($done/$total)'),
        actions: [
          IconButton(
            icon: Icon(
              _isFav ? Icons.favorite : Icons.favorite_border,
              color: _isFav ? Colors.red : null,
            ),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(current.title ?? current.url,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Kalan: $mm:$ss'),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _next,
              icon: const Icon(Icons.skip_next),
              label: const Text('Next'),
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
    );
  }
}
