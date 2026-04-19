import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/care_schedule.dart';
import '../providers/database_provider.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class CareSection extends ConsumerWidget {
  final String plantId;
  final List<CareSchedule> careSchedules;
  final VoidCallback onGeneratePlan;

  const CareSection({
    super.key,
    required this.plantId,
    required this.careSchedules,
    required this.onGeneratePlan,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (careSchedules.isNotEmpty) ...[
          Text('Pflege-Plan', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          ...careSchedules.map((care) {
            final isOverdue = care.isOverdue;
            final daysUntil = care.nextDue.difference(DateTime.now()).inDays;
            return Card(
              color: isOverdue ? theme.colorScheme.errorContainer : null,
              child: ListTile(
                leading: Icon(
                  care.type == 'watering' ? Icons.water_drop : Icons.science,
                  color:
                      care.type == 'watering' ? Colors.blue : Colors.orange,
                ),
                title: Text(
                    care.type == 'watering' ? 'Gießen' : 'Düngen'),
                subtitle: Text(isOverdue
                    ? '${-daysUntil} Tag${daysUntil == -1 ? '' : 'e'} überfällig'
                    : 'in $daysUntil Tag${daysUntil == 1 ? '' : 'en'} (alle ${care.intervalDays} Tage)'),
                trailing: IconButton(
                  icon: const Icon(Icons.check_circle_outline),
                  onPressed: () async {
                    care.lastDone = DateTime.now();
                    await DatabaseService.instance.saveCareSchedule(care);
                    ref.invalidate(plantCareSchedulesProvider(plantId));
                    await NotificationService.instance
                        .scheduleAllCareReminders();
                  },
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          onPressed: onGeneratePlan,
          icon: const Icon(Icons.schedule),
          label: Text(careSchedules.isEmpty
              ? 'Pflege-Plan erstellen'
              : 'Pflege-Plan neu erstellen'),
        ),
      ],
    );
  }
}
