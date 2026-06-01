/// QA-Tests für Ticket #15: Englische Texte in deutscher UI beseitigen
///
/// Prüft per Source-Verification:
/// 1. flutter_localizations als pubspec.yaml-Dependency
/// 2. MaterialApp mit localizationsDelegates, supportedLocales, locale in main.dart
/// 3. Explizite "Antworte immer auf Deutsch." in allen Prompt-Dateien
/// 4. Keine schwachen "Antworte auf Deutsch"-Varianten ohne "immer" an kritischen Stellen

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String _read(String path) =>
    File(path).readAsStringSync();

void main() {
  // ──────────────────────────────────────────────────────────────
  // 1. pubspec.yaml
  // ──────────────────────────────────────────────────────────────
  group('pubspec.yaml – flutter_localizations', () {
    late String content;
    setUpAll(() => content = _read('pubspec.yaml'));

    test('TC-01: flutter_localizations als sdk-Dependency vorhanden', () {
      expect(
        content,
        contains('flutter_localizations:'),
        reason: 'flutter_localizations muss als Dependency eingetragen sein',
      );
      expect(
        content,
        contains('sdk: flutter'),
        reason: 'flutter_localizations muss sdk: flutter als Quelle haben',
      );
    });
  });

  // ──────────────────────────────────────────────────────────────
  // 2. lib/main.dart – MaterialApp Lokalisierungssetup
  // ──────────────────────────────────────────────────────────────
  group('lib/main.dart – MaterialApp Lokalisierung', () {
    late String content;
    setUpAll(() => content = _read('lib/main.dart'));

    test('TC-02: flutter_localizations wird importiert', () {
      expect(
        content,
        contains("import 'package:flutter_localizations/flutter_localizations.dart'"),
        reason: 'Import von flutter_localizations muss vorhanden sein',
      );
    });

    test('TC-03: localizationsDelegates mit GlobalMaterialLocalizations gesetzt', () {
      expect(
        content,
        contains('GlobalMaterialLocalizations.delegates'),
        reason: 'MaterialApp braucht GlobalMaterialLocalizations.delegates',
      );
    });

    test("TC-04: supportedLocales enthält Locale('de')", () {
      expect(
        content,
        contains("Locale('de')"),
        reason: "supportedLocales muss Locale('de') enthalten",
      );
    });

    test("TC-05: locale ist explizit auf Locale('de') gesetzt (Override)", () {
      // Prüfe dass das locale-Feld gesetzt ist (nicht nur in supportedLocales)
      final localeAssignmentPattern = RegExp(r'locale\s*:\s*const\s+Locale\(');
      expect(
        localeAssignmentPattern.hasMatch(content),
        isTrue,
        reason: "locale: const Locale('de') muss in MaterialApp gesetzt sein",
      );
    });
  });

  // ──────────────────────────────────────────────────────────────
  // 3. diagnosis_schema.dart – Deutsch-Direktive in beiden JSON-Instruktionen
  // ──────────────────────────────────────────────────────────────
  group('lib/services/prompts/diagnosis_schema.dart – Deutsch-Direktive', () {
    late String content;
    setUpAll(() => content = _read('lib/services/prompts/diagnosis_schema.dart'));

    test('TC-06: claudeJsonInstruction enthält "Antworte immer auf Deutsch."', () {
      // Extrahiere den claudeJsonInstruction-Block
      final claudeStart = content.indexOf('claudeJsonInstruction');
      final claudeEnd = content.indexOf('deepseekJsonInstruction');
      final claudeBlock = content.substring(claudeStart, claudeEnd);

      final count = 'Antworte immer auf Deutsch'.allMatches(claudeBlock).length;
      expect(
        count,
        greaterThanOrEqualTo(2),
        reason: 'claudeJsonInstruction soll Deutsch-Direktive am Anfang UND Ende haben (Sandwich-Effekt)',
      );
    });

    test('TC-07: deepseekJsonInstruction enthält "Antworte immer auf Deutsch."', () {
      final deepseekStart = content.indexOf('deepseekJsonInstruction');
      // Nimm den Block bis zur nächsten statischen Methode
      final nextMethod = content.indexOf('static String buildClaudePrompt');
      final deepseekBlock = content.substring(deepseekStart, nextMethod);

      final count = 'Antworte immer auf Deutsch'.allMatches(deepseekBlock).length;
      expect(
        count,
        greaterThanOrEqualTo(2),
        reason: 'deepseekJsonInstruction soll Deutsch-Direktive am Anfang UND Ende haben',
      );
    });

    test('TC-08: Kein schwaches "Antworte auf Deutsch" ohne "immer" in JSON-Instruktionen', () {
      // Erlaubt: "Antworte immer auf Deutsch" – nicht erlaubt: reines "Antworte auf Deutsch"
      // (Ausnahme: "Alle Texte auf Deutsch" als Teil eines längeren WICHTIG-Satzes ist ok)
      final weakPattern = RegExp(r'Antworte auf Deutsch(?!\.)(?! immer)');
      // Suche nur in den JSON-Instruktions-Konstanten (nicht in Kommentaren)
      final claudeBlock = content.substring(
        content.indexOf('claudeJsonInstruction'),
        content.indexOf('static String buildClaudePrompt'),
      );
      expect(
        weakPattern.hasMatch(claudeBlock),
        isFalse,
        reason: 'Kein schwaches "Antworte auf Deutsch" (ohne "immer") in JSON-Instruktionen erlaubt',
      );
    });
  });

  // ──────────────────────────────────────────────────────────────
  // 4. plant_care_schema.dart – Deutsch-Direktive im Identify-Prompt
  // ──────────────────────────────────────────────────────────────
  group('lib/services/prompts/plant_care_schema.dart – Deutsch-Direktive', () {
    late String content;
    setUpAll(() => content = _read('lib/services/prompts/plant_care_schema.dart'));

    test('TC-09: buildIdentifyPrompt enthält "Antworte immer auf Deutsch."', () {
      expect(
        content,
        contains('Antworte immer auf Deutsch'),
        reason: 'plant_care_schema muss explizite Deutsch-Instruktion enthalten',
      );
    });

    test('TC-10: Deutsch-Direktive ist als WICHTIG-Statement verstärkt', () {
      expect(
        content,
        contains('WICHTIG'),
        reason: 'Deutsch-Direktive sollte mit WICHTIG-Label verstärkt sein',
      );
    });
  });

  // ──────────────────────────────────────────────────────────────
  // 5. claude_service.dart – System-Prompt und identifyFertilizer
  // ──────────────────────────────────────────────────────────────
  group('lib/services/claude_service.dart – Deutsch-Direktiven', () {
    late String content;
    setUpAll(() => content = _read('lib/services/claude_service.dart'));

    test('TC-11: _defaultSystemPrompt enthält "Antworte immer auf Deutsch."', () {
      expect(
        content,
        contains('Antworte immer auf Deutsch'),
        reason: '_defaultSystemPrompt muss Deutsch-Direktive enthalten',
      );
    });

    test('TC-12: identifyFertilizer-Prompt enthält "Antworte immer auf Deutsch"', () {
      final fertStart = content.indexOf('identifyFertilizer');
      final fertEnd = content.indexOf('Future<String> askQuestion');
      final fertBlock = content.substring(fertStart, fertEnd);

      expect(
        fertBlock,
        contains('Antworte immer auf Deutsch'),
        reason: 'identifyFertilizer-Prompt muss "immer" enthalten (nicht nur "Antworte auf Deutsch")',
      );
    });
  });

  // ──────────────────────────────────────────────────────────────
  // 6. deepseek_service.dart – System-Prompt und identifyFertilizer
  // ──────────────────────────────────────────────────────────────
  group('lib/services/deepseek_service.dart – Deutsch-Direktiven', () {
    late String content;
    setUpAll(() => content = _read('lib/services/deepseek_service.dart'));

    test('TC-13: _defaultSystemPrompt enthält "Antworte immer auf Deutsch."', () {
      expect(
        content,
        contains('Antworte immer auf Deutsch'),
        reason: 'deepseek_service _defaultSystemPrompt muss Deutsch-Direktive enthalten',
      );
    });

    test('TC-14: identifyFertilizer-Prompt (DeepSeek) enthält "Antworte immer auf Deutsch"', () {
      final fertStart = content.indexOf('Future<String> identifyFertilizer');
      final fertEnd = content.indexOf('Future<String> askQuestion');
      final fertBlock = content.substring(fertStart, fertEnd);

      expect(
        fertBlock,
        contains('Antworte immer auf Deutsch'),
        reason: 'deepseek_service identifyFertilizer muss "immer" enthalten',
      );
    });
  });
}
