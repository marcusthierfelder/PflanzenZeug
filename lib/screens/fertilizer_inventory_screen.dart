import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/fertilizer_provider.dart';
import '../services/database_service.dart';
import 'add_fertilizer_screen.dart';

class FertilizerInventoryScreen extends ConsumerWidget {
  const FertilizerInventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fertilizers = ref.watch(fertilizersProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Meine Dünger')),
      body: fertilizers.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.science_outlined,
                      size: 80,
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Keine Dünger gespeichert',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Fotografiere deine Dünger,\ndamit sie bei Empfehlungen\nvorgeschlagen werden.',
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
              itemCount: fertilizers.length,
              itemBuilder: (context, index) {
                final fert = fertilizers[index];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: fert.photoPath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.file(
                              File(fert.photoPath!),
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(Icons.science),
                    title: Text(fert.name),
                    subtitle: Text([
                      if (fert.brand != null) fert.brand!,
                      if (fert.npkRatio != null) 'NPK: ${fert.npkRatio!}',
                    ].join(' — ')),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await DatabaseService.instance
                            .deleteFertilizer(fert.id);
                        ref.invalidate(fertilizersProvider);
                      },
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddFertilizerScreen()),
          );
          ref.invalidate(fertilizersProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('Dünger hinzufügen'),
      ),
    );
  }
}
