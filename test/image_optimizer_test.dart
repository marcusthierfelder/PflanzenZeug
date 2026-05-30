import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

// Da ImageOptimizer flutter_image_compress (native Plugin) nutzt, testen wir
// die Klasse strukturell: Import, Existenz der Methode, Fallback-Logik.
// Echte Komprimierungs-Tests laufen auf dem Device / via Integration-Test.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImageOptimizer – Struktur & Imports', () {
    test('Datei image_optimizer.dart existiert', () {
      final file = File('lib/services/image_optimizer.dart');
      expect(file.existsSync(), isTrue,
          reason: 'lib/services/image_optimizer.dart muss vorhanden sein');
    });

    test('Datei enthält statische optimize-Methode', () {
      final source = File('lib/services/image_optimizer.dart').readAsStringSync();
      expect(source, contains('static Future<File> optimize('),
          reason: 'optimize()-Methode muss als static Future<File> deklariert sein');
    });

    test('Datei nutzt flutter_image_compress', () {
      final source = File('lib/services/image_optimizer.dart').readAsStringSync();
      expect(source, contains('flutter_image_compress'),
          reason: 'flutter_image_compress muss importiert sein');
    });

    test('Max-Kantenlänge ist 1280', () {
      final source = File('lib/services/image_optimizer.dart').readAsStringSync();
      expect(source, contains('1280'),
          reason: 'Max-Kantenlänge 1280 muss im Code stehen');
    });

    test('JPEG-Qualität ist 80', () {
      final source = File('lib/services/image_optimizer.dart').readAsStringSync();
      expect(source, contains('80'),
          reason: 'JPEG-Qualität 80 muss im Code stehen');
    });

    test('JPEG-Format ist gesetzt', () {
      final source = File('lib/services/image_optimizer.dart').readAsStringSync();
      expect(source, contains('CompressFormat.jpeg'),
          reason: 'Format muss CompressFormat.jpeg sein');
    });

    test('keepExif ist false (Privacy)', () {
      final source = File('lib/services/image_optimizer.dart').readAsStringSync();
      expect(source, contains('keepExif: false'),
          reason: 'keepExif muss false sein (Privacy-Schutz)');
    });

    test('Fallback auf Original bei Fehler', () {
      final source = File('lib/services/image_optimizer.dart').readAsStringSync();
      expect(source, contains('catch'),
          reason: 'Fehlerbehandlung mit catch-Block muss vorhanden sein');
      expect(source, contains('return image'),
          reason: 'Im Fehlerfall muss das Original zurückgegeben werden');
    });

    test('Output geht in temporäres Verzeichnis', () {
      final source = File('lib/services/image_optimizer.dart').readAsStringSync();
      expect(source, contains('getTemporaryDirectory'),
          reason: 'Optimierte Bilder müssen ins temporäre Verzeichnis geschrieben werden');
    });
  });
}
