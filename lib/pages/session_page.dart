// lib/pages/session_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models.dart';
import '../repository.dart';

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
  late AppSettings _settings;
  DateTime? _usageStartUtc;
  bool _isFav = false;

  @override
  void initState() {
    super.initState();
    _queue = widget.initialQueue;
    _settings = widget.settings;
    _secondsLeft = _settings.dwellSeconds;
    _initRepo();
    _usageStartUtc = DateTime.now().toUtc();
    _openExternally(_current.url);
    _startTimer();
  }

  Future<void> _initRepo() async {
    _repo = await Repository.create();
    _isFav = await _repo.isFavorite(_current.id);
    setState(() {});
  }

  CardItem get _current => _queue[_index];

  void _startTimer() {
    _timer?.cancel();
    _secondsLeft = _settings.dwellSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        FlutterRingtonePlayer().playNotification();
        t.cancel();
        await _advance();
      }
    });
  }

  Future<void> _advance() async {
    if (_index < _queue.length - 1) {
      setState(() => _index++);
      _openExternally(_current.url);
      _isFav = await _repo.isFavorite(_current.id);
      _startTimer();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Seans bitti')));
      Navigator.pop(context);
    }
  }

  Future<void> _toggleFavorite() async {
    await _repo.toggleFavorite(_current.id, !_isFav);
    _isFav = !_isFav;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_isFav ? 'Favorilere eklendi' : 'Favoriden çıkarıldı'),
    ));
  }

  Future<void> _openExternally(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = NumberFormat('00');
    final mm = f.format((_secondsLeft ~/ 60).clamp(0, 59));
    final ss = f.format((_secondsLeft % 60).clamp(0, 59));

    return Scaffold(
      appBar: AppBar(
        title: Text('Seans ${_index + 1}/${_queue.length}'),
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
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_current.title ?? _current.url,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('Kalan: $mm:$ss'),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _advance,
                icon: const Icon(Icons.skip_next),
                label: const Text('Next'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
