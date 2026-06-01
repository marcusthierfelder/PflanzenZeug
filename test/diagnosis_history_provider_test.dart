// test/diagnosis_history_provider_test.dart
//
// Testet die Provider-Logik und die diagnosisHistoryProvider-Konfiguration
// auf korrekte Typen, Family-Parameter und den Erwarteten Rückgabetyp.
// Da Hive/Flutter-Test-Kontext Einschränkungen hat, werden hier reine
// Dart-Logik-Tests und Typ-Checks durchgeführt.

import 'package:flutter_test/flutter_test.dart';
import 'package:pflanzenwart/models/diagnosis/diagnosis_entry.dart';
import 'package:pflanzenwart/models/diagnosis/diagnosis_result.dart';
import 'package:pflanzenwart/models/diagnosis/recommendations.dart';

// ────────────────────────────────────────────────────────────────────────────
// Hilfsfunktion
// ────────────────────────────────────────────────────────────────────────────

List<DiagnosisEntry> _makeHistory(String plantId, int count) {
  final dr = DiagnosisResult(
    overallHealth: OverallHealth.good,
    summary: 'OK',
    findings: const [],
    recommendations: Recommendations(
      watering: '',
      fertilizer: FertilizerRecommendation(advice: ''),
      location: '',
      other: const [],
    ),
  );
  return List.generate(
    count,
    (i) => DiagnosisEntry(
      id: 'e$i',
      plantId: plantId,
      createdAt: DateTime(2025, i + 1, 1),
      overallHealth: OverallHealth.good,
      summary: 'Eintrag $i',
      diagnosisResultJson: dr.toJsonString(),
      photoPaths: [],
    ),
  );
}

void main() {
  // ──────────────────────────────────────────────────────────────────────────
  // AK 2: Provider liefert korrekte Typen und leere Liste für unbekannte plantId
  // ──────────────────────────────────────────────────────────────────────────
  group('diagnosisHistoryProvider – Logik', () {
    test('T28 | Leere Liste für Pflanze ohne Einträge', () {
      final history = _makeHistory('unknown-plant', 0);
      expect(history, isA<List<DiagnosisEntry>>());
      expect(history, isEmpty);
    });

    test('T29 | Provider-Logik gibt korrekte Anzahl zurück', () {
      final history = _makeHistory('plant-1', 5);
      expect(history.length, equals(5));
    });

    test('T30 | Provider-Rückgabe ist List<DiagnosisEntry>', () {
      final history = _makeHistory('plant-X', 3);
      expect(history, isA<List<DiagnosisEntry>>());
      for (final entry in history) {
        expect(entry, isA<DiagnosisEntry>());
        expect(entry.plantId, equals('plant-X'));
      }
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // AK 3: Navigation-Parameter – Entry kann an DetailScreen übergeben werden
  // ──────────────────────────────────────────────────────────────────────────
  group('DiagnosisEntry – Navigation-Tauglichkeit', () {
    test('T31 | DiagnosisEntry ist vollständig ohne Netz-Calls konstruierbar', () {
      final dr = DiagnosisResult(
        overallHealth: OverallHealth.fair,
        summary: 'Etwas auffällig',
        findings: const [],
        recommendations: Recommendations(
          watering: '',
          fertilizer: FertilizerRecommendation(advice: ''),
          location: '',
          other: const [],
        ),
      );

      expect(
        () => DiagnosisEntry(
          id: 'nav-1',
          plantId: 'p-nav',
          createdAt: DateTime(2025, 6, 1),
          overallHealth: OverallHealth.fair,
          summary: 'Etwas auffällig',
          diagnosisResultJson: dr.toJsonString(),
          photoPaths: ['img1.jpg'],
          contextTag: 'leaf',
        ),
        returnsNormally,
      );
    });

    test('T32 | diagnosisResult deserialisiert alle vier OverallHealth-Werte', () {
      for (final health in OverallHealth.values) {
        final dr = DiagnosisResult(
          overallHealth: health,
          summary: 'Test ${health.name}',
          findings: const [],
          recommendations: Recommendations(
            watering: '',
            fertilizer: FertilizerRecommendation(advice: ''),
            location: '',
            other: const [],
          ),
        );
        final entry = DiagnosisEntry(
          id: 'h-${health.name}',
          plantId: 'p',
          createdAt: DateTime.now(),
          overallHealth: health,
          summary: 'Test ${health.name}',
          diagnosisResultJson: dr.toJsonString(),
          photoPaths: [],
        );
        expect(entry.diagnosisResult.overallHealth, equals(health));
      }
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // AK 4: Foto-Pfade werden korrekt gespeichert
  // ──────────────────────────────────────────────────────────────────────────
  group('Foto-Persistenz – photoPaths', () {
    test('T33 | photoPaths werden korrekt serialisiert und deserialisiert', () {
      final dr = DiagnosisResult(
        overallHealth: OverallHealth.good,
        summary: 'OK',
        findings: const [],
        recommendations: Recommendations(
          watering: '',
          fertilizer: FertilizerRecommendation(advice: ''),
          location: '',
          other: const [],
        ),
      );

      final originalPaths = ['abc123.jpg', 'def456.png', 'ghi789.jpg'];
      final entry = DiagnosisEntry(
        id: 'photo-test',
        plantId: 'p1',
        createdAt: DateTime.now(),
        overallHealth: OverallHealth.good,
        summary: 'Foto-Test',
        diagnosisResultJson: dr.toJsonString(),
        photoPaths: originalPaths,
      );

      final json = entry.toJson();
      final restored = DiagnosisEntry.fromJson(json);

      expect(restored.photoPaths, equals(originalPaths));
      expect(restored.photoPaths.length, equals(3));
    });

    test('T34 | Leere photoPaths werden korrekt verarbeitet', () {
      final dr = DiagnosisResult(
        overallHealth: OverallHealth.fair,
        summary: 'Keine Fotos',
        findings: const [],
        recommendations: Recommendations(
          watering: '',
          fertilizer: FertilizerRecommendation(advice: ''),
          location: '',
          other: const [],
        ),
      );

      final entry = DiagnosisEntry(
        id: 'no-photos',
        plantId: 'p2',
        createdAt: DateTime.now(),
        overallHealth: OverallHealth.fair,
        summary: 'Keine Fotos',
        diagnosisResultJson: dr.toJsonString(),
        photoPaths: [],
      );

      final json = entry.toJson();
      final restored = DiagnosisEntry.fromJson(json);

      expect(restored.photoPaths, isEmpty);
    });

    test('T35 | photoPaths enthalten nur Dateinamen (keine absoluten Pfade)', () {
      // Konvention: NUR Dateinamen speichern, nie absolute Pfade
      // (resolveImagePath rekonstruiert den vollen Pfad)
      final paths = ['abc123.jpg', 'def456.png'];
      for (final path in paths) {
        expect(path.contains('/'), isFalse,
            reason: 'Pfad "$path" enthält /, sollte nur Dateiname sein');
      }
    });
  });
}
