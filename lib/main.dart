import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/api_key_wizard_screen.dart';
import 'screens/plant_collection_screen.dart';
import 'providers/api_key_provider.dart';
import 'services/database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.instance.init();
  runApp(const ProviderScope(child: PflanzenZeugApp()));
}

class PflanzenZeugApp extends ConsumerWidget {
  const PflanzenZeugApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apiKey = ref.watch(apiKeyProvider);

    return MaterialApp(
      title: 'PflanzenZeug',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.green,
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.green,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: apiKey.when(
        data: (key) =>
            key == null
                ? const ApiKeyWizardScreen()
                : const PlantCollectionScreen(),
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => const ApiKeyWizardScreen(),
      ),
    );
  }
}
