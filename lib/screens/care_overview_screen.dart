import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/care_provider.dart';
import '../providers/database_provider.dart';
import '../services/database_service.dart';

class CareOverviewScreen extends ConsumerWidget {
  const CareOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overdue = ref.watch(overdueCaresProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Pflege')),
      body: overdue.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 80,
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Alles erledigt!',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Keine Pflege-Aufgaben fällig.\nPflege-Pläne werden pro Pflanze erstellt.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: overdue.length,
              itemBuilder: (context, index) {
                final care = overdue[index];
                final plant = ref.watch(plantProvider(care.plantId));
                final daysOverdue =
                    DateTime.now().difference(care.nextDue).inDays;

                return Card(
                  child: ListTile(
                    leading: Icon(
                      care.type == 'watering'
                          ? Icons.water_drop
                          : Icons.science,
                      color: care.type == 'watering'
                          ? Colors.blue
                          : Colors.orange,
                    ),
                    title: Text(plant?.nickname ?? 'Unbekannt'),
                    subtitle: Text(
                      '${care.type == 'watering' ? 'Gießen' : 'Düngen'} '
                      '— $daysOverdue Tag${daysOverdue == 1 ? '' : 'e'} überfällig',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.check),
                      onPressed: () async {
                        care.lastDone = DateTime.now();
                        await DatabaseService.instance.saveCareSchedule(care);
                        ref.invalidate(overdueCaresProvider);
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
