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
    return _secureStorage.read(key: _deepseekKeyKey);
  }

  Future<void> setApiKey(String key) async {
    await _secureStorage.write(key: _deepseekKeyKey, value: key);
    state = AsyncData(key);
  }

  Future<void> clearApiKey() async {
    await _secureStorage.delete(key: _deepseekKeyKey);
    state = const AsyncData(null);
  }
}

// --- Aktiver AI-Service ---

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
