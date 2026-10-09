/// Mirrors the backend's DevSettings (backend/app/dev.py).
class DevSettings {
  const DevSettings({
    this.hour,
    this.weekday,
    this.finals,
    this.crowd = 1.0,
    this.floorOverrides = const {},
  });

  /// 0–24, null = real time of day.
  final double? hour;

  /// 0 = Monday … 6 = Sunday, null = today.
  final int? weekday;

  /// null = follow the real calendar.
  final bool? finals;

  /// Multiplies everyone on floors that aren't overridden.
  final double crowd;

  /// Floor id → forced fullness 0..1.
  final Map<String, double> floorOverrides;

  bool get isDefault =>
      hour == null &&
      weekday == null &&
      finals == null &&
      crowd == 1.0 &&
      floorOverrides.isEmpty;

  DevSettings copyWith({
    double? Function()? hour,
    int? Function()? weekday,
    bool? Function()? finals,
    double? crowd,
    Map<String, double>? floorOverrides,
  }) => DevSettings(
    hour: hour != null ? hour() : this.hour,
    weekday: weekday != null ? weekday() : this.weekday,
    finals: finals != null ? finals() : this.finals,
    crowd: crowd ?? this.crowd,
    floorOverrides: floorOverrides ?? this.floorOverrides,
  );

  factory DevSettings.fromJson(Map<String, dynamic> json) => DevSettings(
    hour: (json['hour'] as num?)?.toDouble(),
    weekday: json['weekday'] as int?,
    finals: json['finals'] as bool?,
    crowd: (json['crowd'] as num).toDouble(),
    floorOverrides: (json['floor_overrides'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, (v as num).toDouble()),
    ),
  );

  Map<String, dynamic> toJson() => {
    'hour': hour,
    'weekday': weekday,
    'finals': finals,
    'crowd': crowd,
    'floor_overrides': floorOverrides,
  };
}
