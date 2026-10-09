import 'dart:async';

import 'package:flutter/material.dart';

import '../models/floor.dart';
import '../services/api_client.dart';
import '../widgets/floor_tile.dart';

class FloorsScreen extends StatefulWidget {
  const FloorsScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<FloorsScreen> createState() => _FloorsScreenState();
}

class _FloorsScreenState extends State<FloorsScreen> {
  FloorsSnapshot? _snapshot;
  Object? _error;
  Timer? _timer;

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
      appBar: AppBar(title: const Text('Bobst Busyness')),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    final snapshot = _snapshot;

    if (snapshot == null && _error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.cloud_off, size: 48),
          const SizedBox(height: 12),
          const Text("Couldn't reach the server.", textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Center(
            child: FilledButton(onPressed: _load, child: const Text('Retry')),
          ),
        ],
      );
    }
    if (snapshot == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final updated = TimeOfDay.fromDateTime(snapshot.updatedAt.toLocal());
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            'Updated ${updated.format(context)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        for (final floor in snapshot.floors) FloorTile(floor: floor),
      ],
    );
  }
}
