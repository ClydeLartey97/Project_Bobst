import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/bobst.dart';
import '../theme/busyness_colors.dart';
import '../widgets/busyness_pill.dart';
import '../widgets/floor_plan.dart';
import 'floor_page.dart';
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
    required this.live,
  });

  final BobstStatus status;
  final Future<void> Function() onRefresh;

  /// Latest data, handed to floor pages so they stay live while open.
  final ValueListenable<BobstStatus?> live;

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

  /// Native pull-down menu with the sort order and the noise filter.
  Widget _filterMenu() {
    final native = PlatformInfo.isIOS26OrHigher();
    return AdaptivePopupMenuButton.icon<Object>(
      icon: native ? 'line.3.horizontal.decrease.circle' : Icons.filter_list,
      items: [
        const AdaptivePopupMenuDivider(title: 'Sort'),
        for (final sort in _Sort.values)
          AdaptivePopupMenuItem<Object>(
            label: sort.label,
            value: sort,
            selected: sort == _sort,
          ),
        const AdaptivePopupMenuDivider(title: 'Noise'),
        for (final (noise, label) in [
          (null, 'Any noise'),
          (Noise.quiet, 'Quiet'),
          (Noise.talkative, 'Talkative'),
        ])
          AdaptivePopupMenuItem<Object>(
            label: label,
            value: noise ?? 'any',
            selected: noise == _noise,
          ),
      ],
      onSelected: (_, entry) => setState(() {
        switch (entry.value) {
          case final _Sort sort:
            _sort = sort;
          case final Noise noise:
            _noise = noise;
          default:
            _noise = null;
        }
      }),
    );
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
          FloorCard(key: ValueKey(floor.id), floor: floor, live: widget.live),
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
          Row(
            children: [
              Expanded(
                child: Text(
                  'Floors',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _filterMenu(),
            ],
          ),
          const SizedBox(height: 2),
          UpdatedLabel(updatedAt: widget.status.updatedAt),
          const SizedBox(height: 16),
          AdaptiveSegmentedControl(
            labels: const ['Floors', 'Areas'],
            selectedIndex: _grouping.index,
            onValueChanged: (i) =>
                setState(() => _grouping = _Grouping.values[i]),
          ),
          const SizedBox(height: 8),
          Text(
            '${_sort.label} · ${_noise?.label ?? 'Any noise'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
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

/// A floor at a glance: mini overhead plan (each side's busyness) plus the
/// headline. Tapping grows the plan into the full floor page.
class FloorCard extends StatelessWidget {
  const FloorCard({super.key, required this.floor, required this.live});

  final Floor floor;
  final ValueListenable<BobstStatus?> live;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () =>
              Navigator.of(context)
                  .push(FloorPage.route(floorId: floor.id, live: live)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  child: Hero(
                    tag: floorPlanTag(floor.id),
                    createRectTween: straightRectTween,
                    child: FloorPlanDiagram(floor: floor),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Hero(
                        tag: floorTitleTag(floor.id),
                        createRectTween: straightRectTween,
                        child: FloorTitle(floor: floor),
                      ),
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: floor.busyness.label,
                              style: TextStyle(
                                color: deepen(colorFor(floor.busyness)),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(text: '  ·  ${floor.occupancy} people'),
                          ],
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
