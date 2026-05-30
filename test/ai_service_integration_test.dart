import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Prüft, dass beide AI-Services korrekt in die Bildoptimierung integriert sind.
void main() {
  group('ClaudeService – ImageOptimizer Integration', () {
    late String source;
    setUpAll(() {
      source = File('lib/services/claude_service.dart').readAsStringSync();
    });

    test('ImageOptimizer wird importiert', () {
      expect(source, contains("import 'image_optimizer.dart'"),
          reason: 'claude_service.dart muss image_optimizer.dart importieren');
    });

    test('_encodeImages ist async', () {
      expect(source, contains('Future<List<Map<String, dynamic>>> _encodeImages'),
          reason: '_encodeImages muss async (Future) sein');
    });

    test('ImageOptimizer.optimize wird in _encodeImages aufgerufen', () {
      expect(source, contains('ImageOptimizer.optimize('),
          reason: 'optimize() muss in _encodeImages aufgerufen werden');
    });

    test('optimize-Aufruf ist awaited', () {
      expect(source, contains('await ImageOptimizer.optimize('),
          reason: 'ImageOptimizer.optimize() muss mit await aufgerufen werden');
    });

    test('MIME-Type nach Optimierung ist image/jpeg', () {
      expect(source, contains("'image/jpeg'"),
          reason: 'MIME-Type nach Optimierung muss image/jpeg sein');
    });

    test('_encodeImages wird mit await aufgerufen (identifyPlant)', () {
      // Prüfe dass await _encodeImages() in identifyPlant vorkommt
      expect(source, contains('await _encodeImages('),
          reason: '_encodeImages muss immer mit await aufgerufen werden');
    });
  });

  group('DeepSeekService – ImageOptimizer Integration', () {
    late String source;
    setUpAll(() {
      source = File('lib/services/deepseek_service.dart').readAsStringSync();
    });

    test('ImageOptimizer wird importiert', () {
      expect(source, contains("import 'image_optimizer.dart'"),
          reason: 'deepseek_service.dart muss image_optimizer.dart importieren');
    });

    test('_encodeImages ist async', () {
      expect(source, contains('Future<List<Map<String, dynamic>>> _encodeImages'),
          reason: '_encodeImages muss async (Future) sein');
    });

    test('ImageOptimizer.optimize wird aufgerufen', () {
      expect(source, contains('ImageOptimizer.optimize('),
          reason: 'optimize() muss in _encodeImages aufgerufen werden');
    });

    test('optimize-Aufruf ist awaited', () {
      expect(source, contains('await ImageOptimizer.optimize('),
          reason: 'ImageOptimizer.optimize() muss mit await aufgerufen werden');
    });

    test('MIME-Type nach Optimierung ist image/jpeg', () {
      expect(source, contains("'image/jpeg'"),
          reason: 'MIME-Type nach Optimierung muss image/jpeg sein');
    });
  });
}
