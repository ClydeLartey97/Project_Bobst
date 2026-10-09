import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/bobst.dart';
import '../theme/busyness_colors.dart';
import '../widgets/busyness_pill.dart';
import '../widgets/floor_plan.dart';

/// Hero tags shared between a floor card and its page.
String floorPlanTag(String floorId) => 'floor-plan-$floorId';
String floorTitleTag(String floorId) => 'floor-title-$floorId';

/// Straight-line hero path (the default arcs), so the plan stays square.
RectTween straightRectTween(Rect? begin, Rect? end) =>
    RectTween(begin: begin, end: end);

/// One floor up close: overhead plan on top, its areas below.
///
/// Opens from a floor card: the card's mini plan grows into the big one and
/// the title carries across, while the rest of the page settles in.
class FloorPage extends StatefulWidget {
  const FloorPage({super.key, required this.floorId, required this.live});

  final String floorId;

  /// Latest data, so the page keeps updating while it's open.
  final ValueListenable<BobstStatus?> live;

  static Route<void> route({
    required String floorId,
    required ValueListenable<BobstStatus?> live,
  }) {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 560),
      reverseTransitionDuration: const Duration(milliseconds: 440),
      pageBuilder: (_, _, _) => FloorPage(floorId: floorId, live: live),
      transitionsBuilder: (context, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: const Interval(0, 0.5, curve: Curves.easeOut),
        ),
        child: child,
      ),
    );
  }

  @override
  State<FloorPage> createState() => _FloorPageState();
}

class _FloorPageState extends State<FloorPage> {
  String? _selectedAreaId;
  double _edgeDrag = 0;

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context)!;
    return ValueListenableBuilder<BobstStatus?>(
      valueListenable: widget.live,
      builder: (context, status, _) {
        final floor = status?.floors
            .where((f) => f.id == widget.floorId)
            .firstOrNull;
        if (floor == null) return const Scaffold();

        return Scaffold(
          body: Stack(
            children: [
              ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  MediaQuery.paddingOf(context).top + 8,
                  16,
                  32,
                ),
                children: [
                  const SizedBox(height: 56), // room for the pinned back button
                  Hero(
                    tag: floorTitleTag(floor.id),
                    createRectTween: straightRectTween,
                    flightShuttleBuilder: _titleFlight,
                    child: FloorTitle(floor: floor, large: true),
                  ),
                  const SizedBox(height: 4),
                  _Settle(
                    animation: route.animation!,
                    start: 0.7, // after the title has landed
                    child: _Summary(floor: floor),
                  ),
                  const SizedBox(height: 20),
                  _Settle(
                    animation: route.animation!,
                    start: 0.75,
                    child: const _NorthMarker(),
                  ),
                  const SizedBox(height: 8),
                  Hero(
                    tag: floorPlanTag(floor.id),
                    createRectTween: straightRectTween,
                    flightShuttleBuilder: _planFlight,
                    child: FloorPlanDiagram(
                      floor: floor,
                      detail: 1,
                      selectedAreaId: _selectedAreaId,
                      onTapArea: (id) => setState(() => _selectedAreaId = id),
                    ),
                  ),
                  const SizedBox(height: 24),
                  for (final (i, area) in floor.areas.indexed)
                    _Settle(
                      animation: route.animation!,
                      start: 0.45 + i * 0.08,
                      child: _AreaRow(
                        area: area,
                        selected: area.id == _selectedAreaId,
                        onTap: () => setState(
                          () => _selectedAreaId = area.id == _selectedAreaId
                              ? null
                              : area.id,
                        ),
                      ),
                    ),
                ],
              ),
              // Back stays pinned while the page scrolls.
              Positioned(
                left: 12,
                top: MediaQuery.paddingOf(context).top + 8,
                child: IconButton.filledTonal(
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                ),
              ),
              // Swipe from the left edge to go back, like a standard iOS page.
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 24,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragStart: (_) => _edgeDrag = 0,
                  onHorizontalDragUpdate: (d) => _edgeDrag += d.delta.dx,
                  onHorizontalDragEnd: (d) {
                    if (_edgeDrag > 80 || d.primaryVelocity! > 600) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// The mini plan grows into the full plan, labels fading in as it lands.
  Widget _planFlight(
    BuildContext context,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext from,
    BuildContext to,
  ) {
    // The page's diagram has the data and selection; animate its detail.
    final page = (direction == HeroFlightDirection.push ? to : from).widget;
    final diagram = (page as Hero).child as FloorPlanDiagram;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) => FloorPlanDiagram(
        floor: diagram.floor,
        detail: animation.value,
        selectedAreaId: diagram.selectedAreaId,
      ),
    );
  }

  Widget _titleFlight(
    BuildContext context,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext from,
    BuildContext to,
  ) {
    final title =
        ((direction == HeroFlightDirection.push ? to : from).widget as Hero)
                .child
            as FloorTitle;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) =>
          FloorTitle(floor: title.floor, large: true, grow: animation.value),
    );
  }
}

/// Floor name; grows from card size to page size during the transition.
class FloorTitle extends StatelessWidget {
  const FloorTitle({
    super.key,
    required this.floor,
    this.large = false,
    this.grow,
  });

  final Floor floor;
  final bool large;

  /// Mid-flight size between card (0) and page (1); null = settled.
  final double? grow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final small = theme.textTheme.titleMedium!.copyWith(
      fontWeight: FontWeight.w700,
    );
    final big = theme.textTheme.headlineMedium!.copyWith(
      fontWeight: FontWeight.w800,
    );
    final style = grow != null
        ? TextStyle.lerp(small, big, Curves.easeOut.transform(grow!))!
        : (large ? big : small);
    return Material(
      type: MaterialType.transparency,
      child: Text(
        floor.name,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
        style: style,
      ),
    );
  }
}

/// Busyness word, coloured to match, plus the headline numbers.
class _Summary extends StatelessWidget {
  const _Summary({required this.floor});

  final Floor floor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: floor.busyness.label,
            style: TextStyle(
              color: deepen(colorFor(floor.busyness)),
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(
            text:
                '  ·  ${floor.occupancy} people  ·  '
                '${(floor.fullness * 100).round()}% full',
          ),
        ],
      ),
      style: muted,
    );
  }
}

class _NorthMarker extends StatelessWidget {
  const _NorthMarker();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.north, size: 14, color: color),
        const SizedBox(width: 2),
        Text(
          'N',
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: color),
        ),
      ],
    );
  }
}

class _AreaRow extends StatelessWidget {
  const _AreaRow({
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selected
              ? Color.alphaBlend(
                  color.withValues(alpha: 0.12),
                  theme.colorScheme.surface,
                )
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          area.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        area.busyness.label,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: deepen(color),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FullnessBar(
                    fullness: area.fullness,
                    busyness: area.busyness,
                    height: 6,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${area.occupancy} people',
                        style: theme.textTheme.bodySmall,
                      ),
                      const Spacer(),
                      Text(
                        area.noise.label,
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
      ),
    );
  }
}

/// Fades and lifts a child into place partway through the page transition.
class _Settle extends StatelessWidget {
  const _Settle({
    required this.animation,
    required this.start,
    required this.child,
  });

  final Animation<double> animation;
  final double start;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Interval(start.clamp(0, 0.9), 1, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) => Opacity(
        opacity: curved.value,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - curved.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
