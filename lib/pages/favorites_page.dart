// lib/pages/favorites_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models.dart';
import '../repository.dart';

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

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _repo = await Repository.create();
    _settings = await _repo.getSettings();
    final favs = await _repo.getFavoriteCards();
    if (favs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Favori link yok')),
        );
        Navigator.pop(context);
      }
      return;
    }
    _queue = favs;
    _openExternally(_queue[_index].url);
    _startTimer();
    _isFav = await _repo.isFavorite(_queue[_index].id);
    setState(() {});
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
    if (_index < _queue.length - 1) {
      setState(() => _index++);
      _openExternally(_queue[_index].url);
      _isFav = await _repo.isFavorite(_queue[_index].id);
      _startTimer();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Favoriler tamamlandı')),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _toggleFavorite() async {
    await _repo.toggleFavorite(_queue[_index].id, !_isFav);
    _isFav = !_isFav;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:
      Text(_isFav ? 'Favorilere eklendi' : 'Favorilerden çıkarıldı'),
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
    final total = _queue.length;
    final done = total > 0 ? (_index + 1).clamp(1, total) : 0;
    final f = NumberFormat('00');
    final mm = f.format((_secondsLeft ~/ 60).clamp(0, 59));
    final ss = f.format((_secondsLeft % 60).clamp(0, 59));
    final current = _queue.isEmpty ? null : _queue[_index];

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
      body: current == null
          ? const Center(child: CircularProgressIndicator())
          : Center(
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
          ],
        ),
      ),
    );
  }
}
