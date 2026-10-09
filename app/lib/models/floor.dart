enum BusynessLevel { quiet, moderate, busy }

class Floor {
  const Floor({
    required this.id,
    required this.name,
    required this.occupancy,
    required this.capacity,
    required this.busyness,
    required this.level,
  });

  final String id;
  final String name;
  final int occupancy;
  final int capacity;
  final double busyness;
  final BusynessLevel level;

  factory Floor.fromJson(Map<String, dynamic> json) => Floor(
        id: json['id'] as String,
        name: json['name'] as String,
        occupancy: json['occupancy'] as int,
        capacity: json['capacity'] as int,
        busyness: (json['busyness'] as num).toDouble(),
        level: BusynessLevel.values.byName(json['level'] as String),
      );
}

class FloorsSnapshot {
  const FloorsSnapshot({required this.updatedAt, required this.floors});

  final DateTime updatedAt;
  final List<Floor> floors;

  factory FloorsSnapshot.fromJson(Map<String, dynamic> json) => FloorsSnapshot(
        updatedAt: DateTime.parse(json['updated_at'] as String),
        floors: (json['floors'] as List)
            .map((f) => Floor.fromJson(f as Map<String, dynamic>))
            .toList(),
      );
}
