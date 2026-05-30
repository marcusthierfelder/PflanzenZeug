import 'care_item.dart';

/// Vollständiges Pflege-Profil einer Pflanze.
///
/// Alle Felder sind defensiv (optional), fromJson wirft niemals.
class CareProfile {
  final CareItem water;
  final CareItem light;
  final TemperatureRange temperature;
  final CareItem humidity;
  final CareItem fertilizer;
  final CareItem repotting;

  const CareProfile({
    required this.water,
    required this.light,
    required this.temperature,
    required this.humidity,
    required this.fertilizer,
    required this.repotting,
  });

  factory CareProfile.empty() => CareProfile(
        water: const CareItem(shortValue: '–', detail: ''),
        light: const CareItem(shortValue: '–', detail: ''),
        temperature: const TemperatureRange(shortValue: '–', detail: ''),
        humidity: const CareItem(shortValue: '–', detail: ''),
        fertilizer: const CareItem(shortValue: '–', detail: ''),
        repotting: const CareItem(shortValue: '–', detail: ''),
      );

  factory CareProfile.fromJson(Map<String, dynamic>? json) {
    if (json == null) return CareProfile.empty();
    return CareProfile(
      water: CareItem.fromJson(json['water'] as Map<String, dynamic>?),
      light: CareItem.fromJson(json['light'] as Map<String, dynamic>?),
      temperature: TemperatureRange.fromJson(
          json['temperature'] as Map<String, dynamic>?),
      humidity: CareItem.fromJson(json['humidity'] as Map<String, dynamic>?),
      fertilizer:
          CareItem.fromJson(json['fertilizer'] as Map<String, dynamic>?),
      repotting: CareItem.fromJson(json['repotting'] as Map<String, dynamic>?),
    );
  }

  Map<String, dynamic> toJson() => {
        'water': water.toJson(),
        'light': light.toJson(),
        'temperature': temperature.toJson(),
        'humidity': humidity.toJson(),
        'fertilizer': fertilizer.toJson(),
        'repotting': repotting.toJson(),
      };
}
