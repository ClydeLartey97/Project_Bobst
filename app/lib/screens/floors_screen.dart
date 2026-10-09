import 'package:flutter/material.dart';

import '../models/bobst.dart';
import '../widgets/busyness_pill.dart';
import '../widgets/updated_label.dart';

class FloorsScreen extends StatelessWidget {
  const FloorsScreen({
    super.key,
    required this.status,
    required this.onRefresh,
  });

  final BobstStatus status;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        // Bottom padding keeps the last floor clear of the floating tab bar.
        padding: EdgeInsets.fromLTRB(
          16,
          MediaQuery.paddingOf(context).top + 16,
          16,
          120,
        ),
        children: [
          Text(
            'Floors',
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          UpdatedLabel(updatedAt: status.updatedAt),
          const SizedBox(height: 16),
          for (final floor in status.floors) FloorCard(floor: floor),
        ],
      ),
    );
  }
}

class FloorCard extends StatefulWidget {
  const FloorCard({super.key, required this.floor});

  final Floor floor;

  @override
  State<FloorCard> createState() => _FloorCardState();
}

class _FloorCardState extends State<FloorCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final floor = widget.floor;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          floor.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          floor.noise.label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${floor.occupancy}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('people', style: theme.textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 10),
              FullnessBar(fullness: floor.fullness, busyness: floor.busyness),
              const SizedBox(height: 8),
              Row(
                children: [
                  BusynessPill(busyness: floor.busyness),
                  const Spacer(),
                  if (floor.areas.length > 1) ...[
                    Text(
                      '${floor.areas.length} areas',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.expand_more, color: muted),
                    ),
                  ],
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: _expanded && floor.areas.length > 1
                    ? Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          children: [
                            for (final area in floor.areas)
                              _AreaRow(area: area),
                          ],
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AreaRow extends StatelessWidget {
  const _AreaRow({required this.area});

  final Area area;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  area.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${area.occupancy} people  ·  ${area.busyness.label}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 6),
          FullnessBar(
            fullness: area.fullness,
            busyness: area.busyness,
            height: 5,
          ),
        ],
      ),
    );
  }
}
