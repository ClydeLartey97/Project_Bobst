import 'package:flutter/material.dart';

import '../models/floor.dart';

Color colorForLevel(BusynessLevel level) => switch (level) {
      BusynessLevel.quiet => Colors.green,
      BusynessLevel.moderate => Colors.orange,
      BusynessLevel.busy => Colors.red,
    };

String labelForLevel(BusynessLevel level) => switch (level) {
      BusynessLevel.quiet => 'Quiet',
      BusynessLevel.moderate => 'Moderate',
      BusynessLevel.busy => 'Busy',
    };

class FloorTile extends StatelessWidget {
  const FloorTile({super.key, required this.floor});

  final Floor floor;

  @override
  Widget build(BuildContext context) {
    final color = colorForLevel(floor.level);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(floor.name, style: theme.textTheme.titleMedium),
                ),
                Text(
                  labelForLevel(floor.level),
                  style: theme.textTheme.labelLarge?.copyWith(color: color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: floor.busyness,
                minHeight: 8,
                color: color,
                backgroundColor: color.withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(floor.busyness * 100).round()}% full',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
