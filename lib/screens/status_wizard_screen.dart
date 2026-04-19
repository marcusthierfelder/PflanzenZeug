import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../models/plant.dart';
import '../models/plant_photo.dart';
import '../providers/api_key_provider.dart';
import '../providers/database_provider.dart';
import '../providers/fertilizer_provider.dart';
import '../services/claude_service.dart';
import '../services/database_service.dart';

/// Status-Wizard: führt den User durch einen schnellen Check
/// für Pflanzen, die länger nicht geprüft wurden.
class StatusWizardScreen extends ConsumerStatefulWidget {
  const StatusWizardScreen({super.key});

  @override
  ConsumerState<StatusWizardScreen> createState() => _StatusWizardScreenState();
}

class _StatusWizardScreenState extends ConsumerState<StatusWizardScreen> {
  List<Plant> _pendingPlants = [];
  int _currentIndex = 0;
  final _picker = ImagePicker();

  // Wizard-Zustand pro Pflanze
  List<File> _photos = [];
  bool _analyzing = false;
  String? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPendingPlants();
  }

  void _loadPendingPlants() {
    final plants = ref.read(plantsProvider);
    final now = DateTime.now();
    // Pflanzen die seit >7 Tagen nicht gecheckt wurden
    _pendingPlants = plants.where((p) {
      final lastCheck = p.lastCheckUp ?? p.createdAt;
      return now.difference(lastCheck).inDays >= 7;
    }).toList()
      ..sort((a, b) {
        final aCheck = a.lastCheckUp ?? a.createdAt;
        final bCheck = b.lastCheckUp ?? b.createdAt;
        return aCheck.compareTo(bCheck); // Älteste zuerst
      });
  }

  Plant? get _currentPlant =>
      _currentIndex < _pendingPlants.length ? _pendingPlants[_currentIndex] : null;

  Future<void> _takePhoto() async {
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (photo != null) {
      setState(() => _photos.add(File(photo.path)));
    }
  }

  Future<void> _pickFromGallery() async {
    final photos = await _picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (photos.isNotEmpty) {
      setState(() => _photos.addAll(photos.map((p) => File(p.path))));
    }
  }

  Future<void> _runAnalysis() async {
    final plant = _currentPlant;
    if (plant == null || _photos.isEmpty) return;

    setState(() {
      _analyzing = true;
      _error = null;
    });

    try {
      final apiKey = ref.read(apiKeyProvider).value;
      if (apiKey == null) throw Exception('Kein API Key');

      final service = ClaudeService(apiKey);
      final fertilizers = ref.read(fertilizersProvider);
      final db = DatabaseService.instance;

      // Historische Fotos laden
      final existingPhotos = db.getPhotosForPlant(plant.id);
      final historicalImages = existingPhotos
          .take(3)
          .map((p) => File(p.filePath))
          .where((f) => f.existsSync())
          .toList();

      final result = await service.diagnosePlant(
        images: _photos,
        plantName: plant.speciesName ?? plant.nickname,
        location: plant.location,
        potInfo: plant.potInfo,
        previousDiagnosis: plant.diagnosisResult,
        historicalImages: historicalImages.isNotEmpty ? historicalImages : null,
        availableFertilizers: fertilizers.isNotEmpty ? fertilizers : null,
      );

      // Fotos speichern
      for (final image in _photos) {
        final path = await db.persistImage(image);
        await db.savePhoto(PlantPhoto(
          id: db.generateId(),
          plantId: plant.id,
          filePath: path,
          takenAt: DateTime.now(),
          purpose: 'checkup',
        ));
      }

      // Plant aktualisieren
      plant.diagnosisResult = result;
      plant.lastCheckUp = DateTime.now();
      plant.updatedAt = DateTime.now();
      await db.savePlant(plant);

      ref.invalidate(plantProvider(plant.id));
      ref.invalidate(plantPhotosProvider(plant.id));
      ref.invalidate(plantsProvider);

      setState(() => _result = result);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _analyzing = false);
    }
  }

  void _nextPlant() {
    setState(() {
      _currentIndex++;
      _photos = [];
      _result = null;
      _error = null;
    });
  }

  void _skipPlant() {
    // Als gecheckt markieren ohne Analyse
    final plant = _currentPlant;
    if (plant != null) {
      plant.lastCheckUp = DateTime.now();
      plant.updatedAt = DateTime.now();
      DatabaseService.instance.savePlant(plant);
      ref.invalidate(plantsProvider);
    }
    _nextPlant();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_pendingPlants.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pflanzen-Check')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline,
                    size: 80,
                    color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                Text('Alles im grünen Bereich!',
                    style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Alle Pflanzen wurden kürzlich geprüft.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Zurück'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final plant = _currentPlant;
    if (plant == null) {
      // Alle durch
      return Scaffold(
        appBar: AppBar(title: const Text('Pflanzen-Check')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle,
                    size: 80, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text('Check abgeschlossen!',
                    style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  '$_currentIndex Pflanze${_currentIndex == 1 ? '' : 'n'} geprüft.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fertig'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final lastCheck = plant.lastCheckUp ?? plant.createdAt;
    final daysSince = DateTime.now().difference(lastCheck).inDays;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Check ${_currentIndex + 1}/${_pendingPlants.length}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Pflanzen-Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plant.nickname,
                        style: theme.textTheme.titleLarge),
                    if (plant.speciesName != null)
                      Text(plant.speciesName!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          )),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.schedule,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          'Letzter Check: vor $daysSince Tagen',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (_result == null && !_analyzing) ...[
              Text('Mach ein aktuelles Foto:',
                  style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),

              // Foto-Vorschau
              if (_photos.isNotEmpty)
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _photos.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, index) => Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(_photos[index],
                              width: 100, height: 100, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () => setState(
                                () => _photos.removeAt(index)),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _takePhoto,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Kamera'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickFromGallery,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Galerie'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _photos.isNotEmpty ? _runAnalysis : null,
                icon: const Icon(Icons.medical_services),
                label: const Text('Analyse starten'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _skipPlant,
                child: const Text('Überspringen'),
              ),
            ],

            if (_analyzing)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Pflanze wird analysiert...'),
                    ],
                  ),
                ),
              ),

            if (_error != null) ...[
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_error!,
                      style: TextStyle(color: theme.colorScheme.error)),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _runAnalysis,
                icon: const Icon(Icons.refresh),
                label: const Text('Nochmal versuchen'),
              ),
            ],

            if (_result != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.medical_services,
                              color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text('Ergebnis',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SelectableText(_result!,
                          style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _nextPlant,
                icon: const Icon(Icons.arrow_forward),
                label: Text(_currentIndex < _pendingPlants.length - 1
                    ? 'Nächste Pflanze'
                    : 'Abschließen'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
