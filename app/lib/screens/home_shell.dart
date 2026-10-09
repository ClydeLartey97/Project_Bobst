import 'dart:async';

import 'package:flutter/material.dart';

import '../models/floor.dart';
import '../services/api_client.dart';
import 'floors_screen.dart';
import 'overview_screen.dart';

/// Owns the data and the tab bar; both tabs render the same snapshot.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.api});

  final ApiClient api;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  FloorsSnapshot? _snapshot;
  Object? _error;
  Timer? _timer;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final snapshot = await widget.api.fetchFloors();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _buildBody()),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.layers_outlined),
            selectedIcon: Icon(Icons.layers),
            label: 'Floors',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final snapshot = _snapshot;

    if (snapshot == null && _error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48),
            const SizedBox(height: 12),
            const Text("Couldn't reach the server."),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (snapshot == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return switch (_tab) {
      0 => OverviewScreen(snapshot: snapshot, onRefresh: _load),
      _ => FloorsScreen(snapshot: snapshot, onRefresh: _load),
    };
  }
}
