import 'package:flutter/material.dart';
import '../models.dart';

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
