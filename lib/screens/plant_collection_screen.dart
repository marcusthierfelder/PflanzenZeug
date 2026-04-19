import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/database_provider.dart';
import '../models/plant.dart';
import '../models/plant_photo.dart';
import 'home_screen.dart';
import 'plant_detail_screen.dart';
import 'fertilizer_inventory_screen.dart';
import 'care_overview_screen.dart';
import 'status_wizard_screen.dart';

class PlantCollectionScreen extends ConsumerStatefulWidget {
  const PlantCollectionScreen({super.key});

  @override
  ConsumerState<PlantCollectionScreen> createState() =>
      _PlantCollectionScreenState();
}

class _PlantCollectionScreenState extends ConsumerState<PlantCollectionScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: switch (_tabIndex) {
        0 => const _PlantsTab(),
        1 => const CareOverviewScreen(),
        2 => const FertilizerInventoryScreen(),
        _ => const _PlantsTab(),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.eco_outlined),
            selectedIcon: Icon(Icons.eco),
            label: 'Pflanzen',
          ),
          NavigationDestination(
            icon: Icon(Icons.water_drop_outlined),
            selectedIcon: Icon(Icons.water_drop),
            label: 'Pflege',
          ),
          NavigationDestination(
            icon: Icon(Icons.science_outlined),
            selectedIcon: Icon(Icons.science),
            label: 'Dünger',
          ),
        ],
      ),
    );
  }
}

class _PlantsTab extends ConsumerWidget {
  const _PlantsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plants = ref.watch(plantsProvider);
    final theme = Theme.of(context);

    final pendingChecks = plants.where((p) {
      final lastCheck = p.lastCheckUp ?? p.createdAt;
      return DateTime.now().difference(lastCheck).inDays >= 7;
    }).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meine Pflanzen'),
        actions: [
          if (plants.isNotEmpty)
            IconButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const StatusWizardScreen()),
              ),
              icon: Badge(
                isLabelVisible: pendingChecks > 0,
                label: Text('$pendingChecks'),
                child: const Icon(Icons.fact_check_outlined),
              ),
              tooltip: 'Pflanzen-Check',
            ),
        ],
      ),
      body: plants.isEmpty ? _buildEmptyState(theme) : _buildGrid(plants),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Neue Pflanze'),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.eco_outlined,
              size: 80,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Noch keine Pflanzen',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tippe auf "+", um deine erste\nPflanze zu erkennen und zu speichern',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(List<Plant> plants) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemCount: plants.length,
      itemBuilder: (context, index) {
        return _PlantCard(plant: plants[index]);
      },
    );
  }
}

PlantPhoto _coverPhoto(Plant plant, List<PlantPhoto> photos) {
  if (plant.coverPhotoId != null) {
    final cover = photos.where((p) => p.id == plant.coverPhotoId).firstOrNull;
    if (cover != null) return cover;
  }
  return photos.first;
}

class _PlantCard extends ConsumerWidget {
  final Plant plant;
  const _PlantCard({required this.plant});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = ref.watch(plantPhotosProvider(plant.id))
        .where((p) => File(p.filePath).existsSync())
        .toList();
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PlantDetailScreen(plantId: plant.id),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: photos.isNotEmpty
                  ? Image.file(
                      File(_coverPhoto(plant, photos).filePath),
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.eco,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plant.nickname,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (plant.speciesName != null)
                    Text(
                      plant.speciesName!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
