import 'dart:convert';
import 'finding.dart';
import 'recommendations.dart';

/// Gesamtzustand der Pflanze.
enum OverallHealth {
  good,
  fair,
  poor,
  critical;

  /// Deutsches Anzeige-Label.
  String get label => switch (this) {
        OverallHealth.good => 'Pflanze ist gesund',
        OverallHealth.fair => 'Kleine Auffälligkeiten',
        OverallHealth.poor => 'Behandlung nötig',
        OverallHealth.critical => 'Akut handeln',
      };

  static OverallHealth fromString(String value) {
    return switch (value.toLowerCase()) {
      'good' => OverallHealth.good,
      'fair' => OverallHealth.fair,
      'poor' => OverallHealth.poor,
      'critical' => OverallHealth.critical,
      _ => OverallHealth.fair,
    };
  }
}

/// Vollständiges Diagnose-Ergebnis.
class DiagnosisResult {
  final OverallHealth overallHealth;
  final String summary;
  final List<Finding> findings;
  final Recommendations recommendations;
  final String? comparisonToPrevious;

  const DiagnosisResult({
    required this.overallHealth,
    required this.summary,
    required this.findings,
    required this.recommendations,
    this.comparisonToPrevious,
  });

  factory DiagnosisResult.fromJson(Map<String, dynamic> json) =>
      DiagnosisResult(
        overallHealth: OverallHealth.fromString(
          json['overall_health'] as String? ?? 'fair',
        ),
        summary: json['summary'] as String? ?? '',
        findings: (json['findings'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(Finding.fromJson)
                .toList() ??
            [],
        recommendations: Recommendations.fromJson(
          json['recommendations'] as Map<String, dynamic>? ?? {},
        ),
        comparisonToPrevious: json['comparison_to_previous'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'overall_health': overallHealth.name,
        'summary': summary,
        'findings': findings.map((f) => f.toJson()).toList(),
        'recommendations': recommendations.toJson(),
        if (comparisonToPrevious != null)
          'comparison_to_previous': comparisonToPrevious,
      };

  /// Serialisiert das Ergebnis als JSON-String für die DB-Persistenz.
  String toJsonString() => jsonEncode(toJson());

  /// Konvertiert das strukturierte Ergebnis in Markdown für den Chat-Kontext.
  String toMarkdown() {
    final buf = StringBuffer();

    buf.writeln('## Diagnose-Ergebnis');
    buf.writeln('**Gesundheitszustand:** ${overallHealth.label}');
    buf.writeln();
    buf.writeln(summary);

    if (comparisonToPrevious != null && comparisonToPrevious!.isNotEmpty) {
      buf.writeln();
      buf.writeln('### Vergleich zur letzten Diagnose');
      buf.writeln(comparisonToPrevious);
    }

    if (findings.isNotEmpty) {
      buf.writeln();
      buf.writeln('### Befunde');
      for (final f in findings) {
        final severityLabel = '[${f.severity.label}]';
        buf.writeln('**${f.type.label} $severityLabel: ${f.title}**');
        if (f.evidence.isNotEmpty) buf.writeln('- *Evidenz:* ${f.evidence}');
        if (f.treatment.isNotEmpty) {
          buf.writeln('- *Behandlung:* ${f.treatment}');
        }
        buf.writeln();
      }
    }

    buf.writeln('### Empfehlungen');
    if (recommendations.watering.isNotEmpty) {
      buf.writeln('- **Gießen:** ${recommendations.watering}');
    }
    if (recommendations.fertilizer.advice.isNotEmpty) {
      buf.writeln('- **Dünger:** ${recommendations.fertilizer}');
    }
    if (recommendations.location.isNotEmpty) {
      buf.writeln('- **Standort:** ${recommendations.location}');
    }
    for (final o in recommendations.other) {
      buf.writeln('- $o');
    }

    return buf.toString().trim();
  }
}
