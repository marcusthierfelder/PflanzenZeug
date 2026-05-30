/// Typen eines Befunds.
enum FindingType {
  disease,
  pest,
  deficiency,
  environmental;

  /// Deutsches Anzeige-Label.
  String get label => switch (this) {
        FindingType.disease => 'Krankheit',
        FindingType.pest => 'Schädling',
        FindingType.deficiency => 'Mangelerscheinung',
        FindingType.environmental => 'Umweltfaktor',
      };

  /// Material-Icon-Name.
  String get iconName => switch (this) {
        FindingType.disease => 'coronavirus',
        FindingType.pest => 'bug_report',
        FindingType.deficiency => 'science',
        FindingType.environmental => 'wb_sunny',
      };

  static FindingType fromString(String value) {
    return switch (value.toLowerCase()) {
      'disease' => FindingType.disease,
      'pest' => FindingType.pest,
      'deficiency' => FindingType.deficiency,
      'environmental' => FindingType.environmental,
      _ => FindingType.environmental,
    };
  }
}

/// Schweregrad eines Befunds.
enum Severity {
  high,
  medium,
  low;

  /// Sortier-Gewicht (höher = schwerer).
  int get weight => switch (this) {
        Severity.high => 3,
        Severity.medium => 2,
        Severity.low => 1,
      };

  /// Deutsches Anzeige-Label.
  String get label => switch (this) {
        Severity.high => 'Schwerwiegend',
        Severity.medium => 'Mittel',
        Severity.low => 'Leicht',
      };

  static Severity fromString(String value) {
    return switch (value.toLowerCase()) {
      'high' => Severity.high,
      'medium' => Severity.medium,
      'low' => Severity.low,
      _ => Severity.low,
    };
  }
}

/// Ein einzelner Befund der Pflanzen-Diagnose.
class Finding {
  final FindingType type;
  final Severity severity;
  final String title;
  final String evidence;
  final String treatment;

  const Finding({
    required this.type,
    required this.severity,
    required this.title,
    required this.evidence,
    required this.treatment,
  });

  factory Finding.fromJson(Map<String, dynamic> json) => Finding(
        type: FindingType.fromString(json['type'] as String? ?? ''),
        severity: Severity.fromString(json['severity'] as String? ?? 'low'),
        title: json['title'] as String? ?? 'Unbekannter Befund',
        evidence: json['evidence'] as String? ?? '',
        treatment: json['treatment'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'severity': severity.name,
        'title': title,
        'evidence': evidence,
        'treatment': treatment,
      };
}
