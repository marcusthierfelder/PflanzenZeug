import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('pubspec.yaml – Neue Dependencies', () {
    late YamlMap pubspec;
    setUpAll(() {
      final content = File('pubspec.yaml').readAsStringSync();
      pubspec = loadYaml(content) as YamlMap;
    });

    test('flutter_image_compress ist deklariert', () {
      final deps = pubspec['dependencies'] as YamlMap;
      expect(deps.containsKey('flutter_image_compress'), isTrue,
          reason: 'flutter_image_compress muss in dependencies stehen');
    });

    test('flutter_image_compress Version ist ^2.3.0', () {
      final deps = pubspec['dependencies'] as YamlMap;
      final version = deps['flutter_image_compress'].toString();
      expect(version, equals('^2.3.0'),
          reason: 'Version muss genau ^2.3.0 sein (wie im Ticket spezifiziert)');
    });

    test('path ist als direkte Dependency deklariert', () {
      final deps = pubspec['dependencies'] as YamlMap;
      expect(deps.containsKey('path'), isTrue,
          reason: 'path muss als direkte Dependency deklariert sein (Linter-Konformität)');
    });

    test('shared_preferences ist vorhanden (für Flag-Persistierung)', () {
      final deps = pubspec['dependencies'] as YamlMap;
      expect(deps.containsKey('shared_preferences'), isTrue,
          reason: 'shared_preferences muss für PhotoTipsSheet vorhanden sein');
    });

    test('path_provider ist vorhanden (für temporäres Verzeichnis)', () {
      final deps = pubspec['dependencies'] as YamlMap;
      expect(deps.containsKey('path_provider'), isTrue,
          reason: 'path_provider muss für getTemporaryDirectory() vorhanden sein');
    });
  });
}
