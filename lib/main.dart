import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'time_tracker.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  TimeTracker.instance.start();
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
