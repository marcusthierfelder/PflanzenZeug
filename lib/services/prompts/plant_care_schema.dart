/// Single Source of Truth für das JSON-Schema der Pflanzen-Identifikation.
///
/// Wird von ClaudeService und DeepSeekService verwendet.
/// Enthält auch den Prompt-Text für den Identifikations-Request.
class PlantCareSchema {
  PlantCareSchema._();

  /// JSON-Schema-Beschreibung als String (für System-Prompt).
  static const String schemaDescription = r'''
{
  "name": "Deutscher Pflanzenname",
  "scientific_name": "Gattung Art (Autor)",
  "family": "Pflanzenfamilie",
  "confidence": 85,
  "care_profile": {
    "water": {
      "short_value": "1–2x pro Woche",
      "detail": "Im Sommer regelmäßig gießen, Staunässe vermeiden. Im Winter nur sparsam."
    },
    "light": {
      "short_value": "Heller Standort",
      "detail": "Bevorzugt helle Lagen ohne direkte Mittagssonne. Verträgt auch Halbschatten."
    },
    "temperature": {
      "short_value": "18–24 °C",
      "min_celsius": 15,
      "max_celsius": 30,
      "detail": "Verträgt keine Temperaturen unter 10 °C. Frostempfindlich."
    },
    "humidity": {
      "short_value": "Mittel (50–60%)",
      "detail": "Gelegentlich besprühen oder Wasserschale aufstellen."
    },
    "fertilizer": {
      "short_value": "April–Sept. alle 4 Wo.",
      "detail": "Flüssigdünger für Grünpflanzen, Konzentration halbieren."
    },
    "repotting": {
      "short_value": "Alle 2–3 Jahre",
      "detail": "Im Frühjahr umtopfen, wenn Wurzeln aus dem Topf herauswachsen."
    }
  },
  "difficulty": "easy",
  "toxicity": {
    "is_toxic": false,
    "affected": [],
    "detail": ""
  },
  "diagnostic_notes": "Diagnostische Merkmale die zur Bestimmung geführt haben.",
  "additional_notes": "Weitere narrative Hinweise, Besonderheiten, Herkunft etc."
}
''';

  /// Vollständiger Prompt-Text für die Pflanzen-Identifikation (Claude).
  static String buildIdentifyPrompt({
    required int imageCount,
    required bool isMixedPot,
  }) {
    final context = isMixedPot
        ? 'In diesem Topf wachsen MEHRERE Pflanzen zusammen. '
            'Identifiziere ALLE sichtbaren Arten anhand der $imageCount Bilder. '
            'Verwende für "name" das Format "Mischtopf: Art1 & Art2". '
            'Beschreibe in "diagnostic_notes" ALLE erkannten Arten mit ihren diagnostischen Merkmalen. '
            'Gib ein care_profile zurück, das die gemeinsamen Anforderungen aller Arten berücksichtigt '
            '(verwende den restriktivsten gemeinsamen Nenner, z.B. wenigstens gießen wenn eine Art empfindlich ist). '
            'Notiere Kompatibilitätskonflikte in "additional_notes".'
        : 'Identifiziere diese Pflanze anhand der $imageCount Bilder. '
            'Berücksichtige alle erkennbaren Merkmale: '
            'Blattform, Blattstellung, Blattoberfläche, Wuchsform, Blüten, Früchte, Rinde, Wurzeln.';

    return '''$context

Stütze die Bestimmung auf botanische Fachliteratur und -datenbanken 
(Zander Handwörterbuch der Pflanzennamen, Rothmaler Flora von Deutschland, 
Plants of the World Online / Kew, RHS Encyclopaedia of Plants, Tropicos).

WICHTIG: Antworte AUSSCHLIESSLICH mit einem JSON-Objekt – kein Text davor, kein Text danach, keine Markdown-Code-Fences.
Das JSON muss exakt diesem Schema entsprechen:

$schemaDescription

Hinweise zu den Feldern:
- "confidence": Zahl 0–100
- "difficulty": genau einer von "easy", "medium", "hard", "unknown"
- "toxicity.is_toxic": boolean; "affected" ist ein Array (z.B. ["Menschen", "Katzen", "Hunde"])
- Alle care_profile-Felder sind Pflicht; wenn unbekannt, schreibe sinnvolle Schätzwerte auf Basis der Gattung
- Bei Sicherheit unter 80%: Nenne in "additional_notes" die 2–3 wahrscheinlichsten Kandidaten mit Wahrscheinlichkeit
- "additional_notes": freier Markdown-Text mit narrativen Ergänzungen (Herkunft, Besonderheiten, Kulturhinweise)
- WICHTIG: Antworte immer auf Deutsch. Alle Texte im JSON ausschließlich auf Deutsch.''';
  }

  /// Prompt-Text für DeepSeek (JSON-Mode, kein Prefill nötig).
  static String buildIdentifyPromptDeepSeek({
    required int imageCount,
    required bool isMixedPot,
  }) {
    return buildIdentifyPrompt(imageCount: imageCount, isMixedPot: isMixedPot);
  }
}
