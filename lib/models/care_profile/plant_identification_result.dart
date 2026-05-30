import 'care_profile.dart';
import 'difficulty.dart';
import 'toxicity.dart';

/// Vollständiges strukturiertes Ergebnis der Pflanzen-Identifikation.
///
/// Alle Felder sind defensiv optional; fromJson wirft niemals.
class PlantIdentificationResult {
  final String name;
  final String? scientificName;
  final String? family;
  final int? confidence;
  final CareProfile careProfile;
  final Difficulty difficulty;
  final Toxicity toxicity;
  final String? diagnosticNotes;
  final String? additionalNotes;

  const PlantIdentificationResult({
    required this.name,
    this.scientificName,
    this.family,
    this.confidence,
    required this.careProfile,
    required this.difficulty,
    required this.toxicity,
    this.diagnosticNotes,
    this.additionalNotes,
  });

  factory PlantIdentificationResult.fromJson(Map<String, dynamic> json) {
    return PlantIdentificationResult(
      name: json['name'] as String? ?? 'Unbekannte Pflanze',
      scientificName: json['scientific_name'] as String?,
      family: json['family'] as String?,
      confidence: (json['confidence'] as num?)?.toInt(),
      careProfile: CareProfile.fromJson(
          json['care_profile'] as Map<String, dynamic>?),
      difficulty: Difficulty.fromString(json['difficulty'] as String?),
      toxicity: Toxicity.fromJson(json['toxicity'] as Map<String, dynamic>?),
      diagnosticNotes: json['diagnostic_notes'] as String?,
      additionalNotes: json['additional_notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (scientificName != null) 'scientific_name': scientificName,
        if (family != null) 'family': family,
        if (confidence != null) 'confidence': confidence,
        'care_profile': careProfile.toJson(),
        'difficulty': difficulty.name,
        'toxicity': toxicity.toJson(),
        if (diagnosticNotes != null) 'diagnostic_notes': diagnosticNotes,
        if (additionalNotes != null) 'additional_notes': additionalNotes,
      };
}
