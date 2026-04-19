import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../models/care_schedule.dart';
import '../models/plant_photo.dart';
import '../providers/api_key_provider.dart';
import '../providers/database_provider.dart';
import '../services/claude_service.dart';
import '../services/database_service.dart';
import 'diagnosis_screen.dart';
import 'chat_screen.dart';

class PlantDetailScreen extends ConsumerStatefulWidget {
  final String plantId;
  const PlantDetailScreen({super.key, required this.plantId});

  @override
  ConsumerState<PlantDetailScreen> createState() => _PlantDetailScreenState();
}

class _PlantDetailScreenState extends ConsumerState<PlantDetailScreen> {
  final _picker = ImagePicker();

  Future<void> _addPhoto() async {
    final photos = await _picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (photos.isEmpty) return;

    final db = DatabaseService.instance;
    for (final xfile in photos) {
      final persisted = await db.persistImage(File(xfile.path));
      await db.savePhoto(PlantPhoto(
        id: db.generateId(),
        plantId: widget.plantId,
        filePath: persisted,
        takenAt: DateTime.now(),
        purpose: 'progress',
      ));
    }
    ref.invalidate(plantPhotosProvider(widget.plantId));
    setState(() {});
  }

  void _startDiagnosis() {
    final plant = ref.read(plantProvider(widget.plantId));
    final photos = ref.read(plantPhotosProvider(widget.plantId));
    if (plant == null || photos.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DiagnosisScreen(
          images: photos.map((p) => File(p.filePath)).toList(),
          plantName: plant.speciesName ?? plant.nickname,
          plantId: widget.plantId,
        ),
      ),
    );
  }

  void _openChat() {
    final plant = ref.read(plantProvider(widget.plantId));
    if (plant == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          images: const [],
          plantName: plant.speciesName ?? plant.nickname,
          diagnosis: plant.diagnosisResult ?? '',
          plantId: widget.plantId,
        ),
      ),
    );
  }

  Future<void> _generateCareSchedule() async {
    final plant = ref.read(plantProvider(widget.plantId));
    if (plant == null) return;

    final apiKey = ref.read(apiKeyProvider).value;
    if (apiKey == null) return;

    final service = ClaudeService(apiKey);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pflege-Plan wird erstellt...')),
    );

    try {
      final response = await service.suggestCareSchedule(
        plantName: plant.speciesName ?? plant.nickname,
        identificationResult: plant.identificationResult,
        diagnosisResult: plant.diagnosisResult,
      );

      // Try to parse JSON from response
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
      if (jsonMatch == null) throw Exception('Kein JSON in Antwort');

      final data = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
      final db = DatabaseService.instance;
      final now = DateTime.now();

      if (data['watering_interval_days'] != null) {
        await db.saveCareSchedule(CareSchedule(
          id: db.generateId(),
          plantId: widget.plantId,
          type: 'watering',
          intervalDays: data['watering_interval_days'] as int,
          lastDone: now,
          notes: data['notes'] as String?,
        ));
      }
      if (data['fertilizing_interval_days'] != null) {
        await db.saveCareSchedule(CareSchedule(
          id: db.generateId(),
          plantId: widget.plantId,
          type: 'fertilizing',
          intervalDays: data['fertilizing_interval_days'] as int,
          lastDone: now,
          notes: data['notes'] as String?,
        ));
      }

      ref.invalidate(plantCareSchedulesProvider(widget.plantId));
      setState(() {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pflege-Plan erstellt!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final plant = ref.watch(plantProvider(widget.plantId));
    final photos = ref.watch(plantPhotosProvider(widget.plantId));
    final careSchedules = ref.watch(plantCareSchedulesProvider(widget.plantId));
    final theme = Theme.of(context);

    if (plant == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Pflanze nicht gefunden')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(plant.nickname),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _editPlant(context, plant),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Photo carousel
            if (photos.isNotEmpty)
              SizedBox(
                height: 200,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(12),
                  itemCount: photos.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, index) {
                    final photo = photos[index];
                    return Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(photo.filePath),
                              width: 160,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${photo.takenAt.day}.${photo.takenAt.month}.${photo.takenAt.year}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    );
                  },
                ),
              ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Info card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (plant.speciesName != null) ...[
                            Text(plant.speciesName!,
                                style: theme.textTheme.titleMedium),
                            if (plant.scientificName != null)
                              Text(
                                plant.scientificName!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontStyle: FontStyle.italic,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            const SizedBox(height: 8),
                          ],
                          if (plant.location.isNotEmpty)
                            Row(
                              children: [
                                Icon(Icons.location_on,
                                    size: 16,
                                    color: theme.colorScheme.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Text(plant.location,
                                    style: theme.textTheme.bodyMedium),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Last diagnosis
                  if (plant.diagnosisResult != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.medical_services,
                                    size: 20,
                                    color: theme.colorScheme.primary),
                                const SizedBox(width: 8),
                                Text('Letzte Diagnose',
                                    style: theme.textTheme.titleSmall),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              plant.diagnosisResult!,
                              style: theme.textTheme.bodySmall,
                              maxLines: 6,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Action buttons
                  OutlinedButton.icon(
                    onPressed: _addPhoto,
                    icon: const Icon(Icons.add_a_photo),
                    label: const Text('Foto hinzufügen'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: photos.isNotEmpty ? _startDiagnosis : null,
                    icon: const Icon(Icons.medical_services),
                    label: const Text('Neue Diagnose'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _openChat,
                    icon: const Icon(Icons.chat),
                    label: const Text('Chat'),
                  ),

                  const SizedBox(height: 24),

                  // Care schedules section
                  if (careSchedules.isNotEmpty) ...[
                    Text('Pflege-Plan',
                        style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    ...careSchedules.map((care) {
                      final isOverdue = care.isOverdue;
                      final daysUntil =
                          care.nextDue.difference(DateTime.now()).inDays;
                      return Card(
                        color: isOverdue
                            ? theme.colorScheme.errorContainer
                            : null,
                        child: ListTile(
                          leading: Icon(
                            care.type == 'watering'
                                ? Icons.water_drop
                                : Icons.science,
                            color: care.type == 'watering'
                                ? Colors.blue
                                : Colors.orange,
                          ),
                          title: Text(care.type == 'watering'
                              ? 'Gießen'
                              : 'Düngen'),
                          subtitle: Text(isOverdue
                              ? '${-daysUntil} Tag${daysUntil == -1 ? '' : 'e'} überfällig'
                              : 'in $daysUntil Tag${daysUntil == 1 ? '' : 'en'} (alle ${care.intervalDays} Tage)'),
                          trailing: IconButton(
                            icon: const Icon(Icons.check_circle_outline),
                            onPressed: () async {
                              care.lastDone = DateTime.now();
                              await DatabaseService.instance
                                  .saveCareSchedule(care);
                              ref.invalidate(
                                  plantCareSchedulesProvider(widget.plantId));
                              setState(() {});
                            },
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                  ],

                  OutlinedButton.icon(
                    onPressed: _generateCareSchedule,
                    icon: const Icon(Icons.schedule),
                    label: Text(careSchedules.isEmpty
                        ? 'Pflege-Plan erstellen'
                        : 'Pflege-Plan neu erstellen'),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _editPlant(BuildContext context, plant) {
    final nicknameCtrl = TextEditingController(text: plant.nickname);
    final locationCtrl = TextEditingController(text: plant.location);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pflanze bearbeiten'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nicknameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: locationCtrl,
              decoration: const InputDecoration(
                labelText: 'Standort',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () async {
              plant.nickname = nicknameCtrl.text.trim();
              plant.location = locationCtrl.text.trim();
              plant.updatedAt = DateTime.now();
              await DatabaseService.instance.savePlant(plant);
              ref.invalidate(plantProvider(widget.plantId));
              ref.invalidate(plantsProvider);
              if (context.mounted) Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }
}
