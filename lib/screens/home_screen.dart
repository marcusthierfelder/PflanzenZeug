import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../models/capture_context_tag.dart';
import '../models/plant.dart';
import '../models/plant_photo.dart';
import '../providers/api_key_provider.dart';
import '../providers/database_provider.dart';
import '../services/database_service.dart';
import '../widgets/camera_picker_helper.dart';
import '../widgets/photo_tips_sheet.dart';
import 'identification_screen.dart';
import 'plant_detail_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _images = <File>[];
  final _picker = ImagePicker();
  bool _isMixedPot = false;

  /// Aktuell aktiver Kontext-Tag (vom letzten Kamera-Aufruf).
  CaptureContextTag? _contextTag;

  Future<void> _takePhoto() async {
    final capture = await openBurstCamera(context);
    if (capture == null || !mounted) return;

    for (final f in capture.photos) {
      _checkImageSize(f);
    }
    setState(() {
      _images.addAll(capture.photos);
      // Tag vom letzten Kamera-Aufruf übernehmen (falls kein Tag: bisherigen behalten)
      if (capture.contextTag != null) {
        _contextTag = capture.contextTag;
      }
    });
  }

  Future<void> _pickFromGallery() async {
    await maybeShowPhotoTipsSheet(context);
    if (!mounted) return;

    final photos = await _picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (photos.isNotEmpty && mounted) {
      final files = photos.map((p) => File(p.path)).toList();
      for (final f in files) {
        _checkImageSize(f);
      }
      setState(() => _images.addAll(files));
    }
  }

  /// Prüft die Dateigröße und zeigt bei < 30 KB einen nicht-blockierenden Hinweis.
  Future<void> _checkImageSize(File image) async {
    final size = await image.length();
    if (size < 30 * 1024 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⚠️ Bild könnte zu klein sein – Erkennung evtl. ungenau',
          ),
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  void _startIdentification() {
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte nimm mindestens ein Foto auf')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => IdentificationScreen(
          images: List.of(_images),
          isMixedPot: _isMixedPot,
          // Kontext-Tag für spätere Diagnose mitführen
          contextTag: _contextTag,
        ),
      ),
    );
  }

  Future<void> _createManually() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Pflanze anlegen'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Name der Pflanze',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) => Navigator.pop(context, value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Anlegen'),
            ),
          ],
        );
      },
    );

    if (name == null || name.isEmpty || !mounted) return;

    final db = DatabaseService.instance;
    final plantId = db.generateId();
    final now = DateTime.now();

    final plant = Plant(
      id: plantId,
      nickname: name,
      isMixedPot: _isMixedPot,
      createdAt: now,
      updatedAt: now,
    );
    await db.savePlant(plant);

    // Fotos speichern falls vorhanden (mit Kontext-Tag)
    for (final image in _images) {
      final path = await db.persistImage(image);
      await db.savePhoto(PlantPhoto(
        id: db.generateId(),
        plantId: plantId,
        filePath: path,
        takenAt: now,
        purpose: 'identification',
        contextTag: _contextTag,
      ));
    }

    ref.invalidate(plantsProvider);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PlantDetailScreen(plantId: plantId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PflanzenStuff'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettings(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _images.isEmpty ? _buildEmptyState(theme) : _buildGrid(),
          ),
          _buildBottomBar(theme),
        ],
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
              Icons.camera_alt_outlined,
              size: 80,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Fotografiere deine Pflanze',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Mach am besten mehrere Fotos aus\nverschiedenen Blickwinkeln',
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

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _images.length,
      itemBuilder: (context, index) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(_images[index], fit: BoxFit.cover),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton.filled(
                  onPressed: () => _removeImage(index),
                  icon: const Icon(Icons.close, size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(32, 32),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomBar(ThemeData theme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Aktiver Tag-Badge
            if (_contextTag != null && _images.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ActiveTagBadge(
                  tag: _contextTag!,
                  onClear: () => setState(() => _contextTag = null),
                ),
              ),
            if (_images.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${_images.length} Foto${_images.length == 1 ? '' : 's'} aufgenommen',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Mehrere Pflanzen in einem Topf'),
              subtitle: const Text(
                'Alle Arten werden gemeinsam analysiert',
                style: TextStyle(fontSize: 12),
              ),
              value: _isMixedPot,
              onChanged: (v) => setState(() => _isMixedPot = v),
            ),
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
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _images.isEmpty ? null : _startIdentification,
              icon: const Icon(Icons.search),
              label: const Text('Pflanze erkennen'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _createManually,
              icon: const Icon(Icons.add),
              label: const Text('Manuell anlegen'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Einstellungen'),
        content: const Text('Möchtest du den API Key zurücksetzen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(apiKeyProvider.notifier).clearApiKey();
              Navigator.pop(context);
            },
            child: const Text('Key zurücksetzen'),
          ),
        ],
      ),
    );
  }
}

/// Zeigt den aktiven Kontext-Tag als kleinen Badge mit X-Button an.
class _ActiveTagBadge extends StatelessWidget {
  final CaptureContextTag tag;
  final VoidCallback onClear;

  const _ActiveTagBadge({required this.tag, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.label_outline,
                  size: 14, color: theme.colorScheme.onPrimaryContainer),
              const SizedBox(width: 4),
              Text(
                tag.chipLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close,
                    size: 14, color: theme.colorScheme.onPrimaryContainer),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
