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
    return _secureStorage.read(key: _apiKeyKey);
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
    state = AsyncData(key);
  }

  Future<void> clearApiKey() async {
    await _secureStorage.delete(key: _apiKeyKey);
    state = const AsyncData(null);
  }
}
