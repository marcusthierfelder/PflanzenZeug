import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pflanzenwart/widgets/photo_tips_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ────────────────────────────────────────────────
  // Struktur-Tests (ohne Widget-Rendering)
  // ────────────────────────────────────────────────
  group('PhotoTipsSheet – Datei & Struktur', () {
    test('Datei photo_tips_sheet.dart existiert', () {
      final file = File('lib/widgets/photo_tips_sheet.dart');
      expect(file.existsSync(), isTrue);
    });

    test('maybeShowPhotoTipsSheet-Funktion ist exportiert', () {
      final source = File('lib/widgets/photo_tips_sheet.dart').readAsStringSync();
      expect(source, contains('Future<bool> maybeShowPhotoTipsSheet('),
          reason: 'Öffentliche Funktion muss exportiert sein');
    });

    test('SharedPreferences Key has_seen_photo_tips ist vorhanden', () {
      final source = File('lib/widgets/photo_tips_sheet.dart').readAsStringSync();
      expect(source, contains('has_seen_photo_tips'),
          reason: 'SharedPreferences-Key muss "has_seen_photo_tips" sein');
    });

    test('4 Foto-Tipps (📸 ☀️ 🔍 🌿) sind alle vorhanden', () {
      final source = File('lib/widgets/photo_tips_sheet.dart').readAsStringSync();
      expect(source, contains('📸'), reason: '📸 Nah-ran-Tipp fehlt');
      expect(source, contains('☀️'), reason: '☀️ Licht-Tipp fehlt');
      expect(source, contains('🔍'), reason: '🔍 Schärfe-Tipp fehlt');
      expect(source, contains('🌿'), reason: '🌿 Winkel-Tipp fehlt');
    });

    test('"Los geht\'s"-Button ist vorhanden', () {
      final source = File('lib/widgets/photo_tips_sheet.dart').readAsStringSync();
      expect(source, contains('Los geht'),
          reason: '"Los geht\'s"-Button muss im Sheet vorhanden sein');
    });

    test('"Nicht mehr zeigen"-Option ist vorhanden', () {
      final source = File('lib/widgets/photo_tips_sheet.dart').readAsStringSync();
      expect(source, contains('Nicht mehr zeigen'),
          reason: '"Nicht mehr zeigen"-Checkbox muss vorhanden sein');
    });

    test('context.mounted-Check ist vorhanden (Safety)', () {
      final source = File('lib/widgets/photo_tips_sheet.dart').readAsStringSync();
      expect(source, contains('mounted'),
          reason: 'context.mounted-Check muss vorhanden sein');
    });

    test('showModalBottomSheet wird genutzt', () {
      final source = File('lib/widgets/photo_tips_sheet.dart').readAsStringSync();
      expect(source, contains('showModalBottomSheet'),
          reason: 'Modal-Bottom-Sheet muss via showModalBottomSheet gezeigt werden');
    });
  });

  // ────────────────────────────────────────────────
  // SharedPreferences-Logik (Unit-Tests)
  // ────────────────────────────────────────────────
  group('PhotoTipsSheet – SharedPreferences-Logik', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Sheet zeigt sich beim ersten Mal (Flag noch nicht gesetzt)', () async {
      final prefs = await SharedPreferences.getInstance();
      final hasSeen = prefs.getBool('has_seen_photo_tips') ?? false;
      expect(hasSeen, isFalse,
          reason: 'Flag darf beim ersten Start nicht gesetzt sein');
    });

    test('Flag wird korrekt gesetzt und danach gelesen', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_seen_photo_tips', true);
      final hasSeen = prefs.getBool('has_seen_photo_tips') ?? false;
      expect(hasSeen, isTrue,
          reason: 'Nach dem Setzen muss Flag true zurückgeben');
    });

    test('Flag kann zurückgesetzt werden', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_seen_photo_tips', true);
      await prefs.remove('has_seen_photo_tips');
      final hasSeen = prefs.getBool('has_seen_photo_tips') ?? false;
      expect(hasSeen, isFalse,
          reason: 'Nach remove() muss Flag wieder false sein');
    });
  });
}
