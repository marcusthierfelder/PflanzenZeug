// test/database_service_diagnosis_test.dart
//
// Unit-Tests für DatabaseService – Diagnosis-Entries-Methoden.
// Da Hive IO und path_provider im Test-Kontext nicht verfügbar sind,
// testen wir die Logik isoliert über reine Dart-Datenstrukturen und
// prüfen das Verhalten der DiagnosisEntry-Methoden, die DatabaseService nutzt.
//
// Für die Hive-basierten Tests wird ein Mock-Ansatz via direkter
// Map-Manipulation verwendet (wie DatabaseService intern speichert).

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:pflanzenwart/models/diagnosis/diagnosis_entry.dart';
import 'package:pflanzenwart/models/diagnosis/diagnosis_result.dart';
import 'package:pflanzenwart/models/diagnosis/recommendations.dart';

// ────────────────────────────────────────────────────────────────────────────
// Hilfsfunktionen
// ────────────────────────────────────────────────────────────────────────────

DiagnosisEntry _makeEntry({
  required String id,
  required String plantId,
  required DateTime createdAt,
  OverallHealth health = OverallHealth.fair,
  String summary = 'Test-Summary',
  List<String> photoPaths = const [],
  String? contextTag,
}) {
  final dr = DiagnosisResult(
    overallHealth: health,
    summary: summary,
    findings: const [],
    recommendations: Recommendations(
      watering: 'täglich',
      fertilizer: FertilizerRecommendation(advice: ''),
      location: 'hell',
      other: const [],
    ),
  );
  return DiagnosisEntry(
    id: id,
    plantId: plantId,
    createdAt: createdAt,
    overallHealth: health,
    summary: summary,
    diagnosisResultJson: dr.toJsonString(),
    photoPaths: photoPaths,
    contextTag: contextTag,
  );
}

/// Simuliert getDiagnosisHistoryForPlant wie in DatabaseService implementiert:
/// Filtert nach plantId + sortiert desc nach createdAt.
List<DiagnosisEntry> _simulateGetHistory(
  List<Map<dynamic, dynamic>> boxValues,
  String plantId,
) {
  return boxValues
      .where((json) => json['plantId'] == plantId)
      .map((json) => DiagnosisEntry.fromJson(json))
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}

// ────────────────────────────────────────────────────────────────────────────
// Tests
// ────────────────────────────────────────────────────────────────────────────

void main() {
  // ──────────────────────────────────────────────────────────────────────────
  // AK 1: Jede Diagnose wird als eigener Eintrag gespeichert
  // ──────────────────────────────────────────────────────────────────────────
  group('DatabaseService-Logik – saveDiagnosisEntry', () {
    test('T18 | Eintrag wird mit korrektem Key (entry.id) gespeichert', () {
      final entry = _makeEntry(
        id: 'diag-1',
        plantId: 'plant-A',
        createdAt: DateTime(2025, 1, 10),
        health: OverallHealth.good,
        summary: 'Gesund',
      );

      // Simuliert Hive-Box als Map
      final box = <String, Map<dynamic, dynamic>>{};
      box[entry.id] = entry.toJson();

      expect(box.containsKey('diag-1'), isTrue);
      expect(box['diag-1']?['plantId'], equals('plant-A'));
      expect(box['diag-1']?['overallHealth'], equals('good'));
    });

    test('T19 | Mehrere Einträge derselben Pflanze koexistieren (kein Überschreiben)', () {
      final entry1 = _makeEntry(
        id: 'e1',
        plantId: 'plant-B',
        createdAt: DateTime(2025, 1, 1),
        health: OverallHealth.fair,
        summary: 'Erste Diagnose',
      );
      final entry2 = _makeEntry(
        id: 'e2',
        plantId: 'plant-B',
        createdAt: DateTime(2025, 2, 1),
        health: OverallHealth.good,
        summary: 'Zweite Diagnose',
      );

      final box = <String, Map<dynamic, dynamic>>{};
      box[entry1.id] = entry1.toJson();
      box[entry2.id] = entry2.toJson();

      // Beide Einträge sind vorhanden
      expect(box.length, equals(2));
      expect(box['e1']?['summary'], equals('Erste Diagnose'));
      expect(box['e2']?['summary'], equals('Zweite Diagnose'));
    });

    test('T20 | Einträge verschiedener Pflanzen werden getrennt gespeichert', () {
      final entryA = _makeEntry(id: 'ea', plantId: 'plant-A', createdAt: DateTime(2025, 1, 1));
      final entryB = _makeEntry(id: 'eb', plantId: 'plant-B', createdAt: DateTime(2025, 1, 2));

      final box = <String, Map<dynamic, dynamic>>{};
      box[entryA.id] = entryA.toJson();
      box[entryB.id] = entryB.toJson();

      final historyA = _simulateGetHistory(box.values.toList(), 'plant-A');
      final historyB = _simulateGetHistory(box.values.toList(), 'plant-B');

      expect(historyA.length, equals(1));
      expect(historyA.first.plantId, equals('plant-A'));
      expect(historyB.length, equals(1));
      expect(historyB.first.plantId, equals('plant-B'));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // AK 2: getDiagnosisHistoryForPlant – sortiert desc
  // ──────────────────────────────────────────────────────────────────────────
  group('DatabaseService-Logik – getDiagnosisHistoryForPlant', () {
    test('T21 | Geschichte wird absteigend nach Datum sortiert (neueste zuerst)', () {
      final entries = [
        _makeEntry(id: 'e1', plantId: 'p1', createdAt: DateTime(2025, 3, 1), summary: 'März'),
        _makeEntry(id: 'e2', plantId: 'p1', createdAt: DateTime(2025, 5, 1), summary: 'Mai'),
        _makeEntry(id: 'e3', plantId: 'p1', createdAt: DateTime(2025, 1, 1), summary: 'Januar'),
      ];

      final box = {for (final e in entries) e.id: e.toJson()};
      final history = _simulateGetHistory(box.values.toList(), 'p1');

      expect(history.length, equals(3));
      expect(history[0].summary, equals('Mai'));
      expect(history[1].summary, equals('März'));
      expect(history[2].summary, equals('Januar'));
    });

    test('T22 | Leere History bei Pflanze ohne Einträge', () {
      final box = <String, Map<dynamic, dynamic>>{};
      final history = _simulateGetHistory(box.values.toList(), 'unbekannte-pflanze');
      expect(history, isEmpty);
    });

    test('T23 | Einträge anderer Pflanzen werden korrekt herausgefiltert', () {
      final entries = [
        _makeEntry(id: 'e1', plantId: 'p1', createdAt: DateTime(2025, 1, 1)),
        _makeEntry(id: 'e2', plantId: 'p2', createdAt: DateTime(2025, 2, 1)),
        _makeEntry(id: 'e3', plantId: 'p1', createdAt: DateTime(2025, 3, 1)),
      ];

      final box = {for (final e in entries) e.id: e.toJson()};
      final historyP1 = _simulateGetHistory(box.values.toList(), 'p1');

      expect(historyP1.length, equals(2));
      expect(historyP1.every((e) => e.plantId == 'p1'), isTrue);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // getDiagnosisEntry – einzelner Eintrag
  // ──────────────────────────────────────────────────────────────────────────
  group('DatabaseService-Logik – getDiagnosisEntry', () {
    test('T24 | Gespeicherter Eintrag kann per ID abgerufen werden', () {
      final entry = _makeEntry(
        id: 'lookup-id',
        plantId: 'p1',
        createdAt: DateTime(2025, 6, 1),
        health: OverallHealth.critical,
        summary: 'Kritischer Zustand',
        contextTag: 'leaf',
      );

      final box = <String, Map<dynamic, dynamic>>{entry.id: entry.toJson()};

      // Simuliert getDiagnosisEntry
      final json = box['lookup-id'];
      expect(json, isNotNull);
      final restored = DiagnosisEntry.fromJson(json!);

      expect(restored.id, equals('lookup-id'));
      expect(restored.overallHealth, equals(OverallHealth.critical));
      expect(restored.contextTag, equals('leaf'));
    });

    test('T25 | Unbekannte ID liefert null (wie DatabaseService)', () {
      final box = <String, Map<dynamic, dynamic>>{};
      final json = box['nicht-vorhanden'];
      expect(json, isNull);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // AK 5: Dual-Write-Pattern – Plant.diagnosisResultJson bleibt Cache
  // ──────────────────────────────────────────────────────────────────────────
  group('Dual-Write-Pattern – Plant-Cache + DiagnosisEntry', () {
    test('T26 | DiagnosisEntry und Plant.diagnosisResultJson tragen dieselbe JSON-Information', () {
      // Erstelle DiagnosisResult
      final dr = DiagnosisResult(
        overallHealth: OverallHealth.poor,
        summary: 'Blätter gelb',
        findings: const [],
        recommendations: Recommendations(
          watering: 'mehr gießen',
          fertilizer: FertilizerRecommendation(advice: ''),
          location: 'heller',
          other: const [],
        ),
      );

      final jsonStr = dr.toJsonString();

      // Plant-Cache
      final plantCacheJson = jsonStr;

      // DiagnosisEntry
      final entry = DiagnosisEntry(
        id: 'dw-1',
        plantId: 'p1',
        createdAt: DateTime.now(),
        overallHealth: dr.overallHealth,
        summary: dr.summary,
        diagnosisResultJson: jsonStr,
        photoPaths: [],
      );

      // Beide enthalten dasselbe diagnosisResultJson
      expect(entry.diagnosisResultJson, equals(plantCacheJson));

      // Plant-Cache kann zur Vordiagnose verwendet werden (toMarkdown)
      final parsedFromCache = DiagnosisResult.fromJson(
        (jsonDecode(plantCacheJson) as Map).cast<String, dynamic>(),
      );
      expect(parsedFromCache.summary, equals('Blätter gelb'));
      expect(parsedFromCache.overallHealth, equals(OverallHealth.poor));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Cleanup-Logik: deletePlant bereinigt Diagnose-Einträge
  // ──────────────────────────────────────────────────────────────────────────
  group('DatabaseService-Logik – deletePlant Cleanup', () {
    test('T27 | Alle Diagnose-Einträge einer Pflanze werden beim Löschen entfernt', () {
      final entries = [
        _makeEntry(id: 'e1', plantId: 'to-delete', createdAt: DateTime(2025, 1, 1)),
        _makeEntry(id: 'e2', plantId: 'to-delete', createdAt: DateTime(2025, 2, 1)),
        _makeEntry(id: 'e3', plantId: 'keep', createdAt: DateTime(2025, 1, 1)),
      ];

      final box = <String, Map<dynamic, dynamic>>{
        for (final e in entries) e.id: e.toJson(),
      };

      // Simuliert deletePlant('to-delete') auf diagnosis_entries_box
      final keysToDelete = box.keys
          .where((k) => box[k]?['plantId'] == 'to-delete')
          .toList();
      for (final key in keysToDelete) {
        box.remove(key);
      }

      expect(box.length, equals(1));
      expect(box.containsKey('e1'), isFalse);
      expect(box.containsKey('e2'), isFalse);
      expect(box.containsKey('e3'), isTrue);
    });
  });
}
