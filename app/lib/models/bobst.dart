enum Busyness {
  empty('Empty'),
  quiteEmpty('Quite empty'),
  notTooBusy('Not too busy'),
  busy('Busy'),
  veryBusy('Very busy'),
  full('Full');

  const Busyness(this.label);

  final String label;

  static Busyness fromJson(String value) => switch (value) {
    'empty' => empty,
    'quite_empty' => quiteEmpty,
    'not_too_busy' => notTooBusy,
    'busy' => busy,
    'very_busy' => veryBusy,
    'full' => full,
    _ => throw FormatException('Unknown busyness: $value'),
  };
}

enum Noise {
  quiet('Quiet'),
  talkative('Talkative'),
  mixed('Quiet & talkative');

  const Noise(this.label);

  final String label;
}

class Area {
  const Area({
    required this.id,
    required this.name,
    required this.label,
    required this.noise,
    required this.occupancy,
    required this.capacity,
    required this.fullness,
    required this.busyness,
  });

  final String id;
  final String name;
  final String label;
  final Noise noise;
  final int occupancy;
  final int capacity;
  final double fullness;
  final Busyness busyness;

  factory Area.fromJson(Map<String, dynamic> json) => Area(
    id: json['id'] as String,
    name: json['name'] as String,
    label: json['label'] as String,
    noise: Noise.values.byName(json['noise'] as String),
    occupancy: json['occupancy'] as int,
    capacity: json['capacity'] as int,
    fullness: (json['fullness'] as num).toDouble(),
    busyness: Busyness.fromJson(json['busyness'] as String),
  );
}

class Floor {
  const Floor({
    required this.id,
    required this.name,
    required this.noise,
    required this.occupancy,
    required this.capacity,
    required this.fullness,
    required this.busyness,
    required this.areas,
  });

  final String id;
  final String name;
  final Noise noise;
  final int occupancy;
  final int capacity;
  final double fullness;
  final Busyness busyness;
  final List<Area> areas;

  factory Floor.fromJson(Map<String, dynamic> json) => Floor(
    id: json['id'] as String,
    name: json['name'] as String,
    noise: Noise.values.byName(json['noise'] as String),
    occupancy: json['occupancy'] as int,
    capacity: json['capacity'] as int,
    fullness: (json['fullness'] as num).toDouble(),
    busyness: Busyness.fromJson(json['busyness'] as String),
    areas: (json['areas'] as List)
        .map((a) => Area.fromJson(a as Map<String, dynamic>))
        .toList(),
  );
}

class Building {
  const Building({
    required this.occupancy,
    required this.capacity,
    required this.fullness,
    required this.busyness,
  });

  final int occupancy;
  final int capacity;
  final double fullness;
  final Busyness busyness;

  factory Building.fromJson(Map<String, dynamic> json) => Building(
    occupancy: json['occupancy'] as int,
    capacity: json['capacity'] as int,
    fullness: (json['fullness'] as num).toDouble(),
    busyness: Busyness.fromJson(json['busyness'] as String),
  );
}

class BobstStatus {
  const BobstStatus({
    required this.updatedAt,
    required this.building,
    required this.bestQuiet,
    required this.bestTalkative,
    required this.floors,
  });

  final DateTime updatedAt;
  final Building building;
  final Area? bestQuiet;
  final Area? bestTalkative;
  final List<Floor> floors;

  factory BobstStatus.fromJson(Map<String, dynamic> json) {
    final best = json['best_spots'] as Map<String, dynamic>;
    Area? area(Object? a) =>
        a == null ? null : Area.fromJson(a as Map<String, dynamic>);
    return BobstStatus(
      updatedAt: DateTime.parse(json['updated_at'] as String),
      building: Building.fromJson(json['building'] as Map<String, dynamic>),
      bestQuiet: area(best['quiet']),
      bestTalkative: area(best['talkative']),
      floors: (json['floors'] as List)
          .map((f) => Floor.fromJson(f as Map<String, dynamic>))
          .toList(),
    );
  }
}
