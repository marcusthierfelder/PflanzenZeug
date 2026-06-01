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
      "confidence": "high|medium|low",
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

  /// Sorgfaltspflicht-Block: wird in beide Prompt-Varianten eingebettet.
  ///
  /// Enthält Beleuchtungs-Klausel, Edge-Case-Liste und Gesund-Regel.
  static const String _dueDiligenceBlock = '''

=== DIAGNOSTISCHE SORGFALTSPFLICHT ===

**Farb-Aussagen und Beleuchtung:**
Kamerafotos können durch Weißabgleich, Kunstlicht (LED, Neon) oder starkes Gegenlicht Farben verfälschen.
Mache EINEN Farb-Befund (z. B. "Blätter vergilben") NUR dann, wenn:
  - Die Verfärbung an MEHREREN Stellen eindeutig sichtbar ist UND
  - Die Grundfarbe des restlichen Blattes klar abweicht (nicht nur leicht anders getönt).
Bei Unsicherheit über die echte Blattfarbe: confidence = "low" oder Befund weglassen.

**Bekannte Verwechslungs-Fallen – diese Merkmale sind ART-NORMAL und KEIN Befund:**
  - Monstera deliciosa / Philodendron / Epipremnum: Braune, korkige, fadenförmige LUFTWURZELN sind artypisch und völlig normal. Keine Fehldiagnose "vertrocknet", "Wurzelfäule" oder "Mangelerscheinung" für diese Strukturen.
  - Sukkulenten / Echeveria / Sedum: Blaugrauer oder silbriger Wachsfilm (Bereifung / Pruinose) ist normale Schutzschicht – NICHT Mehltau oder Schimmel.
  - Panaschierte / bunte Sorten (Variegaten): Cremefarbene, weiße oder gelbe Blatt-Sektionen sind genetisch bedingt – NICHT Chlorose oder Nährstoffmangel.
  - Sansevieria (Bogenhanf) / Zamioculcas (ZZ-Pflanze): Feste, ledriger Stängel- und Blattstruktur ist artypisch – NICHT Überwässerung oder Trockenheit.
  - Ficus benjamina / Citrus spp.: Blattfall an älteren Blättern ist normaler Entwicklungsprozess – NICHT zwingend ein Stresssymptom.
  - Kakteen (Cactaceae): Weiße, filzige Trichome (Areolen, Haare) sind artypisch – NICHT Wollläuse oder Mehltau, solange keine klebrige Substanz vorhanden.
  - Orchideen (Phalaenopsis, Cattleya u. a.): Silbrig-grüne oder braune LUFTWURZELN sind artypisch und zeigen normalen Trockenheits-/Feuchtigkeitszustand – KEIN Befund.

**Gesund-Regel:**
Wenn die Pflanze insgesamt gesund wirkt und kein eindeutiger Befund vorliegt:
  → Setze overall_health = "good" UND gib ein LEERES findings-Array ([]) zurück.
  → Erfinde KEINE Probleme um den Befund-Bereich zu füllen.

**Confidence-Feld (Pflicht für jeden Befund):**
  - "high" → Eindeutiger Befund, klare Sichtbarkeit, mehrere Belege
  - "medium" → Wahrscheinlicher Befund, aber nicht 100 % eindeutig
  - "low" → Möglicher Befund; Grundlage unsicher (Licht, Fotoqualität, Einzelmerkmal)

=== ENDE SORGFALTSPFLICHT ===
''';

  /// Prompt-Baustein: JSON-Instruktion (Claude, mit Prefill-Trick).
  static const String claudeJsonInstruction = '''

WICHTIG: Antworte AUSSCHLIESSLICH mit einem JSON-Objekt – kein Text davor, kein Text danach, keine Markdown-Code-Fences.
Antworte immer auf Deutsch. Alle Texte im JSON ausschließlich auf Deutsch.
Das JSON muss exakt diesem Schema entsprechen:

$schemaDescription

Hinweise:
- "overall_health": genau einer von "good", "fair", "poor", "critical"
- "findings": Array mit 0–6 Einträgen; leer ([]) wenn keine Befunde
- "type": genau einer von "disease", "pest", "deficiency", "environmental"
- "severity": genau einer von "high", "medium", "low"
- "confidence": genau einer von "high", "medium", "low" (Pflicht)
- "recommendations.fertilizer": Objekt mit "advice" und optionalem "product"
- "comparison_to_previous": null wenn keine Vordiagnose vorhanden
- WICHTIG: Antworte immer auf Deutsch. Alle Texte im JSON ausschließlich auf Deutsch.''';

  /// Prompt-Baustein: JSON-Instruktion (DeepSeek, response_format: json_object).
  static const String deepseekJsonInstruction = '''

Antworte immer auf Deutsch. Alle Texte im JSON ausschließlich auf Deutsch.
Antworte mit einem JSON-Objekt das exakt diesem Schema entspricht:

$schemaDescription

Hinweise:
- "overall_health": genau einer von "good", "fair", "poor", "critical"
- "findings": Array mit 0–6 Einträgen; leer ([]) wenn keine Befunde
- "type": genau einer von "disease", "pest", "deficiency", "environmental"
- "severity": genau einer von "high", "medium", "low"
- "confidence": genau einer von "high", "medium", "low" (Pflicht)
- "recommendations.fertilizer": Objekt mit "advice" und optionalem "product"
- "comparison_to_previous": null wenn keine Vordiagnose vorhanden
- WICHTIG: Antworte immer auf Deutsch. Alle Texte im JSON ausschließlich auf Deutsch.''';

  /// Baut den vollständigen Diagnose-Prompt für Claude.
  static String buildClaudePrompt({
    required String plantName,
    String? location,
    String? potInfo,
    bool isMixedPot = false,
    String? previousDiagnosis,
    bool hasHistoricalImages = false,
    List<String> availableFertilizerNames = const [],
    String? speciesNotes,
    String? userContext,
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
      speciesNotes: speciesNotes,
      userContext: userContext,
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
    String? speciesNotes,
    String? userContext,
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
      speciesNotes: speciesNotes,
      userContext: userContext,
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
    String? speciesNotes,
    String? userContext,
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

    // Art-spezifische Hinweise aus der Bestimmung – größter Hebel für korrekte Diagnose
    if (speciesNotes != null && speciesNotes.isNotEmpty) {
      buf.writeln();
      buf.writeln('Art-spezifische Hinweise aus der Pflanzenbestimmung:');
      buf.writeln(speciesNotes);
    }

    // Sorgfaltspflicht-Block direkt nach Pflanzennamen/Arthinweisen
    buf.write(_dueDiligenceBlock);

    // Nutzer-Foto-Kontext (Tag-basiert) – direkt nach Sorgfaltspflicht
    if (userContext != null && userContext.isNotEmpty) {
      buf.writeln();
      buf.writeln(userContext);
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
