import 'package:flutter/material.dart';

import 'screens/floors_screen.dart';
import 'services/api_client.dart';

void main() {
  runApp(BobstApp(api: ApiClient()));
}

class BobstApp extends StatelessWidget {
  const BobstApp({super.key, required this.api});

  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bobst Busyness',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF57068C), // NYU violet
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF57068C),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: FloorsScreen(api: api),
    );
  }
}
