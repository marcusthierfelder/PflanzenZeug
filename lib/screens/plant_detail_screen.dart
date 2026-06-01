import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../models/capture_context_tag.dart';
import '../models/care_schedule.dart';
import '../models/diagnosis/diagnosis_entry.dart';
import '../models/diagnosis/diagnosis_result.dart';
import '../models/plant.dart';
import '../models/plant_photo.dart';
import '../providers/ai_provider.dart';
import '../providers/database_provider.dart';

import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../widgets/camera_picker_helper.dart';
import '../widgets/photo_carousel.dart';
import '../widgets/care_section.dart';
import 'diagnosis_history_detail_screen.dart';
import 'diagnosis_screen.dart';
import 'identification_screen.dart' show IdentificationScreen, PlantCareProfileView;
import 'chat_screen.dart';

class PlantDetailScreen extends ConsumerStatefulWidget {
  final String plantId;
  const PlantDetailScreen({super.key, required this.plantId});

  @override
  ConsumerState<PlantDetailScreen> createState() => _PlantDetailScreenState();
}

class _PlantDetailScreenState extends ConsumerState<PlantDetailScreen> {
  final _picker = ImagePicker();

  /// Letzter aktiver Kontext-Tag aus dem Kamera-Flow (für Diagnose-Weitergabe).
  CaptureContextTag? _lastContextTag;

  /// Zeigt ein Modal-Bottom-Sheet zur Auswahl der Bildquelle (Kamera oder Galerie).
  /// Kamera: einzelnes Foto via [ImageSource.camera].
  /// Galerie: mehrere Fotos via [pickMultiImage].
  Future<void> _addPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag-Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Foto hinzufügen',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Kamera'),
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galerie'),
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return; // Nutzer hat abgebrochen
    if (!mounted) return;

    List<File> selectedFiles;

    if (source == ImageSource.camera) {
      // Burst-Kamera: mehrere Fotos + optionaler Kontext-Tag
      final capture = await openBurstCamera(context); // ignore: use_build_context_synchronously
      if (capture == null || capture.photos.isEmpty || !mounted) return;
      selectedFiles = capture.photos;
      if (capture.contextTag != null) {
        setState(() => _lastContextTag = capture.contextTag);
      }
    } else {
      final picked = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (picked.isEmpty) return;
      selectedFiles = picked.map((x) => File(x.path)).toList();
    }

    final db = DatabaseService.instance;
    for (final file in selectedFiles) {
      final persisted = await db.persistImage(file);
      await db.savePhoto(PlantPhoto(
        id: db.generateId(),
        plantId: widget.plantId,
        filePath: persisted,
        takenAt: DateTime.now(),
        purpose: 'progress',
        contextTag: _lastContextTag,
      ));
    }
    ref.invalidate(plantPhotosProvider(widget.plantId));
  }

  void _startDiagnosis() {
    final plant = ref.read(plantProvider(widget.plantId));
    final photos = ref.read(plantPhotosProvider(widget.plantId));
    if (plant == null || photos.isEmpty) return;

    // Neuestes Foto mit Tag bevorzugen, sonst _lastContextTag nutzen
    final latestTaggedPhoto = photos.firstWhere(
      (p) => p.contextTag != null,
      orElse: () => photos.first,
    );
    final contextTag = latestTaggedPhoto.contextTag ?? _lastContextTag;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DiagnosisScreen(
          images: photos
              .map((p) => File(
                  DatabaseService.instance.resolveImagePath(p.filePath)))
              .toList(),
          plantName: plant.speciesName ?? plant.nickname,
          plantId: widget.plantId,
          contextTag: contextTag,
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
    final diagnosisHistory = ref.watch(diagnosisHistoryProvider(widget.plantId));

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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'delete') {
                _confirmDeletePlant(context, plant);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Löschen',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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

                  // Pflege-Profil (strukturiertes Karten-Layout oder Markdown-Fallback)
                  if (plant.careProfileJson != null ||
                      plant.identificationResult != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Pflege-Tipps',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    PlantCareProfileView(
                      plant: plant,
                      theme: Theme.of(context),
                    ),
                  ],

                  // Diagnose-Verlauf (neue strukturierte Historie)
                  if (diagnosisHistory.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    DiagnosisHistorySection(
                      history: diagnosisHistory,
                      onEntryTap: (entry) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DiagnosisHistoryDetailScreen(entry: entry),
                          ),
                        );
                      },
                    ),
                  ] else if (plant.diagnosisResult != null) ...[
                    // Legacy-Fallback für Altdaten ohne strukturierte Historie
                    const SizedBox(height: 8),
                    _DiagnosisCard(diagnosis: plant.diagnosisResult!),
                  ],

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

  Future<void> _confirmDeletePlant(BuildContext context, Plant plant) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Theme.of(ctx).colorScheme.error,
          size: 32,
        ),
        title: const Text('Pflanze löschen?'),
        content: const Text(
          'Pflanze inkl. aller Fotos, Chat-Verläufe und Erinnerungen wird endgültig gelöscht.\n\n'
          'Diese Aktion kann nicht rückgängig gemacht werden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Endgültig löschen'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await DatabaseService.instance.deletePlant(plant.id);
    // Notifications neu planen – gelöschte Schedules werden nicht mehr berücksichtigt
    await NotificationService.instance.scheduleAllCareReminders();
    ref.invalidate(plantsProvider);

    if (mounted) {
      // ignore: use_build_context_synchronously
      Navigator.pop(context);
    }
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

// ─────────────────────────────────────────────────────────────────────────────
// Diagnose-Verlauf Abschnitt
// ─────────────────────────────────────────────────────────────────────────────

/// Abschnitt "Diagnose-Verlauf" im PlantDetailScreen.
///
/// Zeigt alle Diagnose-Einträge als kompakte Liste (neueste zuerst) mit
/// Datum, Health-Badge, kurzer Summary und Mini-Thumbnail.
class DiagnosisHistorySection extends StatelessWidget {
  final List<DiagnosisEntry> history;
  final void Function(DiagnosisEntry entry) onEntryTap;

  const DiagnosisHistorySection({
    super.key,
    required this.history,
    required this.onEntryTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.history,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Diagnose-Verlauf',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Text(
              '${history.length} Einträge',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...history.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _DiagnosisHistoryTile(
              entry: entry,
              onTap: () => onEntryTap(entry),
            ),
          ),
        ),
      ],
    );
  }
}

/// Einzelne Kachel im Diagnose-Verlauf.
class _DiagnosisHistoryTile extends StatelessWidget {
  final DiagnosisEntry entry;
  final VoidCallback onTap;

  const _DiagnosisHistoryTile({
    required this.entry,
    required this.onTap,
  });

  static Color _healthColor(OverallHealth health, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return switch (health) {
      OverallHealth.good => isDark ? const Color(0xFF81C784) : const Color(0xFF388E3C),
      OverallHealth.fair => isDark ? const Color(0xFF64B5F6) : const Color(0xFF1976D2),
      OverallHealth.poor => isDark ? const Color(0xFFFFB74D) : const Color(0xFFF57C00),
      OverallHealth.critical => isDark ? const Color(0xFFEF5350) : const Color(0xFFD32F2F),
    };
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun',
      'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez',
    ];
    return '${dt.day}. ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final color = _healthColor(entry.overallHealth, brightness);
    final db = DatabaseService.instance;

    // Erstes verfügbares Foto als Thumbnail
    File? thumbFile;
    for (final path in entry.photoPaths) {
      final f = File(db.resolveImagePath(path));
      if (f.existsSync()) {
        thumbFile = f;
        break;
      }
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: thumbFile != null
                    ? Image.file(
                        thumbFile,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 52,
                        height: 52,
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          size: 24,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
              ),

              const SizedBox(width: 12),

              // Inhalt
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Datum + Health-Badge
                    Row(
                      children: [
                        Text(
                          _formatDate(entry.createdAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        _HealthChip(health: entry.overallHealth, color: color),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Summary
                    Text(
                      entry.summary,
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kleines farbiges Health-Chip.
class _HealthChip extends StatelessWidget {
  final OverallHealth health;
  final Color color;

  const _HealthChip({required this.health, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Text(
        health.label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Legacy _DiagnosisCard (Fallback für Altdaten)
// ─────────────────────────────────────────────────────────────────────────────

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
