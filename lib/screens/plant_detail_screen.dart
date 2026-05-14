import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../models/care_schedule.dart';
import '../models/plant.dart';
import '../models/plant_photo.dart';
import '../providers/ai_provider.dart';
import '../providers/database_provider.dart';

import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../widgets/photo_carousel.dart';
import '../widgets/care_section.dart';
import 'diagnosis_screen.dart';
import 'identification_screen.dart';
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
  }

  void _startDiagnosis() {
    final plant = ref.read(plantProvider(widget.plantId));
    final photos = ref.read(plantPhotosProvider(widget.plantId));
    if (plant == null || photos.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DiagnosisScreen(
          images: photos.map((p) => File(DatabaseService.instance.resolveImagePath(p.filePath))).toList(),
          plantName: plant.speciesName ?? plant.nickname,
          plantId: widget.plantId,
        ),
      ),
    );
  }

  void _startReIdentification() {
    final plant = ref.read(plantProvider(widget.plantId));
    final photos = ref.read(plantPhotosProvider(widget.plantId));
    if (plant == null || photos.isEmpty) return;

    final identificationPhotos = photos.where((p) => p.purpose == 'identification').toList();
    final photosToUse = identificationPhotos.isNotEmpty ? identificationPhotos : photos;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => IdentificationScreen(
          images: photosToUse
              .map((p) => File(DatabaseService.instance.resolveImagePath(p.filePath)))
              .toList(),
          isMixedPot: plant.isMixedPot,
          existingPlantId: widget.plantId,
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

    
    

    final service = ref.read(aiServiceProvider);
      if (service == null) throw Exception('Kein API Key konfiguriert. Bitte in den Einstellungen hinterlegen.');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pflege-Plan wird erstellt...')),
    );

    try {
      final response = await service.suggestCareSchedule(
        plantName: plant.speciesName ?? plant.nickname,
        identificationResult: plant.identificationResult,
        diagnosisResult: plant.diagnosisResult,
      );

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
      await NotificationService.instance.scheduleAllCareReminders();

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
            PhotoCarousel(plant: plant, photos: photos),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Info card
                  _PlantInfoCard(plant: plant),

                  const SizedBox(height: 8),

                  // Last diagnosis
                  if (plant.diagnosisResult != null)
                    _DiagnosisCard(diagnosis: plant.diagnosisResult!),

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
                  OutlinedButton.icon(
                    onPressed: photos.isNotEmpty ? _startReIdentification : null,
                    icon: const Icon(Icons.manage_search),
                    label: const Text('Neu bestimmen'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _openChat,
                    icon: const Icon(Icons.chat),
                    label: const Text('Chat'),
                  ),

                  const SizedBox(height: 24),

                  CareSection(
                    plantId: widget.plantId,
                    careSchedules: careSchedules,
                    onGeneratePlan: _generateCareSchedule,
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
    final potCtrl = TextEditingController(text: plant.potInfo);
    bool isMixedPot = plant.isMixedPot;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Pflanze bearbeiten'),
          content: SingleChildScrollView(
            child: Column(
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
                    hintText: 'z.B. Wohnzimmer, Balkon',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: potCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Topf',
                    hintText: 'z.B. Terrakotta 20cm',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mischtopf'),
                  subtitle: const Text(
                    'Mehrere Pflanzen in einem Topf',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: isMixedPot,
                  onChanged: (v) => setLocalState(() => isMixedPot = v),
                ),
              ],
            ),
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
                plant.potInfo = potCtrl.text.trim();
                plant.isMixedPot = isMixedPot;
                plant.updatedAt = DateTime.now();
                await DatabaseService.instance.savePlant(plant);
                ref.invalidate(plantProvider(widget.plantId));
                ref.invalidate(plantsProvider);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlantInfoCard extends StatelessWidget {
  final Plant plant;
  const _PlantInfoCard({required this.plant});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (plant.speciesName != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(plant.speciesName!, style: theme.textTheme.titleMedium),
                  ),
                  if (plant.identificationConfidence != null) ...[
                    const SizedBox(width: 8),
                    _ConfidenceBadge(confidence: plant.identificationConfidence!.round()),
                  ],
                ],
              ),
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
              _InfoRow(Icons.location_on, plant.location),
            if (plant.potInfo.isNotEmpty) ...[
              const SizedBox(height: 4),
              _InfoRow(Icons.yard, plant.potInfo),
            ],
            if (plant.isMixedPot) ...[
              const SizedBox(height: 4),
              _InfoRow(Icons.diversity_3, 'Mischtopf (mehrere Arten)'),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(text, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  final int confidence;
  const _ConfidenceBadge({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final color = confidence >= 80
        ? Colors.green
        : confidence >= 60
            ? Colors.orange
            : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            '$confidence%',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _DiagnosisCard extends StatelessWidget {
  final String diagnosis;
  const _DiagnosisCard({required this.diagnosis});

  void _showFull(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.medical_services,
                      size: 20, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('Letzte Diagnose',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  diagnosis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showFull(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.medical_services,
                      size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('Letzte Diagnose', style: theme.textTheme.titleSmall),
                  const Spacer(),
                  Icon(Icons.chevron_right,
                      size: 18, color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                diagnosis,
                style: theme.textTheme.bodySmall,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
