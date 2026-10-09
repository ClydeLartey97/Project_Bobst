import 'package:flutter/material.dart';

import '../models/floor.dart';
import '../widgets/updated_label.dart';

class OverviewScreen extends StatelessWidget {
  const OverviewScreen({
    super.key,
    required this.snapshot,
    required this.onRefresh,
  });

  final FloorsSnapshot snapshot;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final building = snapshot.building;
    final isFull = building.status == BuildingStatus.full;
    final color = isFull ? Colors.red : Colors.green;
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('BOBST IS', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      isFull ? 'FULL' : 'AVAILABLE',
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontSize: 72,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '${building.occupancy} people · '
                    '${(building.busyness * 100).round()}% full',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  UpdatedLabel(updatedAt: snapshot.updatedAt),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
