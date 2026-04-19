import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/plant.dart';
import '../models/plant_photo.dart';
import '../providers/api_key_provider.dart';
import '../providers/database_provider.dart';
import '../services/claude_service.dart';
import '../services/database_service.dart';
import 'diagnosis_screen.dart';

class IdentificationScreen extends ConsumerStatefulWidget {
  final List<File> images;

  const IdentificationScreen({super.key, required this.images});

  @override
  ConsumerState<IdentificationScreen> createState() =>
      _IdentificationScreenState();
}

class _IdentificationScreenState extends ConsumerState<IdentificationScreen> {
  String? _result;
  String? _error;
  bool _loading = false;
  String? _savedPlantId;

  Future<void> _identify() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final apiKey = ref.read(apiKeyProvider).value;
      if (apiKey == null) throw Exception('Kein API Key');

      final service = ClaudeService(apiKey);
      final result = await service.identifyPlant(widget.images);
      setState(() => _result = result);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveToCollection() async {
    final nicknameCtrl = TextEditingController();
    final locationCtrl = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zur Sammlung hinzufügen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nicknameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name (z.B. "Wohnzimmer-Orchidee")',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: locationCtrl,
              decoration: const InputDecoration(
                labelText: 'Standort (z.B. "Südfenster")',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );

    if (saved != true) return;

    final db = DatabaseService.instance;
    final plantId = db.generateId();
    final now = DateTime.now();
    final nickname = nicknameCtrl.text.trim().isEmpty
        ? (_result?.split('\n').first ?? 'Meine Pflanze')
        : nicknameCtrl.text.trim();

    final plant = Plant(
      id: plantId,
      nickname: nickname,
      speciesName: _result?.split('\n').first.replaceAll(RegExp(r'[*#]'), '').trim(),
      location: locationCtrl.text.trim(),
      identificationResult: _result,
      createdAt: now,
      updatedAt: now,
    );
    await db.savePlant(plant);

    // Persist images
    for (final image in widget.images) {
      final path = await db.persistImage(image);
      await db.savePhoto(PlantPhoto(
        id: db.generateId(),
        plantId: plantId,
        filePath: path,
        takenAt: now,
        purpose: 'identification',
      ));
    }

    ref.invalidate(plantsProvider);

    setState(() => _savedPlantId = plantId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pflanze gespeichert!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Pflanze erkennen')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image preview
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.images.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    widget.images[index],
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            if (_result == null && !_loading && _error == null)
              FilledButton.icon(
                onPressed: _identify,
                icon: const Icon(Icons.search),
                label: const Text('Pflanze identifizieren'),
              ),

            if (_loading) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Pflanze wird erkannt...'),
                    ],
                  ),
                ),
              ),
            ],

            if (_error != null) ...[
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(Icons.error, color: theme.colorScheme.error),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.error),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _identify,
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
                          Icon(Icons.eco, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Ergebnis',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        _result!,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_savedPlantId == null)
                FilledButton.icon(
                  onPressed: _saveToCollection,
                  icon: const Icon(Icons.bookmark_add),
                  label: const Text('Zur Sammlung hinzufügen'),
                )
              else
                Card(
                  color: theme.colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle,
                            color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        const Text('In Sammlung gespeichert'),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DiagnosisScreen(
                        images: widget.images,
                        plantName: _result!,
                        plantId: _savedPlantId,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.medical_services),
                label: const Text('Diagnose starten'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _identify,
                icon: const Icon(Icons.refresh),
                label: const Text('Nochmal erkennen'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
