import 'package:flutter/material.dart';

import '../models/bobst.dart';
import '../theme/busyness_colors.dart';
import '../widgets/building_view.dart';

/// Bobst floor by floor as a building you can rotate. Will likely replace the
/// Floors tab once it settles.
class BuildingScreen extends StatefulWidget {
  const BuildingScreen({super.key, required this.status});

  final BobstStatus status;

  @override
  State<BuildingScreen> createState() => _BuildingScreenState();
}

class _BuildingScreenState extends State<BuildingScreen> {
  String? _floorId;
  String? _areaId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Resolve against the latest data so the card updates with each refresh.
    final floor = widget.status.floors
        .where((f) => f.id == _floorId)
        .firstOrNull;
    final area = floor?.areas.where((a) => a.id == _areaId).firstOrNull;

    return Padding(
      // Bottom padding keeps everything clear of the floating tab bar.
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 16,
        16,
        110,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Building',
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: BuildingView(
              floors: widget.status.floors,
              onSelectionChanged: (floorId, areaId) => setState(() {
                _floorId = floorId;
                _areaId = areaId;
              }),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.bottomCenter,
            child: floor == null
                ? const SizedBox(width: double.infinity)
                : Card(
                    margin: const EdgeInsets.only(top: 8),
                    child: area != null
                        ? _StatsSheet(
                            title: area.label,
                            occupancy: area.occupancy,
                            fullness: area.fullness,
                            busyness: area.busyness,
                            noise: area.noise,
                            areas: const [],
                          )
                        : _StatsSheet(
                            title: floor.name,
                            occupancy: floor.occupancy,
                            fullness: floor.fullness,
                            busyness: floor.busyness,
                            noise: floor.noise,
                            areas: floor.areas.length > 1
                                ? floor.areas
                                : const [],
                          ),
                  ),
          ),
          const SizedBox(height: 12),
          const _Legend(),
        ],
      ),
    );
  }
}

class _StatsSheet extends StatelessWidget {
  const _StatsSheet({
    required this.title,
    required this.occupancy,
    required this.fullness,
    required this.busyness,
    required this.noise,
    required this.areas,
  });

  final String title;
  final int occupancy;
  final double fullness;
  final Busyness busyness;
  final Noise noise;
  final List<Area> areas;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              busyness.label,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorFor(busyness),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _Stat(value: '$occupancy', label: 'people'),
                _Stat(value: '${(fullness * 100).round()}%', label: 'full'),
                _Stat(value: noise.label, label: 'noise'),
              ],
            ),
            if (areas.isNotEmpty) ...[
              const SizedBox(height: 20),
              for (final area in areas)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: colorFor(area.busyness),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(area.name)),
                      Text(
                        '${area.occupancy} people · ${area.busyness.label}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Empty → Full colour key.
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Row(
      children: [
        Text('Empty', style: style),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(
                colors: [for (final b in Busyness.values) colorFor(b)],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('Full', style: style),
      ],
    );
  }
}
