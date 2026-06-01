import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _apiKeyKey = 'claude_api_key';

const _secureStorage = FlutterSecureStorage(
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
);

final apiKeyProvider =
    AsyncNotifierProvider<ApiKeyNotifier, String?>(ApiKeyNotifier.new);

class ApiKeyNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    // Migration: SharedPreferences → Keychain (einmalig)
    await _migrateFromSharedPreferences();

    // Primärer Read
    String? key = await _secureStorage.read(key: _apiKeyKey);

    // iOS-Keychain `first_unlock` Workaround:
    // Nach einem frischen Write kann der erste Read auf iOS kurz `null`
    // liefern, bevor das Keychain-Item vollständig verfügbar ist.
    // Ein einmaliger kurzer Retry reicht aus.
    if (key == null) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      key = await _secureStorage.read(key: _apiKeyKey);
    }

    return key;
  }

  Future<void> _migrateFromSharedPreferences() async {
    final existing = await _secureStorage.read(key: _apiKeyKey);
    if (existing != null) return; // Bereits in Keychain

    final prefs = await SharedPreferences.getInstance();
    final oldKey = prefs.getString(_apiKeyKey);
    if (oldKey != null) {
      await _secureStorage.write(key: _apiKeyKey, value: oldKey);
      await prefs.remove(_apiKeyKey);
    }
  }

  Future<void> setApiKey(String key) async {
    await _secureStorage.write(key: _apiKeyKey, value: key);
    // ref.invalidateSelf() statt manuelles `state = AsyncData(key)`:
    // Verhindert die Race-Condition, bei der ein noch laufendes build()-Future
    // den manuell gesetzten State nachträglich mit einem veralteten/null-Wert
    // überschreiben würde. Der Re-Build liest den soeben geschriebenen Key
    // zuverlässig aus dem Keychain (mit Retry-Fallback oben).
    ref.invalidateSelf();
    // Auf den neuen State warten, damit der Caller sicher ist, dass der Key
    // bereits verfügbar ist, wenn er z.B. direkt danach eine KI-Aktion startet.
    await future;
  }

  Future<void> clearApiKey() async {
    await _secureStorage.delete(key: _apiKeyKey);
    // Auch hier invalidateSelf für Konsistenz und sauberen Re-Build
    ref.invalidateSelf();
    await future;
  }
}
