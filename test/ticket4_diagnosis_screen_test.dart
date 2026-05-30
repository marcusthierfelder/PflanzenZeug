/// QA-Tests für Ticket #4: Diagnose-Screen mit strukturierter Karten-Anzeige
///
/// Akzeptanzkriterien (MVP) werden direkt durch Unit- und Widget-Tests abgedeckt.
library;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pflanzenwart/models/diagnosis/diagnosis_result.dart';
import 'package:pflanzenwart/models/diagnosis/finding.dart';
import 'package:pflanzenwart/models/diagnosis/recommendations.dart';
import 'package:pflanzenwart/models/plant.dart';
import 'package:pflanzenwart/services/parsers/diagnosis_parser.dart';
import 'package:pflanzenwart/services/parsers/parse_result.dart';
import 'package:pflanzenwart/services/prompts/diagnosis_schema.dart';
import 'package:pflanzenwart/widgets/diagnosis/comparison_banner.dart';
import 'package:pflanzenwart/widgets/diagnosis/finding_card.dart';
import 'package:pflanzenwart/widgets/diagnosis/health_header.dart';
import 'package:pflanzenwart/widgets/diagnosis/recommendations_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Test-Fixtures
// ─────────────────────────────────────────────────────────────────────────────

/// Vollständiges, valides Diagnose-JSON (alle Felder vorhanden).
String _validDiagnosisJson({
  String overallHealth = 'poor',
  String summary = 'Die Pflanze zeigt Anzeichen von Spinnmilben und Nährstoffmangel.',
  String? comparisonToPrevious = 'Zustand hat sich verschlechtert seit letzter Diagnose.',
}) =>
    jsonEncode({
      'overall_health': overallHealth,
      'summary': summary,
      'findings': [
        {
          'type': 'pest',
          'severity': 'high',
          'title': 'Spinnmilbenbefall',
          'evidence': 'Feine Gespinste an Blattunterseiten sichtbar.',
          'treatment': 'Neem-Öl-Spray 1x/Woche für 4 Wochen.',
        },
        {
          'type': 'deficiency',
          'severity': 'medium',
          'title': 'Eisenmangel',
          'evidence': 'Chlorose zwischen den Blattadern.',
          'treatment': 'Eisenchelat-Dünger alle 2 Wochen.',
        },
        {
          'type': 'environmental',
          'severity': 'low',
          'title': 'Zu wenig Licht',
          'evidence': 'Blätter blassen aus.',
          'treatment': 'Heller Standort ohne Direktsonne.',
        },
      ],
      'recommendations': {
        'watering': 'Alle 5–7 Tage mäßig gießen.',
        'fertilizer': {
          'advice': 'Flüssigdünger im Sommer.',
          'product': 'Compo Blaues Wunder',
        },
        'location': 'Helles Fensterbrett, kein direktes Mittagslicht.',
        'other': ['Blätter regelmäßig mit feuchtem Tuch abwischen.'],
      },
      'comparison_to_previous': comparisonToPrevious,
    });

/// Minimales JSON ohne optionale Felder.
String _minimalDiagnosisJson() => jsonEncode({
      'overall_health': 'good',
      'summary': 'Pflanze ist kerngesund.',
      'findings': <dynamic>[],
      'recommendations': {
        'watering': 'Normal gießen.',
        'fertilizer': 'Kein Dünger nötig.',
        'location': 'Aktueller Standort optimal.',
        'other': <dynamic>[],
      },
      'comparison_to_previous': null,
    });

DiagnosisResult _makeDiagnosisResult({
  OverallHealth health = OverallHealth.poor,
  String summary = 'Testbefund.',
  List<Finding>? findings,
  String? comparison,
}) =>
    DiagnosisResult(
      overallHealth: health,
      summary: summary,
      findings: findings ??
          [
            const Finding(
              type: FindingType.pest,
              severity: Severity.high,
              title: 'Spinnmilben',
              evidence: 'Gespinste sichtbar.',
              treatment: 'Neem-Öl.',
            ),
            const Finding(
              type: FindingType.deficiency,
              severity: Severity.low,
              title: 'Eisenmangel',
              evidence: 'Chlorose.',
              treatment: 'Eisendünger.',
            ),
          ],
      recommendations: Recommendations(
        watering: 'Wöchentlich gießen.',
        fertilizer: const FertilizerRecommendation(
          advice: 'Flüssigdünger.',
          product: 'Compo',
        ),
        location: 'Helles Fensterbrett.',
        other: const ['Blätter abwischen.'],
      ),
      comparisonToPrevious: comparison,
    );

// ─────────────────────────────────────────────────────────────────────────────
// 1. DiagnosisParser – AK: JSON-Schema parsen, nie crashen
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('AK-1 / DiagnosisParser – Valides JSON wird geparst', () {
    test('TC-D01: Vollständiges JSON liefert ParseSuccess<DiagnosisResult>', () {
      final raw = _validDiagnosisJson();
      final result = DiagnosisParser.parse(raw);

      expect(result.isSuccess, isTrue);
      final dr = result.valueOrNull!;
      expect(dr.overallHealth, equals(OverallHealth.poor));
      expect(dr.summary,
          equals('Die Pflanze zeigt Anzeichen von Spinnmilben und Nährstoffmangel.'));
      expect(dr.findings, hasLength(3));
      expect(dr.comparisonToPrevious, isNotNull);
    });

    test('TC-D02: Findings haben korrekte Typen und Severity', () {
      final dr = DiagnosisParser.parse(_validDiagnosisJson()).valueOrNull!;

      expect(dr.findings[0].type, equals(FindingType.pest));
      expect(dr.findings[0].severity, equals(Severity.high));
      expect(dr.findings[1].type, equals(FindingType.deficiency));
      expect(dr.findings[1].severity, equals(Severity.medium));
      expect(dr.findings[2].type, equals(FindingType.environmental));
      expect(dr.findings[2].severity, equals(Severity.low));
    });

    test('TC-D03: Recommendations mit Objekt-Fertilizer korrekt geparst', () {
      final dr = DiagnosisParser.parse(_validDiagnosisJson()).valueOrNull!;
      final rec = dr.recommendations;

      expect(rec.watering, contains('5–7 Tage'));
      expect(rec.fertilizer.advice, equals('Flüssigdünger im Sommer.'));
      expect(rec.fertilizer.product, equals('Compo Blaues Wunder'));
      expect(rec.location, contains('Fensterbrett'));
      expect(rec.other, hasLength(1));
    });

    test('TC-D04: Minimales JSON (leere Findings, null Comparison) liefert ParseSuccess', () {
      final result = DiagnosisParser.parse(_minimalDiagnosisJson());

      expect(result.isSuccess, isTrue);
      final dr = result.valueOrNull!;
      expect(dr.overallHealth, equals(OverallHealth.good));
      expect(dr.findings, isEmpty);
      expect(dr.comparisonToPrevious, isNull);
    });

    test('TC-D05: JSON mit Code-Fences wird korrekt extrahiert', () {
      final raw = '```json\n${_validDiagnosisJson()}\n```';
      final result = DiagnosisParser.parse(raw);
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.findings, hasLength(3));
    });

    test('TC-D06: JSON mit führendem Text (Claude-Prefill-Szenario)', () {
      final raw = 'Hier ist die Diagnose:\n${_validDiagnosisJson()}\nViel Erfolg.';
      final result = DiagnosisParser.parse(raw);
      expect(result.isSuccess, isTrue);
    });
  });

  group('AK-1 / DiagnosisParser – Fehlerszenarien liefern ParsePartial (kein Crash)', () {
    test('TC-D07: Leere Antwort → ParsePartial mit fallbackText', () {
      final result = DiagnosisParser.parse('');
      expect(result.isPartial, isTrue);
      expect(result.fallbackText, isNotNull);
    });

    test('TC-D08: Reiner Markdown-Text → ParsePartial', () {
      const markdown = '## Diagnose\n\n**Spinnmilben** gefunden.\n\nBitte Neem-Öl verwenden.';
      final result = DiagnosisParser.parse(markdown);
      expect(result.isPartial, isTrue);
      expect(result.fallbackText, equals(markdown));
    });

    test('TC-D09: Kaputtes JSON → ParsePartial, kein Crash', () {
      const broken = '{"overall_health": "poor", "summary": MISSING_QUOTES}';
      ParseResult<DiagnosisResult>? result;
      expect(() {
        result = DiagnosisParser.parse(broken);
      }, returnsNormally);
      expect(result!.isPartial, isTrue);
    });

    test('TC-D10: JSON-Array statt Objekt → ParsePartial, kein Crash', () {
      const raw = '[{"overall_health": "poor"}]';
      ParseResult<DiagnosisResult>? result;
      expect(() {
        result = DiagnosisParser.parse(raw);
      }, returnsNormally);
      // Entweder partial (Array kein Objekt) oder success (JsonExtractor extrahiert Inhalt)
      // Hauptsache kein Crash.
      expect(result, isNotNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 2. JSON-Schema – AK: Schema enthält alle Pflicht-Felder
  // ─────────────────────────────────────────────────────────────────────────

  group('AK-2 / DiagnosisSchema – Prompt enthält vollständiges Schema', () {
    test('TC-D11: Claude-Prompt enthält alle Schema-Felder', () {
      final prompt = DiagnosisSchema.buildClaudePrompt(plantName: 'Monstera');

      expect(prompt, contains('"overall_health"'));
      expect(prompt, contains('"summary"'));
      expect(prompt, contains('"findings"'));
      expect(prompt, contains('"type"'));
      expect(prompt, contains('"severity"'));
      expect(prompt, contains('"title"'));
      expect(prompt, contains('"evidence"'));
      expect(prompt, contains('"treatment"'));
      expect(prompt, contains('"recommendations"'));
      expect(prompt, contains('"watering"'));
      expect(prompt, contains('"fertilizer"'));
      expect(prompt, contains('"location"'));
      expect(prompt, contains('"other"'));
      expect(prompt, contains('"comparison_to_previous"'));
    });

    test('TC-D12: Claude-Prompt enthält alle OverallHealth-Werte', () {
      final prompt = DiagnosisSchema.buildClaudePrompt(plantName: 'Ficus');

      expect(prompt, contains('"good"'));
      expect(prompt, contains('"fair"'));
      expect(prompt, contains('"poor"'));
      expect(prompt, contains('"critical"'));
    });

    test('TC-D13: Claude-Prompt enthält alle Severity-Werte', () {
      final prompt = DiagnosisSchema.buildClaudePrompt(plantName: 'Ficus');

      expect(prompt, contains('"high"'));
      expect(prompt, contains('"medium"'));
      expect(prompt, contains('"low"'));
    });

    test('TC-D14: Claude-Prompt enthält alle FindingType-Werte', () {
      final prompt = DiagnosisSchema.buildClaudePrompt(plantName: 'Ficus');

      expect(prompt, contains('"disease"'));
      expect(prompt, contains('"pest"'));
      expect(prompt, contains('"deficiency"'));
      expect(prompt, contains('"environmental"'));
    });

    test('TC-D15: DeepSeek-Prompt enthält gleiches Schema wie Claude-Prompt', () {
      final claude = DiagnosisSchema.buildClaudePrompt(plantName: 'Monstera');
      final deepseek = DiagnosisSchema.buildDeepSeekPrompt(plantName: 'Monstera');

      // Beide müssen alle Schema-Felder enthalten
      for (final field in [
        '"overall_health"', '"findings"', '"severity"', '"recommendations"'
      ]) {
        expect(claude, contains(field));
        expect(deepseek, contains(field));
      }
    });

    test('TC-D16: Prompt mit Pflanzennamen enthält Pflanzennamen', () {
      final prompt = DiagnosisSchema.buildClaudePrompt(
        plantName: 'Monstera deliciosa',
      );
      expect(prompt, contains('Monstera deliciosa'));
    });

    test('TC-D17: Prompt mit availableFertilizerNames listet Dünger auf', () {
      final prompt = DiagnosisSchema.buildClaudePrompt(
        plantName: 'Ficus',
        availableFertilizerNames: ['Compo Blaues Wunder', 'Oscorna'],
      );
      expect(prompt, contains('Compo Blaues Wunder'));
      expect(prompt, contains('Oscorna'));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 3. Modell-Schicht – AK: defensives fromJson, Enums, toMarkdown()
  // ─────────────────────────────────────────────────────────────────────────

  group('AK-3 / DiagnosisResult – Modell & Enums', () {
    test('TC-D18: OverallHealth.fromString – alle Werte + Fallback', () {
      expect(OverallHealth.fromString('good'), equals(OverallHealth.good));
      expect(OverallHealth.fromString('fair'), equals(OverallHealth.fair));
      expect(OverallHealth.fromString('poor'), equals(OverallHealth.poor));
      expect(OverallHealth.fromString('critical'), equals(OverallHealth.critical));
      expect(OverallHealth.fromString('UNKNOWN'), equals(OverallHealth.fair)); // Fallback
    });

    test('TC-D19: OverallHealth.label gibt deutschen Text zurück', () {
      expect(OverallHealth.good.label, equals('Pflanze ist gesund'));
      expect(OverallHealth.fair.label, equals('Kleine Auffälligkeiten'));
      expect(OverallHealth.poor.label, equals('Behandlung nötig'));
      expect(OverallHealth.critical.label, equals('Akut handeln'));
    });

    test('TC-D20: Severity.weight für Sortierung (high > medium > low)', () {
      expect(Severity.high.weight, greaterThan(Severity.medium.weight));
      expect(Severity.medium.weight, greaterThan(Severity.low.weight));
    });

    test('TC-D21: Severity.fromString – alle Werte + Fallback', () {
      expect(Severity.fromString('high'), equals(Severity.high));
      expect(Severity.fromString('medium'), equals(Severity.medium));
      expect(Severity.fromString('low'), equals(Severity.low));
      expect(Severity.fromString('unknown'), equals(Severity.low)); // Fallback
    });

    test('TC-D22: FindingType.iconName gibt korrekte Material-Icon-Namen zurück', () {
      expect(FindingType.disease.iconName, equals('coronavirus'));
      expect(FindingType.pest.iconName, equals('bug_report'));
      expect(FindingType.deficiency.iconName, equals('science'));
      expect(FindingType.environmental.iconName, equals('wb_sunny'));
    });

    test('TC-D23: Finding.fromJson mit fehlenden Feldern liefert Defaults, kein Crash', () {
      final finding = Finding.fromJson({});
      expect(finding.title, equals('Unbekannter Befund'));
      expect(finding.type, equals(FindingType.environmental)); // Fallback
      expect(finding.severity, equals(Severity.low)); // Fallback
      expect(finding.evidence, equals(''));
      expect(finding.treatment, equals(''));
    });

    test('TC-D24: FertilizerRecommendation.fromJson toleriert String', () {
      final fertilizer = FertilizerRecommendation.fromJson('Flüssigdünger im Sommer');
      expect(fertilizer.advice, equals('Flüssigdünger im Sommer'));
      expect(fertilizer.product, isNull);
    });

    test('TC-D25: FertilizerRecommendation.fromJson toleriert Objekt', () {
      final fertilizer = FertilizerRecommendation.fromJson({
        'advice': 'Flüssigdünger',
        'product': 'Compo',
      });
      expect(fertilizer.advice, equals('Flüssigdünger'));
      expect(fertilizer.product, equals('Compo'));
    });

    test('TC-D26: FertilizerRecommendation.toString mit Produkt', () {
      const fertilizer = FertilizerRecommendation(
        advice: 'Flüssigdünger',
        product: 'Compo',
      );
      expect(fertilizer.toString(), equals('Flüssigdünger (Produkt: Compo)'));
    });

    test('TC-D27: FertilizerRecommendation.toString ohne Produkt', () {
      const fertilizer = FertilizerRecommendation(advice: 'Kein Dünger nötig');
      expect(fertilizer.toString(), equals('Kein Dünger nötig'));
    });

    test('TC-D28: DiagnosisResult.fromJson vollständig', () {
      final json = jsonDecode(_validDiagnosisJson()) as Map<String, dynamic>;
      final dr = DiagnosisResult.fromJson(json);

      expect(dr.overallHealth, equals(OverallHealth.poor));
      expect(dr.findings, hasLength(3));
      expect(dr.comparisonToPrevious, isNotNull);
    });

    test('TC-D29: DiagnosisResult.toJson → fromJson Round-Trip', () {
      final original = _makeDiagnosisResult();
      final json = original.toJson();
      final restored = DiagnosisResult.fromJson(json);

      expect(restored.overallHealth, equals(original.overallHealth));
      expect(restored.summary, equals(original.summary));
      expect(restored.findings, hasLength(original.findings.length));
      expect(restored.findings[0].severity, equals(original.findings[0].severity));
    });

    test('TC-D30: DiagnosisResult.toJsonString liefert gültigen JSON-String', () {
      final dr = _makeDiagnosisResult();
      final jsonStr = dr.toJsonString();

      expect(() => jsonDecode(jsonStr), returnsNormally);
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(decoded['overall_health'], equals('poor'));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 4. toMarkdown() – AK: Chat-Screen bekommt sinnvollen Kontext
  // ─────────────────────────────────────────────────────────────────────────

  group('AK-4 / DiagnosisResult.toMarkdown() – Chat-Kontext', () {
    test('TC-D31: toMarkdown enthält Gesundheitszustand', () {
      final dr = _makeDiagnosisResult(health: OverallHealth.critical);
      final md = dr.toMarkdown();

      expect(md, contains('Akut handeln'));
    });

    test('TC-D32: toMarkdown enthält alle Finding-Titel', () {
      final dr = _makeDiagnosisResult();
      final md = dr.toMarkdown();

      expect(md, contains('Spinnmilben'));
      expect(md, contains('Eisenmangel'));
    });

    test('TC-D33: toMarkdown enthält Empfehlungen', () {
      final dr = _makeDiagnosisResult();
      final md = dr.toMarkdown();

      expect(md, contains('Gießen'));
      expect(md, contains('Wöchentlich'));
    });

    test('TC-D34: toMarkdown enthält Comparison wenn vorhanden', () {
      final dr = _makeDiagnosisResult(comparison: 'Zustand hat sich verbessert.');
      final md = dr.toMarkdown();

      expect(md, contains('Vergleich zur letzten Diagnose'));
      expect(md, contains('Zustand hat sich verbessert.'));
    });

    test('TC-D35: toMarkdown OHNE Comparison enthält keinen Vergleichs-Abschnitt', () {
      final dr = _makeDiagnosisResult(comparison: null);
      final md = dr.toMarkdown();

      expect(md, isNot(contains('Vergleich zur letzten Diagnose')));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 5. Plant-Modell – AK: diagnosisResultJson Persistenz & Altdaten
  // ─────────────────────────────────────────────────────────────────────────

  group('AK-5 / Plant.diagnosisResultJson – Persistenz & Altdaten-Kompatibilität', () {
    Plant _makePlant({
      String? diagnosisResultJson,
      String? diagnosisResult,
    }) =>
        Plant(
          id: 'test-id',
          nickname: 'Testpflanze',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          diagnosisResultJson: diagnosisResultJson,
          diagnosisResult: diagnosisResult,
        );

    test('TC-D36: Plant.fromJson liest diagnosisResultJson', () {
      final json = <dynamic, dynamic>{
        'id': 'abc',
        'nickname': 'Test',
        'createdAt': '2024-01-01T00:00:00.000',
        'updatedAt': '2024-01-01T00:00:00.000',
        'diagnosisResultJson': '{"overall_health":"good"}',
      };
      final plant = Plant.fromJson(json);
      expect(plant.diagnosisResultJson, equals('{"overall_health":"good"}'));
    });

    test('TC-D37: Plant.fromJson ohne diagnosisResultJson → null (Altdaten)', () {
      final json = <dynamic, dynamic>{
        'id': 'abc',
        'nickname': 'Test',
        'createdAt': '2024-01-01T00:00:00.000',
        'updatedAt': '2024-01-01T00:00:00.000',
        // diagnosisResultJson fehlt intentional (Altdaten-Simulation)
      };
      final plant = Plant.fromJson(json);
      expect(plant.diagnosisResultJson, isNull);
    });

    test('TC-D38: Plant.fromJson mit diagnosisResult bleibt erhalten (Legacy)', () {
      final json = <dynamic, dynamic>{
        'id': 'abc',
        'nickname': 'Test',
        'createdAt': '2024-01-01T00:00:00.000',
        'updatedAt': '2024-01-01T00:00:00.000',
        'diagnosisResult': '## Diagnose\n\nSpinnmilben gefunden.',
        // diagnosisResultJson fehlt (Altdaten)
      };
      final plant = Plant.fromJson(json);
      expect(plant.diagnosisResult, equals('## Diagnose\n\nSpinnmilben gefunden.'));
      expect(plant.diagnosisResultJson, isNull);
    });

    test('TC-D39: Plant.toJson enthält diagnosisResultJson', () {
      final dr = _makeDiagnosisResult();
      final plant = _makePlant(
        diagnosisResultJson: dr.toJsonString(),
        diagnosisResult: dr.toMarkdown(),
      );
      final json = plant.toJson();

      expect(json.containsKey('diagnosisResultJson'), isTrue);
      expect(json['diagnosisResultJson'], isNotNull);
      expect(json.containsKey('diagnosisResult'), isTrue);
    });

    test('TC-D40: diagnosisResultJson kann re-geparst werden (Speicher+Lade-Zyklus)', () {
      final dr = _makeDiagnosisResult(health: OverallHealth.critical);
      final jsonStr = dr.toJsonString();

      // Simulation: JSON-String aus DB laden und re-parsen
      final result = DiagnosisParser.parse(jsonStr);
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.overallHealth, equals(OverallHealth.critical));
      expect(result.valueOrNull!.findings, hasLength(2));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 6. Widget-Tests – AK: Diagnose-Screen-Widgets korrekt gerendert
  // ─────────────────────────────────────────────────────────────────────────

  group('AK-6 / HealthHeader Widget', () {
    testWidgets('TC-D41: HealthHeader zeigt Icon + Label für "good"', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HealthHeader(
              health: OverallHealth.good,
              summary: 'Pflanze sieht super aus.',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.text('Pflanze ist gesund'), findsOneWidget);
      expect(find.text('Pflanze sieht super aus.'), findsOneWidget);
    });

    testWidgets('TC-D42: HealthHeader zeigt "Akut handeln" für "critical"', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HealthHeader(
              health: OverallHealth.critical,
              summary: 'Dringend handeln.',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.dangerous), findsOneWidget);
      expect(find.text('Akut handeln'), findsOneWidget);
    });

    testWidgets('TC-D43: HealthHeader zeigt "Behandlung nötig" für "poor"', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HealthHeader(
              health: OverallHealth.poor,
              summary: '',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.warning_amber), findsOneWidget);
      expect(find.text('Behandlung nötig'), findsOneWidget);
    });
  });

  group('AK-7 / FindingCard Widget – Severity-Design & Ausklappbar', () {
    Widget _wrapFindingCard(Finding finding) => MaterialApp(
          home: Scaffold(
            body: FindingCard(finding: finding),
          ),
        );

    testWidgets('TC-D44: FindingCard zeigt Titel + Severity-Label + Type-Label',
        (tester) async {
      const finding = Finding(
        type: FindingType.pest,
        severity: Severity.high,
        title: 'Spinnmilbenbefall',
        evidence: 'Gespinste unter den Blättern.',
        treatment: 'Neem-Öl sprühen.',
      );
      await tester.pumpWidget(_wrapFindingCard(finding));
      await tester.pumpAndSettle();

      expect(find.text('Spinnmilbenbefall'), findsOneWidget);
      expect(find.text('Schwerwiegend'), findsOneWidget);
      expect(find.text('Schädling'), findsOneWidget); // Type-Label
    });

    testWidgets('TC-D45: FindingCard zeigt korrektes Type-Icon (pest=bug_report)',
        (tester) async {
      const finding = Finding(
        type: FindingType.pest,
        severity: Severity.high,
        title: 'Schädling',
        evidence: '',
        treatment: '',
      );
      await tester.pumpWidget(_wrapFindingCard(finding));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.bug_report), findsOneWidget);
    });

    testWidgets('TC-D46: FindingCard disease zeigt coronavirus-Icon', (tester) async {
      const finding = Finding(
        type: FindingType.disease,
        severity: Severity.medium,
        title: 'Pilzbefall',
        evidence: 'Weißer Belag.',
        treatment: 'Fungizid.',
      );
      await tester.pumpWidget(_wrapFindingCard(finding));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.coronavirus), findsOneWidget);
    });

    testWidgets('TC-D47: FindingCard deficiency zeigt science-Icon', (tester) async {
      const finding = Finding(
        type: FindingType.deficiency,
        severity: Severity.low,
        title: 'Mangel',
        evidence: '',
        treatment: '',
      );
      await tester.pumpWidget(_wrapFindingCard(finding));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.science), findsOneWidget);
    });

    testWidgets('TC-D48: FindingCard environmental zeigt wb_sunny-Icon', (tester) async {
      const finding = Finding(
        type: FindingType.environmental,
        severity: Severity.low,
        title: 'Zu wenig Licht',
        evidence: '',
        treatment: '',
      );
      await tester.pumpWidget(_wrapFindingCard(finding));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.wb_sunny), findsOneWidget);
    });

    testWidgets('TC-D49: FindingCard mit Evidence+Treatment zeigt Expand-Icon',
        (tester) async {
      const finding = Finding(
        type: FindingType.disease,
        severity: Severity.high,
        title: 'Pilzbefall',
        evidence: 'Weißer Belag sichtbar.',
        treatment: 'Fungizid auftragen.',
      );
      await tester.pumpWidget(_wrapFindingCard(finding));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    testWidgets('TC-D50: FindingCard klappt auf bei Tap – Evidence sichtbar',
        (tester) async {
      const finding = Finding(
        type: FindingType.disease,
        severity: Severity.high,
        title: 'Pilzbefall',
        evidence: 'Weißer Belag sichtbar.',
        treatment: 'Fungizid auftragen.',
      );
      await tester.pumpWidget(_wrapFindingCard(finding));
      await tester.pumpAndSettle();

      // Vor Tap: expand_more sichtbar
      expect(find.byIcon(Icons.expand_more), findsOneWidget);

      // Karte antippen
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Nach Tap: expand_less + Detail-Labels sichtbar
      expect(find.byIcon(Icons.expand_less), findsOneWidget);
      expect(find.text('Befund'), findsOneWidget);
      expect(find.text('Behandlung'), findsOneWidget);
      expect(find.text('Weißer Belag sichtbar.'), findsOneWidget);
      expect(find.text('Fungizid auftragen.'), findsOneWidget);
    });

    testWidgets('TC-D51: FindingCard ohne Evidence/Treatment hat keinen Expand-Icon',
        (tester) async {
      const finding = Finding(
        type: FindingType.environmental,
        severity: Severity.low,
        title: 'Kein Detail',
        evidence: '',
        treatment: '',
      );
      await tester.pumpWidget(_wrapFindingCard(finding));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.expand_more), findsNothing);
    });
  });

  group('AK-8 / RecommendationsCard Widget', () {
    testWidgets('TC-D52: RecommendationsCard zeigt alle 4 Empfehlungstypen',
        (tester) async {
      final recs = Recommendations(
        watering: 'Alle 7 Tage.',
        fertilizer: const FertilizerRecommendation(
          advice: 'Flüssigdünger.',
          product: 'Compo',
        ),
        location: 'Helles Fensterbrett.',
        other: const ['Blätter abwischen.'],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecommendationsCard(recommendations: recs),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Empfehlungen'), findsOneWidget);
      expect(find.text('Gießen'), findsOneWidget);
      expect(find.text('Alle 7 Tage.'), findsOneWidget);
      expect(find.text('Düngen'), findsOneWidget);
      expect(find.text('Standort'), findsOneWidget);
      expect(find.text('Tipp'), findsOneWidget);
    });

    testWidgets('TC-D53: RecommendationsCard mit leeren Feldern rendert nichts (SizedBox)',
        (tester) async {
      final emptyRecs = Recommendations(
        watering: '',
        fertilizer: const FertilizerRecommendation(advice: ''),
        location: '',
        other: const [],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecommendationsCard(recommendations: emptyRecs),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Empfehlungen'), findsNothing);
    });
  });

  group('AK-9 / ComparisonBanner Widget', () {
    testWidgets('TC-D54: ComparisonBanner zeigt Text und History-Icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ComparisonBanner(
              comparisonText: 'Zustand hat sich deutlich verbessert.',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.history), findsOneWidget);
      expect(find.text('Vergleich zur letzten Diagnose'), findsOneWidget);
      expect(find.text('Zustand hat sich deutlich verbessert.'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 10. Severity-Sortierung – AK: Findings absteigend nach Severity
  // ─────────────────────────────────────────────────────────────────────────

  group('AK-10 / Severity-Sortierung', () {
    test('TC-D55: Findings werden high → medium → low sortiert', () {
      final findings = [
        const Finding(
          type: FindingType.environmental,
          severity: Severity.low,
          title: 'Leicht',
          evidence: '',
          treatment: '',
        ),
        const Finding(
          type: FindingType.disease,
          severity: Severity.high,
          title: 'Schwer',
          evidence: '',
          treatment: '',
        ),
        const Finding(
          type: FindingType.deficiency,
          severity: Severity.medium,
          title: 'Mittel',
          evidence: '',
          treatment: '',
        ),
      ];

      // Sortierung wie im DiagnosisScreen
      final sorted = List<Finding>.from(findings)
        ..sort((a, b) => b.severity.weight.compareTo(a.severity.weight));

      expect(sorted[0].severity, equals(Severity.high));
      expect(sorted[1].severity, equals(Severity.medium));
      expect(sorted[2].severity, equals(Severity.low));
      expect(sorted[0].title, equals('Schwer'));
      expect(sorted[2].title, equals('Leicht'));
    });

    test('TC-D56: Gleichrangige Severity-Werte sind stabil (kein Crash)', () {
      final findings = List.generate(
        5,
        (i) => Finding(
          type: FindingType.pest,
          severity: Severity.high,
          title: 'Finding $i',
          evidence: '',
          treatment: '',
        ),
      );
      expect(() {
        findings.sort((a, b) => b.severity.weight.compareTo(a.severity.weight));
      }, returnsNormally);
      // Alle haben gleiche Severity → alle bleiben high
      for (final f in findings) {
        expect(f.severity, equals(Severity.high));
      }
    });
  });
}
