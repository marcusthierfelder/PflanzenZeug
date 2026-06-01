/// Ticket #19 – API-Key Race-Condition Fix
///
/// Strategie: Source-Code-Analyse-Tests (wie im restlichen Testprojekt üblich)
/// da FlutterSecureStorage als const-Instanz nicht injizierbar ist.
/// Jede Prüfung entspricht einem Akzeptanzkriterium oder einer technischen
/// Anforderung aus dem Senior-Dev-Review.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String apiKeySource;
  late String aiProviderSource;

  setUpAll(() {
    apiKeySource =
        File('lib/providers/api_key_provider.dart').readAsStringSync();
    aiProviderSource =
        File('lib/providers/ai_provider.dart').readAsStringSync();
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Gruppe 1: ApiKeyNotifier – Kern-Fix (Race-Condition Gemini/Claude-Pfad)
  // ─────────────────────────────────────────────────────────────────────────
  group('ApiKeyNotifier – Race-Condition Fix', () {
    test(
        'AC-1a: setApiKey ruft ref.invalidateSelf() auf '
        '(kein manuelles state= mehr)', () {
      expect(
        apiKeySource,
        contains('ref.invalidateSelf()'),
        reason:
            'setApiKey muss ref.invalidateSelf() aufrufen um Race-Condition zu verhindern',
      );
    });

    test(
        'AC-1b: setApiKey enthält kein state = AsyncData(key) mehr '
        '(alte Race-Condition-Ursache – nur ausführbarer Code, nicht Kommentare)', () {
      // Kommentarzeilen entfernen, dann prüfen ob state = AsyncData( im Code vorkommt.
      final codeOnly = apiKeySource
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
      expect(
        codeOnly,
        isNot(contains('state = AsyncData(')),
        reason:
            'Manuelles state = AsyncData() im ausführbaren Code von ApiKeyNotifier '
            'verursacht Race-Condition – darf nur in Kommentaren vorkommen',
      );
    });

    test(
        'AC-1c: setApiKey wartet mit await future auf Abschluss des Re-Builds', () {
      expect(
        apiKeySource,
        contains('await future'),
        reason:
            'await future stellt sicher dass der Key nach setApiKey sofort verfügbar ist',
      );
    });

    test('AC-2: build() enthält iOS first_unlock Retry-Logik', () {
      // Prüfe dass ein Delay (50ms) + zweiter read vorhanden ist
      expect(
        apiKeySource,
        contains('Duration(milliseconds: 50)'),
        reason: 'iOS first_unlock Workaround: Retry nach 50ms muss vorhanden sein',
      );
    });

    test('AC-2b: build() führt zweiten Keychain-Read nach Retry durch', () {
      // Zähle wie oft _secureStorage.read vorkommt: mindestens 2 (primär + retry)
      final readCount =
          'key = await _secureStorage.read'.allMatches(apiKeySource).length;
      expect(
        readCount,
        greaterThanOrEqualTo(2),
        reason:
            'build() muss zwei read()-Aufrufe enthalten: primärer Read + Retry nach 50ms',
      );
    });

    test('AC-3: clearApiKey nutzt ebenfalls ref.invalidateSelf() '
        '(kein asymmetrischer Set/Clear-Pfad)', () {
      // clearApiKey muss auch invalidateSelf + await future nutzen
      final clearSection = apiKeySource
          .split('Future<void> clearApiKey')
          .last
          .split('}')
          .first;
      expect(
        clearSection,
        contains('ref.invalidateSelf()'),
        reason: 'clearApiKey muss analog zu setApiKey ref.invalidateSelf() nutzen',
      );
      expect(
        clearSection,
        contains('await future'),
        reason: 'clearApiKey muss await future nutzen für Konsistenz',
      );
    });

    test('AC-4: Migration aus SharedPreferences bleibt vor dem ersten Read', () {
      // _migrateFromSharedPreferences() muss VOR dem ersten _secureStorage.read
      // in build() aufgerufen werden (Reihenfolge prüfen)
      final buildSection =
          apiKeySource.split('@override').last.split('Future<void> ').first;
      final migratePos = buildSection.indexOf('_migrateFromSharedPreferences');
      final readPos = buildSection.indexOf('_secureStorage.read');
      expect(
        migratePos,
        lessThan(readPos),
        reason:
            'Migration muss VOR dem ersten Keychain-Read in build() aufgerufen werden',
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Gruppe 2: DeepSeekApiKeyNotifier – analoges Pattern (AC: beide Provider)
  // ─────────────────────────────────────────────────────────────────────────
  group('DeepSeekApiKeyNotifier – Race-Condition Fix', () {
    test(
        'AC-1a: setApiKey (DeepSeek) ruft ref.invalidateSelf() auf', () {
      // Im aiProviderSource nach dem DeepSeek-Block suchen
      final deepseekSection = aiProviderSource
          .split('class DeepSeekApiKeyNotifier')
          .last;
      expect(
        deepseekSection,
        contains('ref.invalidateSelf()'),
        reason:
            'DeepSeek setApiKey muss ref.invalidateSelf() aufrufen (kein manuelles state=)',
      );
    });

    test(
        'AC-1b: setApiKey (DeepSeek) enthält kein state = AsyncData(key) mehr', () {
      final deepseekSection = aiProviderSource
          .split('class DeepSeekApiKeyNotifier')
          .last;
      expect(
        deepseekSection,
        isNot(contains('state = AsyncData(')),
        reason: 'DeepSeek: kein manuelles state = AsyncData() in setApiKey',
      );
    });

    test('AC-1c: setApiKey (DeepSeek) enthält await future', () {
      final deepseekSection = aiProviderSource
          .split('class DeepSeekApiKeyNotifier')
          .last;
      expect(
        deepseekSection,
        contains('await future'),
        reason: 'DeepSeek: await future stellt sofortige Nutzbarkeit sicher',
      );
    });

    test('AC-2: build() (DeepSeek) enthält iOS first_unlock Retry-Logik', () {
      final deepseekBuildSection = aiProviderSource
          .split('class DeepSeekApiKeyNotifier')
          .last;
      expect(
        deepseekBuildSection,
        contains('Duration(milliseconds: 50)'),
        reason: 'DeepSeek: iOS first_unlock Retry nach 50ms muss vorhanden sein',
      );
    });

    test('AC-3: clearApiKey (DeepSeek) nutzt ref.invalidateSelf() + await future', () {
      final deepseekSection = aiProviderSource
          .split('class DeepSeekApiKeyNotifier')
          .last;
      final clearSection =
          deepseekSection.split('Future<void> clearApiKey').last.split('}').first;
      expect(
        clearSection,
        contains('ref.invalidateSelf()'),
        reason: 'DeepSeek clearApiKey muss ref.invalidateSelf() nutzen',
      );
      expect(
        clearSection,
        contains('await future'),
        reason: 'DeepSeek clearApiKey muss await future nutzen',
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Gruppe 3: aiServiceProvider – Rebuild-Sicherheit
  // ─────────────────────────────────────────────────────────────────────────
  group('aiServiceProvider – Rebuild-Verhalten', () {
    test(
        'AC-5a: aiServiceProvider beobachtet apiKeyProvider via ref.watch '
        '→ Auto-Rebuild nach Key-Änderung', () {
      // ref.watch(apiKeyProvider) muss im aiServiceProvider vorkommen
      final serviceSection = aiProviderSource
          .split('final aiServiceProvider')
          .last;
      expect(
        serviceSection,
        contains('ref.watch(apiKeyProvider)'),
        reason:
            'aiServiceProvider muss apiKeyProvider per ref.watch beobachten, nicht ref.read',
      );
    });

    test(
        'AC-5b: aiServiceProvider beobachtet deepseekApiKeyProvider via ref.watch '
        '→ Auto-Rebuild nach DeepSeek-Key-Änderung', () {
      final serviceSection = aiProviderSource
          .split('final aiServiceProvider')
          .last;
      expect(
        serviceSection,
        contains('ref.watch(deepseekApiKeyProvider)'),
        reason:
            'aiServiceProvider muss deepseekApiKeyProvider per ref.watch beobachten',
      );
    });

    test(
        'AC-5c: aiServiceProvider ist KEIN autoDispose '
        '(Screens nutzen nur ref.read in Callbacks)', () {
      final serviceSection = aiProviderSource
          .split('final aiServiceProvider')
          .last
          .split(';')
          .first;
      expect(
        serviceSection,
        isNot(contains('autoDispose')),
        reason:
            'aiServiceProvider darf NICHT autoDispose sein – '
            'Screens nutzen nur ref.read in Callbacks, kein dauerhafter Subscriber',
      );
    });

    test(
        'AC-5d: aiServiceProvider gibt null zurück wenn kein Key vorhanden '
        '→ kein Crash beim ersten Start', () {
      final serviceSection = aiProviderSource
          .split('final aiServiceProvider')
          .last;
      expect(
        serviceSection,
        contains('return key != null'),
        reason:
            'aiServiceProvider muss null zurückgeben wenn Key fehlt (kein Crash)',
      );
    });

    test('AC-5e: aiServiceProvider gibt null zurück wenn kein Key vorhanden '
        '(null-Pfad via ternary)', () {
      // Überprüft konkret das "? ... : null" Pattern im Provider
      final serviceSection = aiProviderSource
          .split('final aiServiceProvider')
          .last;
      expect(
        serviceSection,
        contains(': null'),
        reason:
            'aiServiceProvider muss null zurückgeben wenn kein Key vorhanden ist',
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Gruppe 4: SelectedAIProviderNotifier – Out-of-Scope-Check
  // ─────────────────────────────────────────────────────────────────────────
  group('SelectedAIProviderNotifier – Nicht-Regression', () {
    test(
        'Nicht-Regression: SelectedAIProviderNotifier.setProvider nutzt '
        'state = AsyncData() (SharedPrefs, keine Race möglich → bewusst so)', () {
      final providerSection = aiProviderSource
          .split('class SelectedAIProviderNotifier')
          .last
          .split('class DeepSeekApiKeyNotifier')
          .first;
      // Das alte Pattern ist hier ERLAUBT (SharedPreferences, kein Migration-await,
      // keine Race-Condition). Prüfen dass es noch so ist (keine unbeabsichtigte Änderung).
      expect(
        providerSection,
        contains('state = AsyncData('),
        reason:
            'SelectedAIProviderNotifier.setProvider darf state = AsyncData() behalten '
            '– keine Race möglich bei SharedPreferences-Reads',
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Gruppe 5: Strukturelle Vollständigkeitsprüfung
  // ─────────────────────────────────────────────────────────────────────────
  group('Strukturelle Vollständigkeit', () {
    test('api_key_provider.dart enthält ApiKeyNotifier', () {
      expect(apiKeySource, contains('class ApiKeyNotifier'));
    });

    test('api_key_provider.dart exportiert apiKeyProvider als AsyncNotifierProvider', () {
      expect(
        apiKeySource,
        contains('AsyncNotifierProvider<ApiKeyNotifier, String?>'),
      );
    });

    test('ai_provider.dart enthält DeepSeekApiKeyNotifier', () {
      expect(aiProviderSource, contains('class DeepSeekApiKeyNotifier'));
    });

    test('ai_provider.dart exportiert deepseekApiKeyProvider als AsyncNotifierProvider', () {
      expect(
        aiProviderSource,
        contains('AsyncNotifierProvider<DeepSeekApiKeyNotifier, String?>'),
      );
    });

    test('aiServiceProvider ist als Provider<AIService?> deklariert', () {
      expect(
        aiProviderSource,
        contains('Provider<AIService?>'),
      );
    });
  });
}
