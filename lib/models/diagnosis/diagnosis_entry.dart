import 'dart:convert';
import 'diagnosis_result.dart';

/// Persistierter Eintrag einer Diagnose-Sitzung pro Pflanze.
///
/// Wird als eigenständige Hive-Box-Entität gespeichert und ermöglicht
/// damit eine vollständige Diagnose-Historie ohne Überschreiben älterer Einträge.
class DiagnosisEntry {
  /// Eindeutige ID (UUID v4).
  final String id;

  /// Fremdschlüssel zur zugehörigen Pflanze.
  final String plantId;

  /// Zeitpunkt der Diagnose.
  final DateTime createdAt;

  /// Gesamtzustand der Pflanze.
  final OverallHealth overallHealth;

  /// Kurzfassung des Befunds.
  final String summary;

  /// Vollständiges Diagnose-Ergebnis als JSON-String (DiagnosisResult).
  final String diagnosisResultJson;

  /// Permanente Dateinamen der verwendeten Fotos (relativ zu _imageDir).
  /// Werden beim Speichern aus dem Temp-Verzeichnis kopiert.
  final List<String> photoPaths;

  /// Optionaler Kontext-Tag (CaptureContextTag.tagKeyString) der Diagnose-Session.
  final String? contextTag;

  const DiagnosisEntry({
    required this.id,
    required this.plantId,
    required this.createdAt,
    required this.overallHealth,
    required this.summary,
    required this.diagnosisResultJson,
    required this.photoPaths,
    this.contextTag,
  });

  /// Deserialisiert das gespeicherte diagnosisResultJson zu einem [DiagnosisResult].
  DiagnosisResult get diagnosisResult {
    final map = (jsonDecode(diagnosisResultJson) as Map).cast<String, dynamic>();
    return DiagnosisResult.fromJson(map);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'plantId': plantId,
        'createdAt': createdAt.toIso8601String(),
        'overallHealth': overallHealth.name,
        'summary': summary,
        'diagnosisResultJson': diagnosisResultJson,
        'photoPaths': photoPaths,
        if (contextTag != null) 'contextTag': contextTag,
      };

  factory DiagnosisEntry.fromJson(Map<dynamic, dynamic> json) {
    final rawPaths = json['photoPaths'];
    final paths = rawPaths is List
        ? rawPaths.cast<String>().toList()
        : <String>[];

    return DiagnosisEntry(
      id: json['id'] as String,
      plantId: json['plantId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      overallHealth: OverallHealth.fromString(json['overallHealth'] as String? ?? 'fair'),
      summary: json['summary'] as String? ?? '',
      diagnosisResultJson: json['diagnosisResultJson'] as String,
      photoPaths: paths,
      contextTag: json['contextTag'] as String?,
    );
  }
}
