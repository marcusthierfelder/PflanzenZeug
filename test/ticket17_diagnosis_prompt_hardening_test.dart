/// QA-Tests für Ticket #17: Diagnose-Prompt-Hardening + Confidence-Feld + speciesNotes
///
/// Akzeptanzkriterien:
///  AK-1: Prompt enthält „Diagnostische Sorgfaltspflicht"-Block mit Beleuchtungs-Klausel + Edge-Cases
///  AK-2: Finding-Schema um `confidence`-Feld erweitert; Prompt-Schema dokumentiert
///  AK-3: FindingCard zeigt bei confidence:low visuellen Hinweis
///  AK-4: _buildSpeciesNotes-Logik (careProfileJson → speciesNotes String)
///  AK-5: Abwärtskompatibilität: altes JSON ohne confidence → high
library;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pflanzenwart/models/diagnosis/finding.dart';
import 'package:pflanzenwart/models/diagnosis/diagnosis_result.dart';
import 'package:pflanzenwart/models/care_profile/care_profile.dart';
import 'package:pflanzenwart/models/care_profile/plant_identification_result.dart';
import 'package:pflanzenwart/services/parsers/diagnosis_parser.dart';
import 'package:pflanzenwart/services/parsers/parse_result.dart';
import 'package:pflanzenwart/services/prompts/diagnosis_schema.dart';
import 'package:pflanzenwart/widgets/diagnosis/finding_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Hilfsfunktionen
// ─────────────────────────────────────────────────────────────────────────────

String _diagnosisJson({
  String overallHealth = 'fair',
  List<Map<String, dynamic>> findings = const [],
}) =>
    jsonEncode({
      'overall_health': overallHealth,
      'summary': 'Test-Zusammenfassung.',
      'findings': findings,
      'recommendations': {
        'watering': 'Normal gießen.',
        'fertilizer': {'advice': 'Kein Dünger.', 'product': null},
        'location': 'Aktuell gut.',
        'other': <String>[],
      },
      'comparison_to_previous': null,
    });

/// Vollständiges Diagnose-JSON mit confidence-Feldern
String _diagnosisJsonWithConfidence() => _diagnosisJson(
      overallHealth: 'poor',
      findings: [
        {
          'type': 'environmental',
          'severity': 'low',
          'confidence': 'low',
          'title': 'Mögliche Gelbfärbung',
          'evidence': 'Einzelne Stelle leicht gelblich.',
          'treatment': 'Standort prüfen.',
        },
        {
          'type': 'pest',
          'severity': 'high',
          'confidence': 'high',
          'title': 'Spinnmilben',
          'evidence': 'Gespinste sichtbar.',
          'treatment': 'Neem-Öl.',
        },
        {
          'type': 'deficiency',
          'severity': 'medium',
          'confidence': 'medium',
          'title': 'Eisenmangel',
          'evidence': 'Chlorose zwischen Adern.',
          'treatment': 'Eisendünger.',
        },
      ],
    );

/// Altes Diagnose-JSON (ohne confidence-Feld) – simuliert gespeicherte Altdaten
String _diagnosisJsonLegacy() => _diagnosisJson(
      overallHealth: 'poor',
      findings: [
        {
          'type': 'pest',
          'severity': 'high',
          // KEIN confidence-Feld → Abwärtskompatibilität
          'title': 'Spinnmilben',
          'evidence': 'Gespinste.',
          'treatment': 'Neem-Öl.',
        },
      ],
    );

/// Minimal-CareProfile-JSON für speciesNotes-Tests
String _careProfileJson({
  String name = 'Monstera deliciosa',
  String? scientificName = 'Monstera deliciosa Liebm.',
  String? family = 'Araceae',
  String? additionalNotes = 'Bildet artypische braune Luftwurzeln.',
  String? diagnosticNotes = 'Braune, korkige Luftwurzeln sind normal.',
}) =>
    jsonEncode({
      'name': name,
      if (scientificName != null) 'scientific_name': scientificName,
      if (family != null) 'family': family,
      'care_profile': {
        'water': {'short_value': 'Mittel', 'detail': 'Alle 7–10 Tage'},
        'light': {'short_value': 'Hell', 'detail': 'Kein Direktlicht'},
        'humidity': {'short_value': 'Hoch', 'detail': '60–80 %'},
        'temperature': {'short_value': '18–30 °C', 'detail': ''},
        'soil': {'short_value': 'Durchlässig', 'detail': ''},
        'repotting': {'short_value': 'Alle 2 Jahre', 'detail': ''},
      },
      'difficulty': 'easy',
      'toxicity': {'is_toxic': true, 'details': 'Schwach giftig.'},
      if (additionalNotes != null) 'additional_notes': additionalNotes,
      if (diagnosticNotes != null) 'diagnostic_notes': diagnosticNotes,
    });

// ─────────────────────────────────────────────────────────────────────────────
// AK-1: Diagnose-Prompt enthält „Diagnostische Sorgfaltspflicht"-Block
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('AK-1a / Prompt – Sorgfaltspflicht-Block vorhanden (Claude)', () {
    late String prompt;
    setUpAll(() {
      prompt = DiagnosisSchema.buildClaudePrompt(plantName: 'Monstera');
    });

    test('TC-17-01: Prompt enthält „DIAGNOSTISCHE SORGFALTSPFLICHT"-Header', () {
      expect(prompt, contains('DIAGNOSTISCHE SORGFALTSPFLICHT'));
    });

    test('TC-17-02: Prompt enthält Beleuchtungs-/Weißabgleich-Klausel', () {
      // Muss auf Weißabgleich/Kunstlicht/Beleuchtung hinweisen
      expect(
        prompt.toLowerCase(),
        anyOf(contains('weißabgleich'), contains('kunstlicht'), contains('beleuchtung')),
      );
    });

    test('TC-17-03: Farb-Befund nur bei mehreren eindeutigen Stellen', () {
      // Klausel: Farbbefund nur wenn mehrere Stellen
      expect(
        prompt.toLowerCase(),
        anyOf(contains('mehreren stellen'), contains('mehrere stellen')),
      );
    });

    test('TC-17-04: Monstera/Luftwurzeln Edge-Case explizit im Prompt', () {
      expect(prompt, contains('Monstera'));
      expect(
        prompt.toLowerCase(),
        anyOf(contains('luftwurzel'), contains('luftwurzeln')),
      );
    });

    test('TC-17-05: Sukkulenten/Wachsbereifung Edge-Case im Prompt', () {
      expect(
        prompt.toLowerCase(),
        anyOf(contains('sukkulent'), contains('wachs'), contains('bereifung'), contains('pruinose')),
      );
    });

    test('TC-17-06: Variegation/Panaschierung Edge-Case im Prompt', () {
      expect(
        prompt.toLowerCase(),
        anyOf(contains('variegat'), contains('panaschi'), contains('variegation')),
      );
    });

    test('TC-17-07: Sansevieria/Zamioculcas Edge-Case im Prompt', () {
      expect(
        prompt.toLowerCase(),
        anyOf(contains('sansevieria'), contains('zamioculcas'), contains('zz')),
      );
    });

    test('TC-17-08: Ficus/Citrus-Alters-Blattfall Edge-Case im Prompt', () {
      expect(
        prompt.toLowerCase(),
        anyOf(contains('ficus'), contains('citrus')),
      );
      expect(
        prompt.toLowerCase(),
        anyOf(contains('blattfall'), contains('alters')),
      );
    });

    test('TC-17-09: Kakteen-Trichome Edge-Case im Prompt', () {
      expect(
        prompt.toLowerCase(),
        anyOf(contains('kakteen'), contains('kaktus'), contains('trichome'), contains('trichom')),
      );
    });

    test('TC-17-10: Orchideen-Luftwurzeln Edge-Case im Prompt', () {
      expect(
        prompt.toLowerCase(),
        anyOf(contains('orchidee'), contains('orchideen'), contains('phalaenopsis')),
      );
    });

    test('TC-17-11: Gesund-Regel: overall_health good + leeres findings-Array', () {
      // Prompt muss die Gesund-Regel explizit enthalten
      expect(
        prompt,
        anyOf(contains('findings-Array'), contains('leeres'), contains('LEERES')),
      );
    });

    test('TC-17-12: Prompt enthält confidence-Pflicht-Erklärung', () {
      expect(prompt, contains('"confidence"'));
      expect(
        prompt.toLowerCase(),
        anyOf(contains('confidence'), contains('konfidenz')),
      );
    });
  });

  group('AK-1b / Prompt – Sorgfaltspflicht-Block vorhanden (DeepSeek)', () {
    late String prompt;
    setUpAll(() {
      prompt = DiagnosisSchema.buildDeepSeekPrompt(plantName: 'Monstera');
    });

    test('TC-17-13: DeepSeek-Prompt enthält Sorgfaltspflicht-Block', () {
      expect(prompt, contains('DIAGNOSTISCHE SORGFALTSPFLICHT'));
    });

    test('TC-17-14: DeepSeek-Prompt enthält Monstera-Luftwurzeln-Edge-Case', () {
      expect(prompt, contains('Monstera'));
      expect(
        prompt.toLowerCase(),
        anyOf(contains('luftwurzel'), contains('luftwurzeln')),
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // AK-2: confidence-Feld im Schema + Finding-Modell
  // ─────────────────────────────────────────────────────────────────────────

  group('AK-2 / Schema: confidence-Feld dokumentiert und parsebar', () {
    test('TC-17-15: schemaDescription enthält confidence-Feld', () {
      expect(DiagnosisSchema.schemaDescription, contains('"confidence"'));
      expect(
        DiagnosisSchema.schemaDescription,
        contains('high|medium|low'),
      );
    });

    test('TC-17-16: Claude-Prompt enthält confidence in den Schema-Hinweisen', () {
      final prompt = DiagnosisSchema.buildClaudePrompt(plantName: 'Test');
      // Muss in den "Hinweise:"-Zeilen als Pflicht-Feld auftauchen
      expect(prompt, contains('"confidence"'));
    });

    test('TC-17-17: Confidence.fromString("high") → Confidence.high', () {
      expect(Confidence.fromString('high'), equals(Confidence.high));
    });

    test('TC-17-18: Confidence.fromString("medium") → Confidence.medium', () {
      expect(Confidence.fromString('medium'), equals(Confidence.medium));
    });

    test('TC-17-19: Confidence.fromString("low") → Confidence.low', () {
      expect(Confidence.fromString('low'), equals(Confidence.low));
    });

    test('TC-17-20: Confidence.fromString(null) → Confidence.high (Abwärtskompatibilität)', () {
      expect(Confidence.fromString(null), equals(Confidence.high));
    });

    test('TC-17-21: Confidence.fromString("") → Confidence.high (leerer String)', () {
      expect(Confidence.fromString(''), equals(Confidence.high));
    });

    test('TC-17-22: Confidence.fromString("UNKNOWN") → Confidence.high (Fallback)', () {
      expect(Confidence.fromString('UNKNOWN'), equals(Confidence.high));
    });

    test('TC-17-23: Confidence.label gibt deutschen Text zurück', () {
      expect(Confidence.high.label, equals('Sicher'));
      expect(Confidence.medium.label, equals('Wahrscheinlich'));
      expect(Confidence.low.label, equals('Möglich'));
    });

    test('TC-17-24: Finding.fromJson liest confidence-Feld korrekt', () {
      final finding = Finding.fromJson({
        'type': 'pest',
        'severity': 'high',
        'confidence': 'low',
        'title': 'Test',
        'evidence': 'Test',
        'treatment': 'Test',
      });
      expect(finding.confidence, equals(Confidence.low));
    });

    test('TC-17-25: Finding.fromJson ohne confidence → Confidence.high (Altdaten)', () {
      final finding = Finding.fromJson({
        'type': 'pest',
        'severity': 'high',
        // kein confidence-Feld
        'title': 'Test',
        'evidence': 'Test',
        'treatment': 'Test',
      });
      expect(finding.confidence, equals(Confidence.high));
    });

    test('TC-17-26: Finding.toJson schreibt confidence-Feld', () {
      const finding = Finding(
        type: FindingType.pest,
        severity: Severity.high,
        confidence: Confidence.medium,
        title: 'Test',
        evidence: 'Test',
        treatment: 'Test',
      );
      final json = finding.toJson();
      expect(json['confidence'], equals('medium'));
    });

    test('TC-17-27: Finding default-Konstruktor hat confidence = Confidence.high', () {
      const finding = Finding(
        type: FindingType.pest,
        severity: Severity.low,
        title: 'Test',
        evidence: '',
        treatment: '',
      );
      expect(finding.confidence, equals(Confidence.high));
    });

    test('TC-17-28: DiagnosisParser parst confidence in Findings korrekt', () {
      final raw = _diagnosisJsonWithConfidence();
      final result = DiagnosisParser.parse(raw);
      expect(result.isSuccess, isTrue);
      final findings = result.valueOrNull!.findings;
      // findings[0] hat confidence=low
      final lowFinding = findings.firstWhere(
        (f) => f.title == 'Mögliche Gelbfärbung',
      );
      expect(lowFinding.confidence, equals(Confidence.low));
      // findings[1] hat confidence=high
      final highFinding = findings.firstWhere(
        (f) => f.title == 'Spinnmilben',
      );
      expect(highFinding.confidence, equals(Confidence.high));
      // findings[2] hat confidence=medium
      final mediumFinding = findings.firstWhere(
        (f) => f.title == 'Eisenmangel',
      );
      expect(mediumFinding.confidence, equals(Confidence.medium));
    });

    test('TC-17-29: DiagnosisParser – altes JSON ohne confidence → high (Regression)', () {
      final raw = _diagnosisJsonLegacy();
      final result = DiagnosisParser.parse(raw);
      expect(result.isSuccess, isTrue);
      final findings = result.valueOrNull!.findings;
      expect(findings, hasLength(1));
      // Altdaten ohne confidence → immer high
      expect(findings[0].confidence, equals(Confidence.high));
    });

    test('TC-17-30: Finding Round-Trip toJson → fromJson behält confidence', () {
      const original = Finding(
        type: FindingType.disease,
        severity: Severity.medium,
        confidence: Confidence.low,
        title: 'Pilzbefall',
        evidence: 'Weißer Belag.',
        treatment: 'Fungizid.',
      );
      final restored = Finding.fromJson(original.toJson());
      expect(restored.confidence, equals(Confidence.low));
      expect(restored.title, equals(original.title));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // AK-3: FindingCard – visueller Hinweis bei confidence:low
  // ─────────────────────────────────────────────────────────────────────────

  group('AK-3 / FindingCard – Confidence UI', () {
    Widget _wrap(Finding finding) => MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: FindingCard(finding: finding))),
        );

    testWidgets('TC-17-31: confidence:low zeigt „Möglich"-Badge in Titelzeile',
        (tester) async {
      const finding = Finding(
        type: FindingType.environmental,
        severity: Severity.low,
        confidence: Confidence.low,
        title: 'Mögliche Gelbfärbung',
        evidence: 'Einzelne leicht gelbliche Stelle.',
        treatment: 'Standort prüfen.',
      );
      await tester.pumpWidget(_wrap(finding));
      await tester.pumpAndSettle();

      // "Möglich"-Label aus _ConfidenceBadge
      expect(find.text('Möglich'), findsOneWidget);
    });

    testWidgets('TC-17-32: confidence:low zeigt help_outline-Icon',
        (tester) async {
      const finding = Finding(
        type: FindingType.environmental,
        severity: Severity.low,
        confidence: Confidence.low,
        title: 'Unsichere Diagnose',
        evidence: 'Unklar.',
        treatment: 'Prüfen.',
      );
      await tester.pumpWidget(_wrap(finding));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.help_outline), findsWidgets);
    });

    testWidgets(
        'TC-17-33: confidence:low – Opacity 0.78: Opacity-Widget vorhanden',
        (tester) async {
      const finding = Finding(
        type: FindingType.pest,
        severity: Severity.medium,
        confidence: Confidence.low,
        title: 'Möglicher Schädling',
        evidence: 'Kleine Punkte.',
        treatment: 'Spray.',
      );
      await tester.pumpWidget(_wrap(finding));
      await tester.pumpAndSettle();

      // Opacity-Widget mit 0.78 muss in der Widget-Tree vorhanden sein
      final opacityWidget = tester.widget<Opacity>(find.byType(Opacity).first);
      expect(opacityWidget.opacity, closeTo(0.78, 0.01));
    });

    testWidgets(
        'TC-17-34: confidence:low – bei Aufklappen erscheint Hinweis-Text „Möglicher Befund"',
        (tester) async {
      const finding = Finding(
        type: FindingType.environmental,
        severity: Severity.low,
        confidence: Confidence.low,
        title: 'Low Confidence Test',
        evidence: 'Evidence vorhanden.',
        treatment: 'Behandlung vorhanden.',
      );
      await tester.pumpWidget(_wrap(finding));
      await tester.pumpAndSettle();

      // Karte aufklappen
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Confidence-Hint-Text muss sichtbar sein
      expect(find.textContaining('Möglicher Befund'), findsOneWidget);
    });

    testWidgets('TC-17-35: confidence:medium zeigt „Wahrscheinlich"-Badge',
        (tester) async {
      const finding = Finding(
        type: FindingType.deficiency,
        severity: Severity.medium,
        confidence: Confidence.medium,
        title: 'Wahrscheinlicher Mangel',
        evidence: 'Chlorose.',
        treatment: 'Düngen.',
      );
      await tester.pumpWidget(_wrap(finding));
      await tester.pumpAndSettle();

      expect(find.text('Wahrscheinlich'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets(
        'TC-17-36: confidence:high zeigt KEINEN Confidence-Badge (unveränderte Darstellung)',
        (tester) async {
      const finding = Finding(
        type: FindingType.pest,
        severity: Severity.high,
        confidence: Confidence.high,
        title: 'Eindeutiger Befall',
        evidence: 'Gespinste.',
        treatment: 'Neem-Öl.',
      );
      await tester.pumpWidget(_wrap(finding));
      await tester.pumpAndSettle();

      // Weder "Möglich" noch "Wahrscheinlich" Badge
      expect(find.text('Möglich'), findsNothing);
      expect(find.text('Wahrscheinlich'), findsNothing);
      expect(find.byIcon(Icons.help_outline), findsNothing);
      expect(find.byIcon(Icons.info_outline), findsNothing);
    });

    testWidgets(
        'TC-17-37: confidence:high – Opacity 1.0 (keine Abschwächung)',
        (tester) async {
      const finding = Finding(
        type: FindingType.disease,
        severity: Severity.high,
        confidence: Confidence.high,
        title: 'Schwere Krankheit',
        evidence: 'Klar sichtbar.',
        treatment: 'Fungizid.',
      );
      await tester.pumpWidget(_wrap(finding));
      await tester.pumpAndSettle();

      // Opacity-Widget muss 1.0 haben
      final opacityWidget = tester.widget<Opacity>(find.byType(Opacity).first);
      expect(opacityWidget.opacity, closeTo(1.0, 0.01));
    });

    testWidgets(
        'TC-17-38: confidence:medium zeigt KEINEN help_outline-Icon (nicht "Möglich")',
        (tester) async {
      const finding = Finding(
        type: FindingType.pest,
        severity: Severity.medium,
        confidence: Confidence.medium,
        title: 'Medium Befall',
        evidence: 'Spuren.',
        treatment: 'Spray.',
      );
      await tester.pumpWidget(_wrap(finding));
      await tester.pumpAndSettle();

      // medium zeigt info_outline aber nicht help_outline
      expect(find.byIcon(Icons.help_outline), findsNothing);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // AK-4: speciesNotes im Prompt – careProfileJson eingespeist
  // ─────────────────────────────────────────────────────────────────────────

  group('AK-4 / Prompt – speciesNotes (careProfileJson) eingespeist', () {
    test('TC-17-39: Claude-Prompt mit speciesNotes enthält Art-spezifischen Hinweis-Block', () {
      const notes = 'Wissenschaftlicher Name: Monstera deliciosa Liebm.\n'
          'Familie: Araceae\n'
          'Weitere Art-Hinweise: Bildet artypische braune Luftwurzeln.';

      final prompt = DiagnosisSchema.buildClaudePrompt(
        plantName: 'Monstera',
        speciesNotes: notes,
      );

      expect(prompt, contains('Art-spezifische Hinweise aus der Pflanzenbestimmung'));
      expect(prompt, contains('Monstera deliciosa Liebm.'));
      expect(prompt, contains('Araceae'));
      expect(prompt, contains('Luftwurzeln'));
    });

    test('TC-17-40: Claude-Prompt ohne speciesNotes enthält KEINEN Art-Hinweis-Block', () {
      final prompt = DiagnosisSchema.buildClaudePrompt(
        plantName: 'Unbekannte Pflanze',
        speciesNotes: null,
      );

      expect(
        prompt,
        isNot(contains('Art-spezifische Hinweise aus der Pflanzenbestimmung')),
      );
    });

    test('TC-17-41: DeepSeek-Prompt mit speciesNotes enthält Art-spezifischen Block', () {
      const notes = 'Wissenschaftlicher Name: Ficus benjamina\n'
          'Weitere Art-Hinweise: Normaler Blattfall bei Standortwechsel.';

      final prompt = DiagnosisSchema.buildDeepSeekPrompt(
        plantName: 'Ficus',
        speciesNotes: notes,
      );

      expect(prompt, contains('Art-spezifische Hinweise aus der Pflanzenbestimmung'));
      expect(prompt, contains('Ficus benjamina'));
    });

    test('TC-17-42: speciesNotes wird VOR dem Sorgfaltspflicht-Block eingespeist', () {
      const notes = 'SPECIES_MARKER';
      final prompt = DiagnosisSchema.buildClaudePrompt(
        plantName: 'Test',
        speciesNotes: notes,
      );

      final speciesPos = prompt.indexOf('SPECIES_MARKER');
      final sorgfaltPos = prompt.indexOf('DIAGNOSTISCHE SORGFALTSPFLICHT');

      expect(speciesPos, greaterThan(-1), reason: 'speciesNotes fehlt im Prompt');
      expect(sorgfaltPos, greaterThan(-1), reason: 'Sorgfaltspflicht-Block fehlt im Prompt');
      expect(speciesPos, lessThan(sorgfaltPos),
          reason: 'speciesNotes muss VOR dem Sorgfaltspflicht-Block stehen');
    });

    test('TC-17-43: leerer speciesNotes-String (isEmpty) → kein Art-Hinweis-Block', () {
      final prompt = DiagnosisSchema.buildClaudePrompt(
        plantName: 'Test',
        speciesNotes: '',
      );

      expect(
        prompt,
        isNot(contains('Art-spezifische Hinweise aus der Pflanzenbestimmung')),
      );
    });

    test('TC-17-44: speciesNotes steht nach Pflanzennamen-Satz', () {
      const notes = 'SPECIES_NOTE_MARKER';
      final prompt = DiagnosisSchema.buildClaudePrompt(
        plantName: 'Monstera',
        speciesNotes: notes,
      );

      final plantNamePos = prompt.indexOf('Monstera');
      final speciesPos = prompt.indexOf('SPECIES_NOTE_MARKER');

      expect(speciesPos, greaterThan(plantNamePos),
          reason: 'speciesNotes muss nach Pflanzennamen stehen');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // AK-4b: _buildSpeciesNotes-Logik (Unit-Tests über PlantIdentificationResult)
  // ─────────────────────────────────────────────────────────────────────────

  group('AK-4b / _buildSpeciesNotes-Logik (via PlantIdentificationResult.fromJson)', () {
    test('TC-17-45: PlantIdentificationResult.fromJson liest additionalNotes', () {
      final json = jsonDecode(_careProfileJson()) as Map<String, dynamic>;
      final result = PlantIdentificationResult.fromJson(json);

      expect(result.additionalNotes, equals('Bildet artypische braune Luftwurzeln.'));
    });

    test('TC-17-46: PlantIdentificationResult.fromJson liest diagnosticNotes', () {
      final json = jsonDecode(_careProfileJson()) as Map<String, dynamic>;
      final result = PlantIdentificationResult.fromJson(json);

      expect(result.diagnosticNotes, equals('Braune, korkige Luftwurzeln sind normal.'));
    });

    test('TC-17-47: PlantIdentificationResult.fromJson liest scientificName', () {
      final json = jsonDecode(_careProfileJson()) as Map<String, dynamic>;
      final result = PlantIdentificationResult.fromJson(json);

      expect(result.scientificName, equals('Monstera deliciosa Liebm.'));
    });

    test('TC-17-48: PlantIdentificationResult.fromJson liest family', () {
      final json = jsonDecode(_careProfileJson()) as Map<String, dynamic>;
      final result = PlantIdentificationResult.fromJson(json);

      expect(result.family, equals('Araceae'));
    });

    test('TC-17-49: PlantIdentificationResult.fromJson – CareProfile korrekt geladen', () {
      final json = jsonDecode(_careProfileJson()) as Map<String, dynamic>;
      final result = PlantIdentificationResult.fromJson(json);

      expect(result.careProfile.water.shortValue, equals('Mittel'));
      expect(result.careProfile.light.shortValue, equals('Hell'));
      expect(result.careProfile.humidity.shortValue, equals('Hoch'));
    });

    test('TC-17-50: PlantIdentificationResult.fromJson ohne optionale Felder → null (kein Crash)', () {
      final json = jsonDecode(jsonEncode({
        'name': 'Unbekannte Pflanze',
        'care_profile': {
          'water': {'short_value': '', 'detail': ''},
          'light': {'short_value': '', 'detail': ''},
          'humidity': {'short_value': '', 'detail': ''},
          'temperature': {'short_value': '', 'detail': ''},
          'soil': {'short_value': '', 'detail': ''},
          'repotting': {'short_value': '', 'detail': ''},
        },
        'difficulty': 'easy',
        'toxicity': {'is_toxic': false, 'details': ''},
        // additionalNotes, diagnosticNotes, scientificName, family FEHLEN
      })) as Map<String, dynamic>;

      PlantIdentificationResult? result;
      expect(() {
        result = PlantIdentificationResult.fromJson(json);
      }, returnsNormally);

      expect(result!.additionalNotes, isNull);
      expect(result!.diagnosticNotes, isNull);
      expect(result!.scientificName, isNull);
      expect(result!.family, isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // AK-5: Abwärtskompatibilität gespeicherter Diagnosen ohne confidence
  // ─────────────────────────────────────────────────────────────────────────

  group('AK-5 / Abwärtskompatibilität – Altdaten ohne confidence', () {
    test('TC-17-51: Finding-Altdaten ohne confidence werden als high behandelt', () {
      // Simuliert das Laden einer alten gespeicherten Diagnose aus der DB
      const legacyFindingMap = {
        'type': 'disease',
        'severity': 'high',
        'title': 'Altes Finding ohne confidence',
        'evidence': 'Aus alter App-Version.',
        'treatment': 'Wie gehabt.',
        // KEIN confidence-Feld
      };

      final finding = Finding.fromJson(legacyFindingMap);
      expect(finding.confidence, equals(Confidence.high));
    });

    test('TC-17-52: Vollständiges Legacy-JSON (mehrere Findings ohne confidence) → alle high', () {
      final raw = _diagnosisJsonLegacy();
      final result = DiagnosisParser.parse(raw);

      expect(result.isSuccess, isTrue);
      for (final f in result.valueOrNull!.findings) {
        expect(f.confidence, equals(Confidence.high),
            reason: 'Alle Legacy-Findings ohne confidence-Feld müssen als high behandelt werden');
      }
    });

    test('TC-17-53: Confidence-Enum hat genau 3 Werte', () {
      expect(Confidence.values, hasLength(3));
      expect(Confidence.values, containsAll([Confidence.high, Confidence.medium, Confidence.low]));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Integrations-Test: Vollständiger Parser-Durchlauf mit confidence
  // ─────────────────────────────────────────────────────────────────────────

  group('Integration / Parser + Confidence + UI-Smoke', () {
    test('TC-17-54: Parser-Durchlauf mit gemischten confidence-Werten (kein Crash)', () {
      // Simuliert realen Claude-Output mit allen drei Confidence-Stufen
      final raw = jsonEncode({
        'overall_health': 'fair',
        'summary': 'Pflanze zeigt gemischtes Bild.',
        'findings': [
          {
            'type': 'environmental',
            'severity': 'low',
            'confidence': 'low',
            'title': 'Unsichere Gelbfärbung',
            'evidence': 'Möglicherweise Kunstlicht-Effekt.',
            'treatment': 'Standort wechseln.',
          },
          {
            'type': 'pest',
            'severity': 'high',
            'confidence': 'high',
            'title': 'Spinnmilben',
            'evidence': 'Gespinste auf Blattunterseite.',
            'treatment': 'Neem-Öl wöchentlich.',
          },
        ],
        'recommendations': {
          'watering': 'Alle 7 Tage.',
          'fertilizer': {'advice': 'Monatlich.', 'product': null},
          'location': 'Helles Fensterbrett.',
          'other': <String>[],
        },
        'comparison_to_previous': null,
      });

      ParseResult<DiagnosisResult>? result;
      expect(() { result = DiagnosisParser.parse(raw); }, returnsNormally);
      expect(result!.isSuccess, isTrue);
      expect(result!.valueOrNull, isNotNull);
    });

    test('TC-17-55: Gesund-Pflanze: overall=good + findings=[] – kein Crash', () {
      // Monstera gesund: Claude sollte [] zurückgeben
      final raw = jsonEncode({
        'overall_health': 'good',
        'summary': 'Die Monstera ist völlig gesund. Luftwurzeln sind artypisch normal.',
        'findings': <dynamic>[],
        'recommendations': {
          'watering': 'Alle 7–10 Tage.',
          'fertilizer': {'advice': 'Sommerhalbjahr monatlich.', 'product': null},
          'location': 'Heller Standort.',
          'other': <String>[],
        },
        'comparison_to_previous': null,
      });

      final result = DiagnosisParser.parse(raw);
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.findings, isEmpty);
      expect(result.valueOrNull!.overallHealth.name, equals('good'));
    });
  });
}
