import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/bobst.dart';
import '../theme/busyness_colors.dart';

/// Bobst as a stack of floors you can spin, tilt and zoom.
///
/// - Flat (at rest): front-on, each floor one colour for its overall average.
/// - 3D (drag): each side of each floor shows that side's own busyness, with
///   floor numbers and compass points so you can read "the south side is busy".
/// - Open a floor ([openFloorId]): the rest of the building flies away and the
///   camera swings overhead until the floor sits exactly in [planRect], where
///   the screen lays its floor plan over it.
///
/// Drawn with plain canvas maths (no 3D engine), so it's light and identical
/// on every platform.
class BuildingView extends StatefulWidget {
  const BuildingView({
    super.key,
    required this.floors,
    required this.planRect,
    required this.onTapFloor,
    this.openFloorId,
    this.onOpened,
    this.onClosed,
  });

  final List<Floor> floors;

  /// Where an opened floor lands, seen from above, in this widget's
  /// coordinates. Matches the floor plan the screen draws on top.
  final Rect planRect;

  final String? openFloorId;
  final ValueChanged<String> onTapFloor;
  final VoidCallback? onOpened;
  final VoidCallback? onClosed;

  @override
  State<BuildingView> createState() => BuildingViewState();
}

class BuildingViewState extends State<BuildingView>
    with TickerProviderStateMixin {
  // How far into 3D we are: 0 = flat front view, 1 = full 3D.
  double _depth = 0;
  double _yaw = 0;
  double _tilt = 0; // on top of the automatic tilt that comes with 3D
  double _zoom = 1;

  // Camera transitions (into 3D, back to flat).
  late final AnimationController _camera = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..addListener(_onCameraTick);
  _Pose? _from;
  _Pose? _to;

  // Momentum after a flick.
  late final Ticker _spin = createTicker(_onSpinTick);
  double _spinVelocity = 0; // radians per second
  Duration? _lastSpinTick;

  // Opening a floor: everything else flies away, camera goes overhead.
  late final AnimationController _focus =
      AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 950),
        )
        ..addListener(() => setState(() {}))
        ..addStatusListener(_onFocusStatus);
  String? _focusFloor;

  double _zoomAtGestureStart = 1;
  final _hits = <_Hit>[];

  bool get isFlat => _depth == 0 && !_camera.isAnimating;
  bool get isOpen => _focusFloor != null;

  @override
  void didUpdateWidget(BuildingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final id = widget.openFloorId;
    if (id == oldWidget.openFloorId) return;
    if (id != null) {
      _spin.stop();
      _camera.stop();
      _focusFloor = id;
      _focus.forward(from: 0);
    } else {
      _focus.reverse();
    }
  }

  void _onFocusStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onOpened?.call();
    } else if (status == AnimationStatus.dismissed) {
      setState(() => _focusFloor = null);
      widget.onClosed?.call();
    }
  }

  @override
  void dispose() {
    _camera.dispose();
    _spin.dispose();
    _focus.dispose();
    super.dispose();
  }

  // Camera ------------------------------------------------------------------

  void _onCameraTick() {
    final from = _from, to = _to;
    if (from == null || to == null) return;
    final t = Curves.easeInOutCubic.transform(_camera.value);
    setState(() {
      _depth = _lerp(from.depth, to.depth, t);
      if (to.moveCamera) {
        _yaw = _lerp(from.yaw, to.yaw, t);
        _tilt = _lerp(from.tilt, to.tilt, t);
        _zoom = _lerp(from.zoom, to.zoom, t);
      }
    });
  }

  void _animateTo(_Pose to) {
    _from = _Pose(_depth, _yaw, _tilt, _zoom);
    _to = to;
    _camera.forward(from: 0);
  }

  /// Animate back to the flat 2D view.
  void flatten() {
    _spin.stop();
    _animateTo(_Pose(0, _nearestFront(_yaw), 0, 1, moveCamera: true));
  }

  void _maybeSnapFlat() {
    final offFront = (_yaw - _nearestFront(_yaw)).abs();
    if (offFront < 0.3 && _tilt.abs() < 0.2) flatten();
  }

  // Gestures ----------------------------------------------------------------

  void _onScaleStart(ScaleStartDetails d) {
    _spin.stop();
    _camera.stop();
    _zoomAtGestureStart = _zoom;
    if (_depth < 1) _animateTo(_Pose(1, _yaw, _tilt, _zoom));
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    setState(() {
      _yaw += d.focalPointDelta.dx * 0.012;
      _tilt = (_tilt + d.focalPointDelta.dy * 0.008).clamp(-_autoTilt, 0.75);
      if (d.pointerCount > 1) {
        _zoom = (_zoomAtGestureStart * d.scale).clamp(0.6, 3.0);
      }
    });
  }

  void _onScaleEnd(ScaleEndDetails d) {
    final v = d.velocity.pixelsPerSecond.dx * 0.012;
    if (d.pointerCount == 0 && v.abs() > 1.2) {
      _spinVelocity = v.clamp(-12.0, 12.0);
      _lastSpinTick = null;
      _spin.start();
    } else {
      _maybeSnapFlat();
    }
  }

  void _onSpinTick(Duration elapsed) {
    final last = _lastSpinTick;
    _lastSpinTick = elapsed;
    if (last == null) return;
    final dt = (elapsed - last).inMicroseconds / 1e6;
    setState(() {
      _yaw += _spinVelocity * dt;
      _spinVelocity *= math.pow(0.04, dt); // friction
    });
    if (_spinVelocity.abs() < 0.08) {
      _spin.stop();
      _maybeSnapFlat();
    }
  }

  void _onTapUp(TapUpDetails d) {
    for (final hit in _hits.reversed) {
      if (!hit.path.contains(d.localPosition)) continue;
      final floor = hit.floor;
      if (floor != null) widget.onTapFloor(floor.id); // untracked: ignore
      return;
    }
  }

  // Build -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final focus = Curves.easeInOutCubic.transform(_focus.value);
    final basePitch = (_tilt + _autoTilt * _depth).clamp(0.0, 1.25);

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            ignoring: isOpen,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
              onScaleEnd: _onScaleEnd,
              onTapUp: _onTapUp,
              child: CustomPaint(
                size: Size.infinite,
                painter: _BuildingPainter(
                  floors: {for (final f in widget.floors) f.id: f},
                  // Opening a floor always ends in 3D, north up, overhead.
                  depth: _lerp(_depth, 1, focus),
                  yaw: _lerp(_yaw, _nearestFront(_yaw), focus),
                  pitch: _lerp(basePitch, math.pi / 2, focus),
                  zoom: _zoom,
                  focusFloor: _focusFloor,
                  focus: focus,
                  planRect: widget.planRect,
                  hits: _hits,
                  labelStyle: theme.textTheme.labelLarge!.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                  countStyle: theme.textTheme.bodySmall!.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  shadowColor: theme.colorScheme.shadow,
                  backgroundColor: theme.colorScheme.surface,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: AnimatedOpacity(
            opacity: _depth > 0.05 && !isOpen ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: _depth <= 0.05 || isOpen,
              child: IconButton.filledTonal(
                tooltip: 'Flat view',
                onPressed: flatten,
                icon: const Icon(Icons.view_agenda_outlined),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Tilt applied automatically when going 3D, so the floor tops show.
const _autoTilt = 0.5;

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// Nearest yaw that faces the front (multiples of a full turn).
double _nearestFront(double yaw) =>
    (yaw / (2 * math.pi)).roundToDouble() * 2 * math.pi;

class _Pose {
  const _Pose(
    this.depth,
    this.yaw,
    this.tilt,
    this.zoom, {
    this.moveCamera = false,
  });

  final double depth, yaw, tilt, zoom;
  final bool moveCamera;
}

/// Every level of Bobst bottom to top, including ones we don't track, so the
/// building looks right.
const _levels = [
  _Level('LL2', 'LL2'),
  _Level('LL1', 'LL1'),
  _Level('1', '1'),
  _Level('M', 'M', height: 0.26),
  _Level('2', '2'),
  _Level('3', '3'),
  _Level('4', '4'),
  _Level('5', '5'),
  _Level('6', '6'),
  _Level('7', '7'),
  _Level('8', '8'),
  _Level('9', '9'),
  _Level('10', '10'),
  _Level('11', '11'),
  _Level('12', '12'),
];

/// Half-width of the square footprint. Shared with the floor plan so the
/// overhead view and the plan line up.
const buildingOuter = 2.6;

/// Half-width of the central atrium.
const buildingInner = 1.05;

const _outer = buildingOuter;
const _inner = buildingInner;
const _gap = 0.1; // open space between floors
const _plate = 0.07; // white floor plate at the bottom of each level
const _flyAway = 9.0; // how far other floors travel when one is opened

class _Level {
  const _Level(this.id, this.label, {this.height = 0.5});

  final String id;
  final String label;
  final double height;
}

class _V {
  const _V(this.x, this.y, this.z);

  final double x, y, z;

  _V operator +(_V o) => _V(x + o.x, y + o.y, z + o.z);
  double dot(_V o) => x * o.x + y * o.y + z * o.z;
}

class _Hit {
  _Hit(this.path, this.floor);

  final Path path;
  final Floor? floor;
}

/// A flat polygon on one floor: part of a wall, or a band of the floor's top.
class _Face {
  _Face(this.corners, this.normal, this.area, {this.isTop = false});

  final List<_V> corners;
  final _V normal;
  final Area? area;
  final bool isTop;
}

/// Floor plan around the atrium: four bands, one per side.
///   north: full width at the back   south: full width at the front
///   west / east: between them, beside the atrium
typedef _Rect = (double x0, double z0, double x1, double z1);

const Map<Side, _Rect> _bands = {
  Side.north: (-_outer, -_outer, _outer, -_inner),
  Side.south: (-_outer, _inner, _outer, _outer),
  Side.west: (-_outer, -_inner, -_inner, _inner),
  Side.east: (_inner, -_inner, _outer, _inner),
};

/// One floor's walls and top, split by area. Walls are cut where the band
/// behind them changes, then neighbouring pieces with the same area are merged
/// so each area reads as one clean shape.
List<_Face> _floorFaces(double y0, double y1, Map<Side, Area> bySide) {
  final faces = <_Face>[];

  void wall(
    _V normal,
    _V Function(double t, double y) at,
    List<(double, double, Side)> pieces,
  ) {
    final merged = <(double, double, Area?)>[];
    for (final (t0, t1, side) in pieces) {
      final area = bySide[side];
      if (merged.isNotEmpty && merged.last.$3?.id == area?.id && area != null) {
        merged[merged.length - 1] = (merged.last.$1, t1, area);
      } else {
        merged.add((t0, t1, area));
      }
    }
    for (final (t0, t1, area) in merged) {
      faces.add(
        _Face([at(t0, y1), at(t1, y1), at(t1, y0), at(t0, y0)], normal, area),
      );
    }
  }

  const o = _outer, i = _inner;
  // South (front) and north (back) outer walls belong entirely to their band.
  wall(const _V(0, 0, 1), (t, y) => _V(t, y, o), [(-o, o, Side.south)]);
  wall(const _V(0, 0, -1), (t, y) => _V(t, y, -o), [(-o, o, Side.north)]);
  // East and west outer walls cross three bands.
  for (final (x, n, side) in [
    (o, const _V(1, 0, 0), Side.east),
    (-o, const _V(-1, 0, 0), Side.west),
  ]) {
    wall(n, (t, y) => _V(x, y, t), [
      (-o, -i, Side.north),
      (-i, i, side),
      (i, o, Side.south),
    ]);
  }
  // Atrium walls face inwards.
  wall(const _V(0, 0, 1), (t, y) => _V(t, y, -i), [(-i, i, Side.north)]);
  wall(const _V(0, 0, -1), (t, y) => _V(t, y, i), [(-i, i, Side.south)]);
  wall(const _V(1, 0, 0), (t, y) => _V(-i, y, t), [(-i, i, Side.west)]);
  wall(const _V(-1, 0, 0), (t, y) => _V(i, y, t), [(-i, i, Side.east)]);

  for (final MapEntry(key: side, value: (x0, z0, x1, z1)) in _bands.entries) {
    faces.add(
      _Face(
        [_V(x0, y1, z0), _V(x1, y1, z0), _V(x1, y1, z1), _V(x0, y1, z1)],
        const _V(0, 1, 0),
        bySide[side],
        isTop: true,
      ),
    );
  }
  return faces;
}

class _BuildingPainter extends CustomPainter {
  _BuildingPainter({
    required this.floors,
    required this.depth,
    required this.yaw,
    required this.pitch,
    required this.zoom,
    required this.focusFloor,
    required this.focus,
    required this.planRect,
    required this.hits,
    required this.labelStyle,
    required this.countStyle,
    required this.shadowColor,
    required this.backgroundColor,
  });

  final Map<String, Floor> floors;
  final double depth, yaw, pitch, zoom, focus;
  final String? focusFloor;
  final Rect planRect;
  final List<_Hit> hits;
  final TextStyle labelStyle, countStyle;
  final Color shadowColor, backgroundColor;

  late double _cosY, _sinY, _cosP, _sinP, _height, _camDist;
  late double _focalX, _focalY;
  late Offset _center;

  static const _plateColor = Color(0xFFF7F5F2);
  static const _glassColor = Color(0xFFDCE3EA); // untracked floors

  @override
  void paint(Canvas canvas, Size size) {
    hits.clear();
    _cosY = math.cos(yaw);
    _sinY = math.sin(yaw);
    _cosP = math.cos(pitch);
    _sinP = math.sin(pitch);

    final levelY = <double>[];
    var y = 0.0;
    for (final level in _levels) {
      levelY.add(y);
      y += level.height + _gap;
    }
    _height = y - _gap;
    final focusIndex = _levels.indexWhere((l) => l.id == focusFloor);

    // Fit: flat view is a diagram that stretches to fill the space (labels
    // either side) and eases to true proportions in 3D. Opening a floor lands
    // it exactly on [planRect], seen straight down with no perspective.
    final radius = math.sqrt(
      math.pow(_height / 2, 2) + 2 * math.pow(_outer, 2),
    );
    final flatX = (size.width - 2 * 92) / (2 * _outer);
    final flatY = size.height * 0.9 / _height;
    final round = math.min(size.width, size.height) * 0.46 / radius;
    final planScale = planRect.width / (2 * _outer);
    final scaleX = _lerp(_lerp(flatX, round, depth) * zoom, planScale, focus);
    final scaleY = _lerp(_lerp(flatY, round, depth) * zoom, planScale, focus);
    _camDist = _lerp(_lerp(4000, radius * 3.4, depth), 4000, focus);
    _focalX = scaleX * _camDist;
    _focalY = scaleY * _camDist;
    _center = Offset.lerp(
      Offset(size.width / 2, size.height / 2),
      planRect.center,
      focus,
    )!;

    final offsets = [
      for (var i = 0; i < _levels.length; i++)
        _offsetFor(i, focusIndex, levelY[i] + _levels[i].height / 2),
    ];

    if (depth > 0) {
      _paintBase(canvas, 1 - _awayFade);
      _paintCompass(
        canvas,
        (depth - 0.5).clamp(0.0, 0.5) * 2 * (1 - _awayFade),
      );
    }

    // Whole floors far-to-near; within a floor inner walls, then top, then
    // outer walls, which is always the right overlap order.
    double distanceOf(int i) =>
        _distance(_V(0, levelY[i] + _levels[i].height / 2, 0) + offsets[i]);
    final order = List.generate(_levels.length, (i) => i)
      ..sort((a, b) => distanceOf(b).compareTo(distanceOf(a)));
    for (final i in order) {
      if (i != focusIndex && _awayFade >= 1) continue; // flown away
      _paintFloor(canvas, _levels[i], levelY[i], offsets[i], i == focusIndex);
    }

    final chrome = 1 - math.min(1.0, focus / 0.25); // labels go first
    if (depth < 0.5) {
      _paintFlatLabels(canvas, levelY, (1 - depth * 2) * chrome);
    }
    if (depth > 0.5) {
      final alpha = (depth - 0.5) * 2 * chrome;
      _paintFloorNumbers(canvas, levelY, alpha);
    }
  }

  /// Other floors fade out early in the flight so the chosen one flies alone.
  double get _awayFade => math.min(1.0, focus / 0.45);

  /// When a floor opens, it rises to the centre and the rest fly away.
  _V _offsetFor(int index, int focusIndex, double mid) {
    if (focusIndex < 0) return const _V(0, 0, 0);
    if (index == focusIndex) return _V(0, (_height / 2 - mid) * focus, 0);
    final away = index > focusIndex ? _flyAway : -_flyAway;
    return _V(0, away * focus, 0);
  }

  // Camera maths ------------------------------------------------------------

  /// World → camera space. Camera sits on +z looking at the building centre.
  _V _view(_V p) {
    final x = p.x, y = p.y - _height / 2, z = p.z;
    final x1 = x * _cosY + z * _sinY;
    final z1 = -x * _sinY + z * _cosY;
    return _V(x1, y * _cosP - z1 * _sinP, z1 * _cosP + y * _sinP);
  }

  _V _viewDir(_V n) {
    final x1 = n.x * _cosY + n.z * _sinY;
    final z1 = -n.x * _sinY + n.z * _cosY;
    return _V(x1, n.y * _cosP - z1 * _sinP, z1 * _cosP + n.y * _sinP);
  }

  Offset _project(_V p) {
    final v = _view(p);
    final w = _camDist - v.z;
    return Offset(
      _center.dx + v.x * _focalX / w,
      _center.dy - v.y * _focalY / w,
    );
  }

  double _distance(_V p) {
    final v = _view(p);
    return math.sqrt(v.x * v.x + v.y * v.y + math.pow(_camDist - v.z, 2));
  }

  bool _facesCamera(_Face f, _V offset) {
    var cx = 0.0, cy = 0.0, cz = 0.0;
    for (final c in f.corners) {
      cx += c.x;
      cy += c.y;
      cz += c.z;
    }
    final n = f.corners.length;
    final centre = _view(_V(cx / n, cy / n, cz / n) + offset);
    final toCam = _V(-centre.x, -centre.y, _camDist - centre.z);
    return _viewDir(f.normal).dot(toCam) > 1e-6;
  }

  // Drawing -----------------------------------------------------------------

  void _paintBase(Canvas canvas, double opacity) {
    Path quad(double r, double y) => Path()
      ..addPolygon([
        _project(_V(-r, y, -r)),
        _project(_V(r, y, -r)),
        _project(_V(r, y, r)),
        _project(_V(-r, y, r)),
      ], true);

    final a = depth * opacity;
    canvas.drawPath(
      quad(_outer + 0.9, -0.12),
      Paint()
        ..color = shadowColor.withValues(alpha: 0.16 * a)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );
    final plinth = quad(_outer + 0.45, -0.06);
    canvas
      ..drawPath(
        plinth,
        Paint()..color = _plateColor.withValues(alpha: 0.9 * a),
      )
      ..drawPath(
        plinth,
        Paint()
          ..color = shadowColor.withValues(alpha: 0.12 * a)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
  }

  /// Flat view shows each floor's average; 3D shows each area's own colour.
  Color _baseColor(Floor? floor, Area? area, bool focused) {
    var color = _glassColor;
    if (floor != null) {
      final floorColor = colorFor(floor.busyness);
      final areaColor = area != null
          ? colorFor(area.busyness)
          : Color.lerp(floorColor, _glassColor, 0.7)!;
      color = Color.lerp(floorColor, areaColor, depth)!;
    }
    if (focusFloor != null && !focused) {
      color = Color.lerp(color, backgroundColor, _awayFade)!; // fading away
    }
    return color;
  }

  /// Simple lighting from the camera's upper left, so any angle reads well.
  double _light(_V normal) {
    final n = _viewDir(normal);
    final diffuse = math.max(0.0, n.dot(const _V(-0.42, 0.72, 0.55)));
    return _lerp(1, math.min(1.0, 0.74 + 0.3 * diffuse), depth);
  }

  void _paintFloor(
    Canvas canvas,
    _Level level,
    double y0,
    _V offset,
    bool focused,
  ) {
    final floor = floors[level.id];
    final bySide = <Side, Area>{
      for (final area in floor?.areas ?? const <Area>[])
        for (final side in area.sides) side: area,
    };
    final faces = _floorFaces(
      y0,
      y0 + level.height,
      bySide,
    ).where((f) => _facesCamera(f, offset)).toList();

    final atrium = <_Face>[], tops = <_Face>[], outer = <_Face>[];
    for (final f in faces) {
      if (f.isTop) {
        tops.add(f);
      } else if (_isAtriumWall(f)) {
        atrium.add(f);
      } else {
        outer.add(f);
      }
    }

    // Flat view shows only the front; skip edge-on slivers of everything else.
    if (depth > 0.02) {
      for (final f in atrium) {
        _paintWall(canvas, f, floor, offset, y0, focused, inside: true);
      }
      _paintTop(canvas, tops, floor, offset, focused);
    }
    for (final f in outer) {
      _paintWall(canvas, f, floor, offset, y0, focused);
    }
  }

  /// Atrium walls are the only walls entirely within the atrium's square.
  bool _isAtriumWall(_Face f) => f.corners.every(
    (c) => c.x.abs() <= _inner + 1e-9 && c.z.abs() <= _inner + 1e-9,
  );

  List<Offset> _projectAll(List<_V> corners, _V offset) => [
    for (final c in corners) _project(c + offset),
  ];

  void _paintWall(
    Canvas canvas,
    _Face f,
    Floor? floor,
    _V offset,
    double y0,
    bool focused, {
    bool inside = false,
  }) {
    final fading = focusFloor != null && !focused ? _awayFade : 0.0;
    var color = Color.lerp(
      Colors.black,
      _baseColor(floor, f.area, focused),
      _light(f.normal) * (inside ? 0.85 : 1),
    )!;
    final pts = _projectAll(f.corners, offset);
    final path = Path()..addPolygon(pts, true);

    // Glass sheen: lighter towards the top edge of the wall.
    final top = Offset.lerp(pts[0], pts[1], 0.5)!;
    final bottom = Offset.lerp(pts[2], pts[3], 0.5)!;
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(top, bottom, [
          Color.lerp(color, Colors.white, 0.28 * depth + 0.04)!,
          color,
        ]),
    );

    // White floor plate along the bottom of the wall.
    final plateTop = _plate / (f.corners[0].y - y0);
    final plate = Path()
      ..addPolygon([
        Offset.lerp(pts[3], pts[0], plateTop)!,
        Offset.lerp(pts[2], pts[1], plateTop)!,
        pts[2],
        pts[3],
      ], true);
    final plateColor = Color.lerp(
      Color.lerp(
        Colors.black,
        _plateColor,
        _lerp(1, 0.75 + 0.25 * _light(f.normal), depth),
      ),
      backgroundColor,
      fading,
    )!;
    canvas.drawPath(plate, Paint()..color = plateColor);

    // Fine edge so areas and corners read crisply.
    color = Color.lerp(color, Colors.black, 0.25)!;
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.35 * (1 - fading))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
    hits.add(_Hit(path, floor));
  }

  void _paintTop(
    Canvas canvas,
    List<_Face> tops,
    Floor? floor,
    _V offset,
    bool focused,
  ) {
    if (tops.isEmpty) return;
    // Merge neighbouring bands of the same colour into one seamless shape.
    final groups = <Color, Path>{};
    for (final f in tops) {
      final color = _baseColor(floor, f.area, focused);
      final band = Path()..addPolygon(_projectAll(f.corners, offset), true);
      final existing = groups[color];
      groups[color] = existing == null
          ? band
          : Path.combine(PathOperation.union, existing, band);
    }
    final shade = _light(const _V(0, 1, 0));
    for (final MapEntry(key: color, value: path) in groups.entries) {
      final top = Color.lerp(
        Colors.black,
        Color.lerp(color, Colors.white, 0.12)!,
        math.min(1.0, shade + 0.12),
      )!;
      canvas.drawPath(path, Paint()..color = top);
      hits.add(_Hit(path, floor));
    }
    // Crisp light rim around the floor's outer edge and the atrium opening.
    final fading = focusFloor != null && !focused ? _awayFade : 0.0;
    final rim = Paint()
      ..color = Colors.white.withValues(alpha: 0.7 * depth * (1 - fading))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final y = tops.first.corners.first.y;
    for (final r in [_outer, _inner]) {
      canvas.drawPath(
        Path()..addPolygon(
          _projectAll([
            _V(-r, y, -r),
            _V(r, y, -r),
            _V(r, y, r),
            _V(-r, y, r),
          ], offset),
          true,
        ),
        rim,
      );
    }
  }

  // Labels ------------------------------------------------------------------

  /// Flat view: floor number on the left, headcount on the right.
  void _paintFlatLabels(Canvas canvas, List<double> levelY, double opacity) {
    if (opacity <= 0) return;
    for (var i = 0; i < _levels.length; i++) {
      final level = _levels[i];
      final mid = levelY[i] + level.height / 2;
      final left = _project(_V(-_outer, mid, _outer));
      final right = _project(_V(_outer, mid, _outer));
      final floor = floors[level.id];
      final alpha = opacity * (floor == null ? 0.4 : 1);

      _text(
        canvas,
        level.label,
        labelStyle.copyWith(color: labelStyle.color!.withValues(alpha: alpha)),
        Offset(left.dx - 12, left.dy),
        alignRight: true,
      );
      if (floor != null) {
        _text(
          canvas,
          '${floor.occupancy}',
          countStyle.copyWith(
            color: countStyle.color!.withValues(alpha: alpha),
          ),
          Offset(right.dx + 12, right.dy),
        );
      }
    }
  }

  /// 3D: floor numbers beside whichever corner is furthest left on screen.
  void _paintFloorNumbers(Canvas canvas, List<double> levelY, double opacity) {
    if (opacity <= 0) return;
    for (var i = 0; i < _levels.length; i++) {
      final level = _levels[i];
      final mid = levelY[i] + level.height / 2;
      Offset? leftmost;
      for (final (x, z) in [
        (-_outer, -_outer),
        (_outer, -_outer),
        (_outer, _outer),
        (-_outer, _outer),
      ]) {
        final p = _project(_V(x, mid, z));
        if (leftmost == null || p.dx < leftmost.dx) leftmost = p;
      }
      final alpha = opacity * (floors[level.id] == null ? 0.35 : 0.9);
      _text(
        canvas,
        level.label,
        labelStyle.copyWith(
          fontSize: 11,
          color: labelStyle.color!.withValues(alpha: alpha),
        ),
        Offset(leftmost!.dx - 8, leftmost.dy),
        alignRight: true,
      );
    }
  }

  /// 3D: N/E/S/W on the plinth so you can tell which side you're looking at.
  void _paintCompass(Canvas canvas, double opacity) {
    if (opacity <= 0) return;
    const r = _outer + 0.95;
    for (final (label, x, z) in [
      ('N', 0.0, -r),
      ('E', r, 0.0),
      ('S', 0.0, r),
      ('W', -r, 0.0),
    ]) {
      final p = _project(_V(x, -0.06, z));
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: labelStyle.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: (label == 'N' ? const Color(0xFFD0342C) : labelStyle.color!)
                .withValues(alpha: opacity),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }
  }

  void _text(
    Canvas canvas,
    String text,
    TextStyle style,
    Offset anchor, {
    bool alignRight = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = alignRight ? anchor.dx - tp.width : anchor.dx;
    tp.paint(canvas, Offset(dx, anchor.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_BuildingPainter old) => true;
}
