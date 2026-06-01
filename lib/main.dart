import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/api_key_wizard_screen.dart';
import 'screens/plant_collection_screen.dart';
import 'providers/first_launch_provider.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.instance.init();
  await DatabaseService.instance.restoreFromKeychainIfEmpty();
  await NotificationService.instance.init();
  await NotificationService.instance.requestPermissions();
  await NotificationService.instance.scheduleAllCareReminders();
  runApp(const ProviderScope(child: PflanzenwartApp()));
}

class PflanzenwartApp extends ConsumerWidget {
  const PflanzenwartApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Pflanzenwart Pro',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('de')],
      locale: const Locale('de'),
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
      home: ref.watch(firstLaunchProvider).when(
        data: (isFirst) =>
            isFirst ? const ApiKeyWizardScreen() : const PlantCollectionScreen(),
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (_, _) => const PlantCollectionScreen(),
      ),
    );
  }
}
