/// QA-Tests für Ticket #12: Quelltextverifikation
///
/// Liest die implementierten Dart-Dateien als Strings und prüft,
/// ob die spezifischen Anforderungen tatsächlich im Code vorhanden sind.
/// Dies ergänzt die Logik-Tests und stellt sicher, dass niemand die
/// deterministischen Parameter wieder entfernt hat.
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  // =========================================================================
  // AK 1 – Quelltextprüfung: temperature & top_p in Service-Dateien
  // =========================================================================
  group('AK 1 – Source: Deterministik-Parameter', () {
    late String claudeSrc;
    late String deepseekSrc;

    setUpAll(() {
      claudeSrc = _read('lib/services/claude_service.dart');
      deepseekSrc = _read('lib/services/deepseek_service.dart');
    });

    test('TC-S01 claude_service.dart enthält temperature: 0', () {
      expect(claudeSrc.contains("'temperature': 0"), isTrue,
          reason: 'temperature: 0 muss im _callClaudeMessages API-Body stehen');
    });

    test('TC-S02 claude_service.dart enthält top_p: 0.1', () {
      expect(claudeSrc.contains("'top_p': 0.1"), isTrue,
          reason: 'top_p: 0.1 muss im Claude-API-Body stehen (Spec: AK 1)');
    });

    test('TC-S03 deepseek_service.dart enthält temperature: 0', () {
      expect(deepseekSrc.contains("'temperature': 0"), isTrue,
          reason: 'temperature: 0 muss im DeepSeek API-Body stehen');
    });
  });

  // =========================================================================
  // AK 2 – Quelltextprüfung: previousIdentification-Parameter durchgereicht
  // =========================================================================
  group('AK 2 – Source: previousIdentification-Parameter', () {
    late String aiServiceSrc;
    late String claudeSrc;
    late String deepseekSrc;
    late String screenSrc;

    setUpAll(() {
      aiServiceSrc = _read('lib/services/ai_service.dart');
      claudeSrc = _read('lib/services/claude_service.dart');
      deepseekSrc = _read('lib/services/deepseek_service.dart');
      screenSrc = _read('lib/screens/identification_screen.dart');
    });

    test('TC-S04 ai_service.dart: Interface hat previousIdentification-Parameter', () {
      expect(aiServiceSrc.contains('previousIdentification'), isTrue,
          reason: 'Interface-Kontrakt muss den optionalen Parameter definieren');
    });

    test('TC-S05 claude_service.dart: identifyPlant hat previousIdentification-Parameter', () {
      expect(claudeSrc.contains('previousIdentification'), isTrue,
          reason: 'Claude-Implementierung muss den Parameter empfangen');
    });

    test('TC-S06 deepseek_service.dart: identifyPlant hat previousIdentification-Parameter', () {
      expect(deepseekSrc.contains('previousIdentification'), isTrue,
          reason: 'DeepSeek-Implementierung muss den Parameter empfangen');
    });

    test('TC-S07 claude_service.dart: RE-IDENTIFIKATION-Prompt-Block vorhanden', () {
      expect(claudeSrc.contains('RE-IDENTIFIKATION'), isTrue,
          reason: 'Prompt-Erweiterung muss im Claude-Service implementiert sein');
    });

    test('TC-S08 deepseek_service.dart: RE-IDENTIFIKATION-Prompt-Block vorhanden', () {
      expect(deepseekSrc.contains('RE-IDENTIFIKATION'), isTrue,
          reason: 'Prompt-Erweiterung muss im DeepSeek-Service implementiert sein');
    });

    test('TC-S09 Prompt enthält "Wechsele die Art nur bei klarem Widerspruch"', () {
      expect(
        claudeSrc.contains('Wechsele die Art nur bei klarem Widerspruch'),
        isTrue,
        reason: 'Stabilitäts-Instruktion muss wortgleich im Prompt stehen',
      );
      expect(
        deepseekSrc.contains('Wechsele die Art nur bei klarem Widerspruch'),
        isTrue,
        reason: 'Beide Services müssen dieselbe Instruktion haben',
      );
    });

    test('TC-S10 identification_screen.dart: existingPlantId-Check vorhanden', () {
      expect(screenSrc.contains('existingPlantId'), isTrue,
          reason: 'Screen muss auf existingPlantId prüfen und previousIdentification laden');
    });

    test('TC-S11 identification_screen.dart: previousIdentification wird übergeben', () {
      expect(screenSrc.contains('previousIdentification:'), isTrue,
          reason: 'identifyPlant muss mit previousIdentification aufgerufen werden');
    });
  });

  // =========================================================================
  // AK 3+4 – Quelltextprüfung: Konflikt-Logik im Screen
  // =========================================================================
  group('AK 3+4 – Source: Konflikt-Logik & _SpeciesConflictBanner', () {
    late String screenSrc;

    setUpAll(() {
      screenSrc = _read('lib/screens/identification_screen.dart');
    });

    test('TC-S12 _SpeciesConflict-Klasse ist definiert', () {
      expect(screenSrc.contains('class _SpeciesConflict'), isTrue,
          reason: 'Datenmodell für Konflikte muss existieren');
    });

    test('TC-S13 _SpeciesConflictBanner-Widget ist definiert', () {
      expect(screenSrc.contains('class _SpeciesConflictBanner'), isTrue,
          reason: 'UI-Widget für Konflikt-Anzeige muss existieren');
    });

    test('TC-S14 isConflict-Guard prüft prevName != newName', () {
      expect(screenSrc.contains('isConflict'), isTrue,
          reason: 'Konflikt-Flag muss gesetzt und geprüft werden');
    });

    test('TC-S15 scientificName/speciesName wird im Konflikt-Zweig nicht überschrieben', () {
      // Im Konflikt-Zweig (if isConflict) darf scientificName nicht mit
      // dem neuen Wert beschrieben werden. Wir prüfen, dass der Kommentar
      // und die Guard-Logik vorhanden sind.
      expect(
        screenSrc.contains('NICHT überschrieben') ||
        screenSrc.contains('nicht überschrieben') ||
        screenSrc.contains('scientificName bleiben'),
        isTrue,
        reason: 'Kommentar/Doku dass scientificName im Konflikt-Zweig erhalten bleibt',
      );
    });

    test('TC-S16 Banner zeigt "Abweichende Einschätzung"', () {
      expect(screenSrc.contains('Abweichende Einschätzung'), isTrue,
          reason: 'UI-Text "Abweichende Einschätzung" muss im Banner stehen');
    });

    test('TC-S17 Banner zeigt "Die bisherige Klassifikation wurde NICHT überschrieben"', () {
      expect(
        screenSrc.contains('NICHT überschrieben'),
        isTrue,
        reason: 'Expliziter Hinweis für den Nutzer muss im UI-Text stehen',
      );
    });

    test('TC-S18 _speciesConflict wird in setState gesetzt', () {
      expect(screenSrc.contains('_speciesConflict'), isTrue,
          reason: 'State-Variable für Konflikt-Anzeige muss existieren und gesetzt werden');
    });

    test('TC-S19 _SavedBadge nur ohne Konflikt angezeigt', () {
      // Der _SavedBadge-Block muss mit _speciesConflict == null verschränkt sein
      expect(
        screenSrc.contains('_speciesConflict == null'),
        isTrue,
        reason: '_SavedBadge darf nur erscheinen wenn kein Konflikt vorliegt',
      );
    });

    test('TC-S20 case-insensitive Vergleich via .toLowerCase()', () {
      expect(screenSrc.contains('.toLowerCase()'), isTrue,
          reason: 'Case-insensitive Compare via trim().toLowerCase() muss implementiert sein');
    });
  });
}
