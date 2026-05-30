/// Single Source of Truth für das JSON-Schema der Pflanzen-Diagnose.
///
/// Wird von ClaudeService und DeepSeekService verwendet.
class DiagnosisSchema {
  DiagnosisSchema._();

  /// JSON-Schema als Referenz-String (für Prompt-Embedding).
  static const String schemaDescription = r'''
{
  "overall_health": "good|fair|poor|critical",
  "summary": "Kurze Gesamtzusammenfassung des Zustands auf Deutsch (2–3 Sätze)",
  "findings": [
    {
      "type": "disease|pest|deficiency|environmental",
      "severity": "high|medium|low",
      "title": "Kurzer Befund-Titel auf Deutsch",
      "evidence": "Was genau ist auf den Bildern sichtbar? (konkret)",
      "treatment": "Empfohlene Behandlung / Gegenmittel auf Deutsch"
    }
  ],
  "recommendations": {
    "watering": "Gieß-Empfehlung auf Deutsch",
    "fertilizer": {
      "advice": "Dünge-Empfehlung auf Deutsch",
      "product": "Konkreter Produktname falls bekannt, sonst null"
    },
    "location": "Standort-Empfehlung auf Deutsch",
    "other": ["Weitere Maßnahmen als Strings auf Deutsch"]
  },
  "comparison_to_previous": "Vergleich zur letzten Diagnose falls vorhanden, sonst null"
}
''';

  /// Prompt-Baustein: JSON-Instruktion (Claude, mit Prefill-Trick).
  static const String claudeJsonInstruction = '''

WICHTIG: Antworte AUSSCHLIESSLICH mit einem JSON-Objekt – kein Text davor, kein Text danach, keine Markdown-Code-Fences.
Das JSON muss exakt diesem Schema entsprechen:

$schemaDescription

Hinweise:
- "overall_health": genau einer von "good", "fair", "poor", "critical"
- "findings": Array mit 0–6 Einträgen; leer wenn keine Befunde
- "type": genau einer von "disease", "pest", "deficiency", "environmental"
- "severity": genau einer von "high", "medium", "low"
- "recommendations.fertilizer": Objekt mit "advice" und optionalem "product"
- "comparison_to_previous": null wenn keine Vordiagnose vorhanden
- Alle Texte auf Deutsch''';

  /// Prompt-Baustein: JSON-Instruktion (DeepSeek, response_format: json_object).
  static const String deepseekJsonInstruction = '''

Antworte mit einem JSON-Objekt das exakt diesem Schema entspricht:

$schemaDescription

Hinweise:
- "overall_health": genau einer von "good", "fair", "poor", "critical"
- "findings": Array mit 0–6 Einträgen; leer wenn keine Befunde
- "type": genau einer von "disease", "pest", "deficiency", "environmental"
- "severity": genau einer von "high", "medium", "low"
- "recommendations.fertilizer": Objekt mit "advice" und optionalem "product"
- "comparison_to_previous": null wenn keine Vordiagnose vorhanden
- Alle Texte auf Deutsch''';

  /// Baut den vollständigen Diagnose-Prompt für Claude.
  static String buildClaudePrompt({
    required String plantName,
    String? location,
    String? potInfo,
    bool isMixedPot = false,
    String? previousDiagnosis,
    bool hasHistoricalImages = false,
    List<String> availableFertilizerNames = const [],
  }) {
    return _buildPrompt(
      plantName: plantName,
      location: location,
      potInfo: potInfo,
      isMixedPot: isMixedPot,
      previousDiagnosis: previousDiagnosis,
      hasHistoricalImages: hasHistoricalImages,
      availableFertilizerNames: availableFertilizerNames,
      jsonInstruction: claudeJsonInstruction,
    );
  }

  /// Baut den vollständigen Diagnose-Prompt für DeepSeek.
  static String buildDeepSeekPrompt({
    required String plantName,
    String? location,
    String? potInfo,
    bool isMixedPot = false,
    String? previousDiagnosis,
    bool hasHistoricalImages = false,
    List<String> availableFertilizerNames = const [],
  }) {
    return _buildPrompt(
      plantName: plantName,
      location: location,
      potInfo: potInfo,
      isMixedPot: isMixedPot,
      previousDiagnosis: previousDiagnosis,
      hasHistoricalImages: hasHistoricalImages,
      availableFertilizerNames: availableFertilizerNames,
      jsonInstruction: deepseekJsonInstruction,
    );
  }

  static String _buildPrompt({
    required String plantName,
    String? location,
    String? potInfo,
    required bool isMixedPot,
    String? previousDiagnosis,
    required bool hasHistoricalImages,
    required List<String> availableFertilizerNames,
    required String jsonInstruction,
  }) {
    final buf = StringBuffer();

    if (isMixedPot) {
      buf.writeln(
        'In diesem Topf wachsen MEHRERE Pflanzen zusammen, identifiziert als "$plantName". '
        'Analysiere ALLE Arten gemeinsam und beachte Wechselwirkungen.',
      );
    } else {
      buf.writeln('Diese Pflanze wurde als "$plantName" identifiziert.');
    }

    if ((location != null && location.isNotEmpty) ||
        (potInfo != null && potInfo.isNotEmpty)) {
      buf.writeln();
      buf.write('Aktuelle Bedingungen:');
      if (location != null && location.isNotEmpty) {
        buf.write(' Standort: $location.');
      }
      if (potInfo != null && potInfo.isNotEmpty) {
        buf.write(' Topf: $potInfo.');
      }
    }

    if (previousDiagnosis != null && previousDiagnosis.isNotEmpty) {
      buf.writeln();
      buf.writeln();
      buf.writeln('Letzte Diagnose (zum Vergleich):');
      buf.writeln(previousDiagnosis);
    }

    if (hasHistoricalImages) {
      buf.writeln();
      buf.writeln(
        'Die älteren Fotos zeigen den früheren Zustand der Pflanze. '
        'Vergleiche sie mit den aktuellen Fotos und beschreibe Veränderungen in "comparison_to_previous".',
      );
    }

    if (availableFertilizerNames.isNotEmpty) {
      buf.writeln();
      buf.writeln(
        'Verfügbare Dünger des Nutzers (bevorzuge einen davon in der Empfehlung):',
      );
      for (final name in availableFertilizerNames) {
        buf.writeln('- $name');
      }
    }

    buf.write(jsonInstruction);
    return buf.toString();
  }
}
