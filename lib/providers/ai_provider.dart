import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ai_service.dart';
import '../services/claude_service.dart';
import '../services/deepseek_service.dart';
import 'api_key_provider.dart';

enum AIProvider { claude, deepseek }

const _providerKey = 'ai_provider';
const _deepseekKeyKey = 'deepseek_api_key';

const _secureStorage = FlutterSecureStorage(
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
);

// --- Provider-Auswahl ---

final selectedAIProviderProvider =
    AsyncNotifierProvider<SelectedAIProviderNotifier, AIProvider>(
        SelectedAIProviderNotifier.new);

class SelectedAIProviderNotifier extends AsyncNotifier<AIProvider> {
  @override
  Future<AIProvider> build() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_providerKey) ?? 'claude';
    return value == 'deepseek' ? AIProvider.deepseek : AIProvider.claude;
  }

  Future<void> setProvider(AIProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_providerKey, provider.name);
    state = AsyncData(provider);
  }
}

// --- DeepSeek API Key ---

final deepseekApiKeyProvider =
    AsyncNotifierProvider<DeepSeekApiKeyNotifier, String?>(
        DeepSeekApiKeyNotifier.new);

class DeepSeekApiKeyNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    // Primärer Read
    String? key = await _secureStorage.read(key: _deepseekKeyKey);

    // iOS-Keychain `first_unlock` Workaround: Einmaliger Retry nach 50 ms,
    // falls der erste Read direkt nach einem Write noch null liefert.
    if (key == null) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      key = await _secureStorage.read(key: _deepseekKeyKey);
    }

    return key;
  }

  Future<void> setApiKey(String key) async {
    await _secureStorage.write(key: _deepseekKeyKey, value: key);
    // ref.invalidateSelf() verhindert die Race-Condition: Kein spät
    // resolvendes build()-Future kann den neuen Key mehr überschreiben.
    ref.invalidateSelf();
    // Warten bis der Re-Build abgeschlossen ist → Key sofort nutzbar.
    await future;
  }

  Future<void> clearApiKey() async {
    await _secureStorage.delete(key: _deepseekKeyKey);
    ref.invalidateSelf();
    await future;
  }
}

// --- Aktiver AI-Service ---

// aiServiceProvider beobachtet apiKeyProvider und deepseekApiKeyProvider via
// ref.watch. Sobald invalidateSelf() dort einen Re-Build auslöst und der neue
// AsyncData-State verfügbar ist, rebuildet dieser Provider automatisch mit dem
// aktuellen Key → frischer ClaudeService / DeepSeekService ohne App-Restart.
// KEIN autoDispose: Die Screens lesen den Provider via ref.read in Callbacks;
// autoDispose würde den Provider nach jedem Read sofort wieder disposen, da
// keine dauerhaften Listener existieren.
final aiServiceProvider = Provider<AIService?>((ref) {
  final selected = ref.watch(selectedAIProviderProvider).value;
  switch (selected) {
    case AIProvider.deepseek:
      final key = ref.watch(deepseekApiKeyProvider).value;
      return key != null ? DeepSeekService(key) : null;
    case AIProvider.claude:
    case null:
      final key = ref.watch(apiKeyProvider).value;
      return key != null ? ClaudeService(key) : null;
  }
});
