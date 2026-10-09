import 'package:flutter/material.dart';

import '../models/bobst.dart';
import '../widgets/busyness_pill.dart';
import '../widgets/updated_label.dart';

enum _Grouping { floors, areas }

enum _Sort {
  building('Building order'),
  leastBusy('Least busy first'),
  mostBusy('Most busy first');

  const _Sort(this.label);

  final String label;
}

/// Every floor (or every area) at a glance, sortable and filterable by noise.
class FloorsScreen extends StatefulWidget {
  const FloorsScreen({
    super.key,
    required this.status,
    required this.onRefresh,
  });

  final BobstStatus status;
  final Future<void> Function() onRefresh;

  @override
  State<FloorsScreen> createState() => _FloorsScreenState();
}

class _FloorsScreenState extends State<FloorsScreen> {
  _Grouping _grouping = _Grouping.floors;
  _Sort _sort = _Sort.building;
  Noise? _noise; // null = any

  List<T> _sorted<T>(List<T> items, double Function(T) fullness) {
    final list = [...items];
    switch (_sort) {
      case _Sort.building:
        break; // backend order is top of the building down
      case _Sort.leastBusy:
        list.sort((a, b) => fullness(a).compareTo(fullness(b)));
      case _Sort.mostBusy:
        list.sort((a, b) => fullness(b).compareTo(fullness(a)));
    }
    return list;
  }

  bool _matches(Area area) => _noise == null || area.noise == _noise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final floors = widget.status.floors;

    final List<Widget> items;
    if (_grouping == _Grouping.floors) {
      final shown = floors.where((f) => f.areas.any(_matches)).toList();
      items = [
        for (final floor in _sorted(shown, (f) => f.fullness))
          FloorCard(key: ValueKey(floor.id), floor: floor),
      ];
    } else {
      final areas = [
        for (final floor in floors) ...floor.areas.where(_matches),
      ];
      items = [
        for (final area in _sorted(areas, (a) => a.fullness))
          _AreaCard(key: ValueKey(area.label), area: area),
      ];
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        // Bottom padding keeps the last item clear of the floating tab bar.
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
          UpdatedLabel(updatedAt: widget.status.updatedAt),
          const SizedBox(height: 16),
          Row(
            children: [
              SegmentedButton<_Grouping>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: _Grouping.floors, label: Text('Floors')),
                  ButtonSegment(value: _Grouping.areas, label: Text('Areas')),
                ],
                selected: {_grouping},
                onSelectionChanged: (s) => setState(() => _grouping = s.first),
              ),
              const Spacer(),
              PopupMenuButton<_Sort>(
                tooltip: 'Sort',
                initialValue: _sort,
                onSelected: (s) => setState(() => _sort = s),
                itemBuilder: (_) => [
                  for (final s in _Sort.values)
                    PopupMenuItem(value: s, child: Text(s.label)),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sort, size: 20),
                      const SizedBox(width: 6),
                      Text(_sort.label, style: theme.textTheme.labelLarge),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              for (final (noise, label) in [
                (null, 'Any noise'),
                (Noise.quiet, 'Quiet'),
                (Noise.talkative, 'Talkative'),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: _noise == noise,
                  onSelected: (_) => setState(() => _noise = noise),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...items,
        ],
      ),
    );
  }
}

/// One area as its own row, for the flat Areas view.
class _AreaCard extends StatelessWidget {
  const _AreaCard({super.key, required this.area});

  final Area area;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
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
                        area.label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        area.noise.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${area.occupancy}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 4),
                Text('people', style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 10),
            FullnessBar(fullness: area.fullness, busyness: area.busyness),
            const SizedBox(height: 8),
            Row(
              children: [
                BusynessPill(busyness: area.busyness),
                const Spacer(),
                Text(
                  '${(area.fullness * 100).round()}% full',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ),
          ],
        ),
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
