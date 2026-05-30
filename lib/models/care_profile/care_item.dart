/// Eine einzelne Pflege-Kategorie (z.B. Wasser, Licht).
class CareItem {
  final String shortValue;
  final String detail;

  const CareItem({
    required this.shortValue,
    required this.detail,
  });

  factory CareItem.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CareItem(shortValue: '–', detail: '');
    return CareItem(
      shortValue: json['short_value'] as String? ?? '–',
      detail: json['detail'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'short_value': shortValue,
        'detail': detail,
      };
}

/// Temperatur-Kategorie mit zusätzlichen Min/Max-Werten.
class TemperatureRange extends CareItem {
  final double? minCelsius;
  final double? maxCelsius;

  const TemperatureRange({
    required super.shortValue,
    required super.detail,
    this.minCelsius,
    this.maxCelsius,
  });

  factory TemperatureRange.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const TemperatureRange(shortValue: '–', detail: '');
    }
    return TemperatureRange(
      shortValue: json['short_value'] as String? ?? '–',
      detail: json['detail'] as String? ?? '',
      minCelsius: (json['min_celsius'] as num?)?.toDouble(),
      maxCelsius: (json['max_celsius'] as num?)?.toDouble(),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        if (minCelsius != null) 'min_celsius': minCelsius,
        if (maxCelsius != null) 'max_celsius': maxCelsius,
      };
}
