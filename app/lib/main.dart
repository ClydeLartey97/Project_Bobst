import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/api_client.dart';
import 'theme/busyness_colors.dart';

void main() {
  runApp(BobstApp(api: ApiClient()));
}

class BobstApp extends StatelessWidget {
  const BobstApp({super.key, required this.api});

  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bobst',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: nyuViolet, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: nyuViolet,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: HomeScreen(api: api),
    );
  }
}
