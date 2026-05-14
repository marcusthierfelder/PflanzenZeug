import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/plant.dart';
import '../models/plant_photo.dart';
import '../providers/ai_provider.dart';
import '../providers/database_provider.dart';

import '../services/database_service.dart';
import 'diagnosis_screen.dart';

class IdentificationScreen extends ConsumerStatefulWidget {
  final List<File> images;
  final bool isMixedPot;
  final String? existingPlantId;

  const IdentificationScreen({
    super.key,
    required this.images,
    this.isMixedPot = false,
    this.existingPlantId,
  });

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
      
      

      final service = ref.read(aiServiceProvider);
      if (service == null) throw Exception('Kein API Key konfiguriert. Bitte in den Einstellungen hinterlegen.');
      final result = await service.identifyPlant(
        widget.images,
        isMixedPot: widget.isMixedPot,
      );
      setState(() => _result = result);

      // Automatisch zur Sammlung speichern
      await _autoSave(result);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _autoSave(String result) async {
    final db = DatabaseService.instance;
    final now = DateTime.now();

    final nameMatch = RegExp(r'NAME:\s*(.+)').firstMatch(result);
    final sciMatch = RegExp(r'WISSENSCHAFTLICH:\s*(.+)').firstMatch(result);
    final confidenceMatch = RegExp(r'SICHERHEIT:\s*(\d+)').firstMatch(result);
    final name = nameMatch?.group(1)?.replaceAll(RegExp(r'[*#]'), '').trim() ?? '';
    final scientificName = sciMatch?.group(1)?.replaceAll(RegExp(r'[*#]'), '').trim();
    final confidence = confidenceMatch != null ? double.tryParse(confidenceMatch.group(1)!) : null;

    if (widget.existingPlantId != null) {
      final existing = ref.read(plantProvider(widget.existingPlantId!));
      if (existing != null) {
        existing.speciesName = name.isNotEmpty ? name : existing.speciesName;
        existing.scientificName = scientificName ?? existing.scientificName;
        existing.identificationResult = result;
        existing.identificationConfidence = confidence;
        existing.updatedAt = now;
        await db.savePlant(existing);
        ref.invalidate(plantProvider(widget.existingPlantId!));
        ref.invalidate(plantsProvider);
        setState(() => _savedPlantId = widget.existingPlantId);
        return;
      }
    }

    final plantId = db.generateId();
    final plant = Plant(
      id: plantId,
      nickname: name.isNotEmpty ? name : (widget.isMixedPot ? 'Mischtopf' : 'Meine Pflanze'),
      speciesName: name.isNotEmpty ? name : null,
      scientificName: scientificName,
      isMixedPot: widget.isMixedPot,
      identificationResult: result,
      identificationConfidence: confidence,
      createdAt: now,
      updatedAt: now,
    );
    await db.savePlant(plant);

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
              Builder(builder: (context) {
                final confidenceMatch = RegExp(r'SICHERHEIT:\s*(\d+)').firstMatch(_result!);
                final confidence = confidenceMatch != null ? int.tryParse(confidenceMatch.group(1)!) : null;
                return Card(
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
                            if (confidence != null) ...[
                              const SizedBox(width: 8),
                              _ConfidenceBadge(confidence: confidence),
                            ],
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
                );
              }),
              const SizedBox(height: 16),
              if (_savedPlantId != null)
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
