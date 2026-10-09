import 'package:flutter/material.dart';

import '../models/bobst.dart';
import '../theme/busyness_colors.dart';
import '../widgets/building_view.dart';
import '../widgets/busyness_pill.dart';
import '../widgets/floor_plan.dart';

/// Bobst as a building you can rotate. Tap a floor to fly in to its plan.
/// Will likely replace the Floors tab once it settles.
class BuildingScreen extends StatefulWidget {
  const BuildingScreen({super.key, required this.status});

  final BobstStatus status;

  @override
  State<BuildingScreen> createState() => _BuildingScreenState();
}

class _BuildingScreenState extends State<BuildingScreen> {
  /// Floor the camera is flying to / showing.
  String? _openFloorId;

  /// Plan overlay is visible (only once the camera has landed).
  bool _planShown = false;
  String? _selectedAreaId;

  static const _planFade = Duration(milliseconds: 260);

  Floor? get _openFloor =>
      widget.status.floors.where((f) => f.id == _openFloorId).firstOrNull;

  void _open(String floorId) {
    setState(() {
      _openFloorId = floorId;
      _selectedAreaId = null;
    });
  }

  Future<void> _close() async {
    setState(() => _planShown = false);
    await Future<void>.delayed(_planFade);
    if (mounted) setState(() => _openFloorId = null);
  }

  @override
  Widget build(BuildContext context) {
    final floor = _openFloor;
    final top = MediaQuery.paddingOf(context).top;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, top + 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: floor == null
                ? _Header(key: const ValueKey('building'), title: 'Building')
                : _Header(
                    key: ValueKey(floor.id),
                    title: floor.name,
                    subtitle:
                        '${floor.noise.label} · ${floor.occupancy} people',
                    onBack: _close,
                  ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final plan = floorPlanRect(constraints.maxWidth);
                return Stack(
                  children: [
                    Positioned.fill(
                      bottom: 110,
                      child: BuildingView(
                        floors: widget.status.floors,
                        planRect: plan,
                        openFloorId: _openFloorId,
                        onTapFloor: _open,
                        onOpened: () => setState(() => _planShown = true),
                      ),
                    ),
                    if (floor != null)
                      Positioned.fill(
                        child: IgnorePointer(
                          ignoring: !_planShown,
                          child: AnimatedOpacity(
                            opacity: _planShown ? 1 : 0,
                            duration: _planFade,
                            child: _FloorPage(
                              floor: floor,
                              selectedAreaId: _selectedAreaId,
                              onTapArea: (id) =>
                                  setState(() => _selectedAreaId = id),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 110 - 12 - 16,
                      child: AnimatedOpacity(
                        opacity: floor == null ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const _Legend(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({super.key, required this.title, this.subtitle, this.onBack});

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        if (onBack != null) ...[
          IconButton.filledTonal(
            tooltip: 'Back to building',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The opened floor: plan on top, details as you scroll.
class _FloorPage extends StatelessWidget {
  const _FloorPage({
    required this.floor,
    required this.selectedAreaId,
    required this.onTapArea,
  });

  final Floor floor;
  final String? selectedAreaId;
  final ValueChanged<String?> onTapArea;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          FloorPlan(
            floor: floor,
            selectedAreaId: selectedAreaId,
            onTapArea: onTapArea,
          ),
          const SizedBox(height: 20),
          _FloorSummary(floor: floor),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Areas',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (final area in floor.areas)
            _AreaTile(
              area: area,
              selected: area.id == selectedAreaId,
              onTap: () =>
                  onTapArea(area.id == selectedAreaId ? null : area.id),
            ),
        ],
      ),
    );
  }
}

class _FloorSummary extends StatelessWidget {
  const _FloorSummary({required this.floor});

  final Floor floor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = colorFor(floor.busyness);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          color.withValues(alpha: 0.1),
          theme.colorScheme.surface,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overall',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            floor.busyness.label,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: HSLColor.fromColor(color).withLightness(0.36).toColor(),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Stat(value: '${floor.occupancy}', label: 'people'),
              _Stat(value: '${(floor.fullness * 100).round()}%', label: 'full'),
              _Stat(value: '${floor.capacity}', label: 'seats'),
            ],
          ),
          const SizedBox(height: 14),
          FullnessBar(fullness: floor.fullness, busyness: floor.busyness),
        ],
      ),
    );
  }
}

class _AreaTile extends StatelessWidget {
  const _AreaTile({
    required this.area,
    required this.selected,
    required this.onTap,
  });

  final Area area;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = colorFor(area.busyness);
    final sides = area.sides.map((s) => s.name).join(', ');
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? color : Colors.transparent,
          width: 2,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            area.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${area.noise.label} · $sides side',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${area.occupancy}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('people', style: theme.textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: 10),
                FullnessBar(
                  fullness: area.fullness,
                  busyness: area.busyness,
                  height: 6,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      area.busyness.label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: HSLColor.fromColor(color)
                            .withLightness(0.36)
                            .toColor(),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${(area.fullness * 100).round()}% full',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
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
