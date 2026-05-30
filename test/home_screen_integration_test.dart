import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Prüft home_screen.dart auf korrekte Integration aller neuen Features.
void main() {
  late String source;
  setUpAll(() {
    source = File('lib/screens/home_screen.dart').readAsStringSync();
  });

  group('HomeScreen – PhotoTipsSheet Integration', () {
    test('photo_tips_sheet.dart ist importiert', () {
      expect(source, contains("import '../widgets/photo_tips_sheet.dart'"),
          reason: 'photo_tips_sheet.dart muss importiert sein');
    });

    test('maybeShowPhotoTipsSheet wird in _takePhoto aufgerufen', () {
      // Suche nach dem Block mit _takePhoto und dem Aufruf
      expect(source, contains('await maybeShowPhotoTipsSheet(context)'),
          reason: 'maybeShowPhotoTipsSheet muss (mit await) aufgerufen werden');
    });

    test('_takePhoto ruft Sheet VOR dem Picker auf', () {
      // Das Sheet-Aufruf kommt vor pickImage
      final sheetIdx = source.indexOf('maybeShowPhotoTipsSheet');
      final cameraPickerIdx = source.indexOf('ImageSource.camera');
      expect(sheetIdx, lessThan(cameraPickerIdx),
          reason: 'Tips-Sheet muss VOR dem Kamera-Picker gezeigt werden');
    });

    test('_pickFromGallery ruft Sheet VOR dem Picker auf', () {
      final sheetIdx = source.indexOf('maybeShowPhotoTipsSheet');
      final galleryPickerIdx = source.indexOf('pickMultiImage');
      expect(sheetIdx, lessThan(galleryPickerIdx),
          reason: 'Tips-Sheet muss VOR dem Galerie-Picker gezeigt werden');
    });
  });

  group('HomeScreen – Dateigrößen-Check', () {
    test('_checkImageSize-Methode ist vorhanden', () {
      expect(source, contains('_checkImageSize'),
          reason: '_checkImageSize-Methode muss in home_screen.dart vorhanden sein');
    });

    test('30 KB Schwellwert ist korrekt (30 * 1024)', () {
      expect(source, contains('30 * 1024'),
          reason: 'Schwellwert muss 30 * 1024 Bytes (= 30 KB) sein');
    });

    test('Warnhinweis-Text ist vorhanden', () {
      expect(source, contains('zu klein sein'),
          reason: 'Warntext "Bild könnte zu klein sein" muss vorhanden sein');
    });

    test('SnackBar ist floating (nicht-blockierend)', () {
      expect(source, contains('SnackBarBehavior.floating'),
          reason: 'SnackBar muss als floating (nicht-blockierend) konfiguriert sein');
    });

    test('_checkImageSize wird für Kamera-Foto aufgerufen', () {
      // Suche nach dem Aufruf nach dem Kamera-Pick
      final cameraIdx = source.indexOf('ImageSource.camera');
      final checkIdx = source.indexOf('_checkImageSize(');
      expect(checkIdx, greaterThan(cameraIdx),
          reason: '_checkImageSize muss nach dem Kamera-Pick aufgerufen werden');
    });

    test('_checkImageSize wird für Galerie-Fotos aufgerufen', () {
      // Der Aufruf kann _checkImageSize(f) oder _checkImageSize(file) heißen
      final hasGalleryCheck = source.contains('_checkImageSize(f)') ||
          source.contains('_checkImageSize(file)');
      expect(hasGalleryCheck, isTrue,
          reason: '_checkImageSize muss auch für Galerie-Fotos aufgerufen werden');
    });

    test('mounted-Check nach async-Lücke in _takePhoto', () {
      expect(source, contains('if (!mounted) return'),
          reason: 'mounted-Check nach await muss vorhanden sein');
    });
  });

  group('HomeScreen – UI-Schicht bleibt sauber', () {
    test('ImageOptimizer wird NICHT direkt in home_screen.dart importiert', () {
      expect(source, isNot(contains('image_optimizer.dart')),
          reason: 'Optimierung gehört in AI-Services, nicht in home_screen.dart');
    });

    test('flutter_image_compress wird NICHT direkt in home_screen.dart importiert', () {
      expect(source, isNot(contains('flutter_image_compress')),
          reason: 'flutter_image_compress gehört nicht in die UI-Schicht');
    });
  });
}
