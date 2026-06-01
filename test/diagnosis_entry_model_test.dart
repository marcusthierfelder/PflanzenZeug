// test/diagnosis_entry_model_test.dart
//
// Unit-Tests für DiagnosisEntry: Serialisierung, Deserialisierung,
// Defensivverhalten bei Altdaten und Randfälle.

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:pflanzenwart/models/diagnosis/diagnosis_entry.dart';
import 'package:pflanzenwart/models/diagnosis/diagnosis_result.dart';

import 'package:pflanzenwart/models/diagnosis/recommendations.dart';

// ────────────────────────────────────────────────────────────────────────────
// Hilfsfunktionen
// ────────────────────────────────────────────────────────────────────────────

DiagnosisResult _minimalDiagnosisResult() => DiagnosisResult(
      overallHealth: OverallHealth.good,
      summary: 'Pflanze sieht gesund aus.',
      findings: [],
      recommendations: Recommendations(
        watering: 'Regelmäßig gießen.',
        fertilizer: FertilizerRecommendation(advice: 'Monatlich düngen.'),
        location: 'Halbschatten',
        other: [],
      ),
    );

DiagnosisEntry _buildEntry({
  String id = 'entry-id-1',
  String plantId = 'plant-id-1',
  DateTime? createdAt,
  OverallHealth health = OverallHealth.good,
  String summary = 'Alles bestens.',
  List<String> photoPaths = const ['photo1.jpg', 'photo2.jpg'],
  String? contextTag,
  DiagnosisResult? dr,
}) {
  final result = dr ?? _minimalDiagnosisResult();
  return DiagnosisEntry(
    id: id,
    plantId: plantId,
    createdAt: createdAt ?? DateTime(2024, 6, 15, 10, 30),
    overallHealth: health,
    summary: summary,
    diagnosisResultJson: result.toJsonString(),
    photoPaths: photoPaths,
    contextTag: contextTag,
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Tests
// ────────────────────────────────────────────────────────────────────────────

void main() {
  // ──────────────────────────────────────────────────────────────────────────
  // AK 1: Pflichtfelder werden korrekt gespeichert
  // ──────────────────────────────────────────────────────────────────────────
  group('DiagnosisEntry – Pflichtfelder', () {
    test('T01 | Alle Pflichtfelder werden bei Konstruktion gespeichert', () {
      final dt = DateTime(2024, 6, 15, 10, 30);
      final entry = _buildEntry(
        id: 'test-id',
        plantId: 'plant-42',
        createdAt: dt,
        health: OverallHealth.poor,
        summary: 'Blätter gelb',
        photoPaths: ['a.jpg', 'b.jpg'],
        contextTag: 'leaf',
      );

      expect(entry.id, equals('test-id'));
      expect(entry.plantId, equals('plant-42'));
      expect(entry.createdAt, equals(dt));
      expect(entry.overallHealth, equals(OverallHealth.poor));
      expect(entry.summary, equals('Blätter gelb'));
      expect(entry.photoPaths, equals(['a.jpg', 'b.jpg']));
      expect(entry.contextTag, equals('leaf'));
    });

    test('T02 | contextTag ist optional (null erlaubt)', () {
      final entry = _buildEntry(contextTag: null);
      expect(entry.contextTag, isNull);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // AK 1 + AK 5: toJson / fromJson Round-Trip
  // ──────────────────────────────────────────────────────────────────────────
  group('DiagnosisEntry – Serialisierung (toJson / fromJson)', () {
    test('T03 | toJson enthält alle Pflichtfelder', () {
      final entry = _buildEntry(
        id: 'e1',
        plantId: 'p1',
        createdAt: DateTime(2024, 1, 1),
        health: OverallHealth.fair,
        summary: 'Kleine Auffälligkeit',
        photoPaths: ['x.jpg'],
        contextTag: 'root',
      );

      final json = entry.toJson();

      expect(json['id'], equals('e1'));
      expect(json['plantId'], equals('p1'));
      expect(json['createdAt'], contains('2024-01-01'));
      expect(json['overallHealth'], equals('fair'));
      expect(json['summary'], equals('Kleine Auffälligkeit'));
      expect(json['photoPaths'], equals(['x.jpg']));
      expect(json['contextTag'], equals('root'));
      expect(json['diagnosisResultJson'], isA<String>());
    });

    test('T04 | toJson ohne contextTag enthält keinen contextTag-Key', () {
      final entry = _buildEntry(contextTag: null);
      final json = entry.toJson();
      expect(json.containsKey('contextTag'), isFalse);
    });

    test('T05 | fromJson → toJson Round-Trip ist verlustfrei', () {
      final original = _buildEntry(
        id: 'rt-1',
        plantId: 'rp-1',
        createdAt: DateTime(2025, 3, 22, 14, 5),
        health: OverallHealth.critical,
        summary: 'Kritisch!',
        photoPaths: ['img1.jpg', 'img2.jpg'],
        contextTag: 'flower',
      );

      final json = original.toJson();
      final restored = DiagnosisEntry.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.plantId, equals(original.plantId));
      expect(restored.createdAt, equals(original.createdAt));
      expect(restored.overallHealth, equals(original.overallHealth));
      expect(restored.summary, equals(original.summary));
      expect(restored.photoPaths, equals(original.photoPaths));
      expect(restored.contextTag, equals(original.contextTag));
      expect(restored.diagnosisResultJson, equals(original.diagnosisResultJson));
    });

    test('T06 | fromJson ist defensiv bei fehlendem contextTag', () {
      final json = _buildEntry().toJson()..remove('contextTag');
      final entry = DiagnosisEntry.fromJson(json);
      expect(entry.contextTag, isNull);
    });

    test('T07 | fromJson ist defensiv bei fehlendem summary (Altdaten)', () {
      final json = _buildEntry().toJson()..remove('summary');
      // Altdaten ohne summary – sollte leer-String liefern, kein Crash
      final entry = DiagnosisEntry.fromJson(json);
      expect(entry.summary, equals(''));
    });

    test('T08 | fromJson ist defensiv bei fehlendem photoPaths (Altdaten)', () {
      final json = _buildEntry().toJson()..remove('photoPaths');
      // Altdaten ohne photoPaths – sollte leere Liste liefern
      // Aber fromJson erwartet photoPaths – prüfen ob Exception oder leere Liste
      // Die aktuelle Implementierung: rawPaths = null → <String>[]
      expect(
        () => DiagnosisEntry.fromJson(json),
        returnsNormally,
      );
      final entry = DiagnosisEntry.fromJson(json);
      expect(entry.photoPaths, isEmpty);
    });

    test('T09 | fromJson liefert korrekten OverallHealth bei unbekanntem Wert (Fallback)', () {
      final json = _buildEntry().toJson();
      json['overallHealth'] = 'unknown_value';
      final entry = DiagnosisEntry.fromJson(json);
      // OverallHealth.fromString gibt bei unbekanntem Wert 'fair' zurück
      expect(entry.overallHealth, equals(OverallHealth.fair));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // AK 1: diagnosisResult Property (on-demand Deserialisierung)
  // ──────────────────────────────────────────────────────────────────────────
  group('DiagnosisEntry – diagnosisResult Property', () {
    test('T10 | diagnosisResult deserialisiert overallHealth korrekt', () {
      final dr = DiagnosisResult(
        overallHealth: OverallHealth.poor,
        summary: 'Mangelerscheinung',
        findings: [],
        recommendations: Recommendations(
          watering: 'Selten',
          fertilizer: FertilizerRecommendation(advice: ''),
          location: '',
          other: [],
        ),
      );
      final entry = _buildEntry(dr: dr);
      expect(entry.diagnosisResult.overallHealth, equals(OverallHealth.poor));
      expect(entry.diagnosisResult.summary, equals('Mangelerscheinung'));
    });

    test('T11 | diagnosisResult wirft Exception bei kaputtem JSON', () {
      final entry = DiagnosisEntry(
        id: 'x',
        plantId: 'y',
        createdAt: DateTime.now(),
        overallHealth: OverallHealth.fair,
        summary: 'x',
        diagnosisResultJson: '{kaputt:json}',
        photoPaths: [],
      );
      expect(() => entry.diagnosisResult, throwsException);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // AK 1: OverallHealth – alle Werte
  // ──────────────────────────────────────────────────────────────────────────
  group('OverallHealth – fromString', () {
    test('T12 | fromString erkennt alle 4 validen Werte', () {
      expect(OverallHealth.fromString('good'), equals(OverallHealth.good));
      expect(OverallHealth.fromString('fair'), equals(OverallHealth.fair));
      expect(OverallHealth.fromString('poor'), equals(OverallHealth.poor));
      expect(OverallHealth.fromString('critical'), equals(OverallHealth.critical));
    });

    test('T13 | fromString ist case-insensitive', () {
      expect(OverallHealth.fromString('Good'), equals(OverallHealth.good));
      expect(OverallHealth.fromString('FAIR'), equals(OverallHealth.fair));
      expect(OverallHealth.fromString('CRITICAL'), equals(OverallHealth.critical));
    });

    test('T14 | fromString-Fallback bei unbekanntem Wert liefert fair', () {
      expect(OverallHealth.fromString(''), equals(OverallHealth.fair));
      expect(OverallHealth.fromString('xyz'), equals(OverallHealth.fair));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // AK 5: Dual-Write – diagnosisResultJson als Cache-Feld
  // ──────────────────────────────────────────────────────────────────────────
  group('DiagnosisResult – toJsonString / fromJson Konsistenz (previousDiagnosis)', () {
    test('T15 | toJsonString → fromJson erhält overallHealth', () {
      final dr = DiagnosisResult(
        overallHealth: OverallHealth.good,
        summary: 'Alles gut',
        findings: const [],
        recommendations: Recommendations(
          watering: '',
          fertilizer: FertilizerRecommendation(advice: ''),
          location: '',
          other: [],
        ),
      );
      final jsonStr = dr.toJsonString();
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      final restored = DiagnosisResult.fromJson(parsed);

      expect(restored.overallHealth, equals(OverallHealth.good));
      expect(restored.summary, equals('Alles gut'));
    });

    test('T16 | toMarkdown enthält Gesundheitszustand-Label', () {
      final dr = DiagnosisResult(
        overallHealth: OverallHealth.critical,
        summary: 'Sofortiger Handlungsbedarf',
        findings: const [],
        recommendations: Recommendations(
          watering: 'Wenig',
          fertilizer: FertilizerRecommendation(advice: ''),
          location: '',
          other: [],
        ),
      );
      final md = dr.toMarkdown();
      expect(md, contains('Gesundheitszustand'));
      expect(md, contains('Akut handeln'));
      expect(md, contains('Sofortiger Handlungsbedarf'));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Sortierung: neueste zuerst
  // ──────────────────────────────────────────────────────────────────────────
  group('DiagnosisEntry – Sortierung', () {
    test('T17 | Einträge lassen sich nach createdAt absteigend sortieren', () {
      final older = _buildEntry(createdAt: DateTime(2024, 1, 1), id: 'old');
      final newer = _buildEntry(createdAt: DateTime(2024, 6, 1), id: 'new');
      final newest = _buildEntry(createdAt: DateTime(2024, 12, 31), id: 'newest');

      final entries = [older, newest, newer];
      entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      expect(entries.first.id, equals('newest'));
      expect(entries[1].id, equals('new'));
      expect(entries.last.id, equals('old'));
    });
  });
}
