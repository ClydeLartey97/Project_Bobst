enum RoomState { free, booked, closed }

class Room {
  const Room({
    required this.id,
    required this.name,
    required this.floor,
    required this.capacity,
    required this.state,
    required this.freeUntil,
    required this.nextFreeAt,
    required this.bookingUrl,
  });

  final int id;
  final String name;
  final String? floor;
  final int? capacity;
  final RoomState state;
  final DateTime? freeUntil;
  final DateTime? nextFreeAt;
  final Uri bookingUrl;

  factory Room.fromJson(Map<String, dynamic> json) => Room(
    id: json['id'] as int,
    name: json['name'] as String,
    floor: json['floor'] as String?,
    capacity: json['capacity'] as int?,
    state: RoomState.values.byName(json['state'] as String),
    freeUntil: _time(json['free_until']),
    nextFreeAt: _time(json['next_free_at']),
    bookingUrl: Uri.parse(json['booking_url'] as String),
  );
}

class RoomGroup {
  const RoomGroup({
    required this.id,
    required this.name,
    required this.freeNow,
    required this.total,
    required this.rooms,
    required this.updatedAt,
    required this.error,
  });

  final int id;
  final String name;
  final int freeNow;
  final int total;
  final List<Room> rooms;
  final DateTime? updatedAt;
  final String? error;

  factory RoomGroup.fromJson(Map<String, dynamic> json) => RoomGroup(
    id: json['id'] as int,
    name: json['name'] as String,
    freeNow: json['free_now'] as int,
    total: json['total'] as int,
    rooms: (json['rooms'] as List)
        .map((r) => Room.fromJson(r as Map<String, dynamic>))
        .toList(),
    updatedAt: _time(json['updated_at']),
    error: json['error'] as String?,
  );
}

DateTime? _time(Object? value) =>
    value == null ? null : DateTime.parse(value as String).toLocal();
