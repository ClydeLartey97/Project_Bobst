import 'package:flutter/material.dart';

import '../models/floor.dart';
import '../widgets/floor_tile.dart';
import '../widgets/updated_label.dart';

class FloorsScreen extends StatelessWidget {
  const FloorsScreen({
    super.key,
    required this.snapshot,
    required this.onRefresh,
  });

  final FloorsSnapshot snapshot;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
            child: Text(
              'Floors',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: UpdatedLabel(updatedAt: snapshot.updatedAt),
          ),
          for (final floor in snapshot.floors) FloorTile(floor: floor),
        ],
      ),
    );
  }
}
