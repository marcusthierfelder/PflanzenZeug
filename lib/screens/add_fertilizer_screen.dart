import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../models/fertilizer.dart';
import '../providers/api_key_provider.dart';
import '../services/claude_service.dart';
import '../services/database_service.dart';

class AddFertilizerScreen extends ConsumerStatefulWidget {
  const AddFertilizerScreen({super.key});

  @override
  ConsumerState<AddFertilizerScreen> createState() =>
      _AddFertilizerScreenState();
}

class _AddFertilizerScreenState extends ConsumerState<AddFertilizerScreen> {
  final _picker = ImagePicker();
  final _nameController = TextEditingController();
  File? _image;
  String? _analysis;
  String? _error;
  bool _loading = false;
  String _detectedName = '';
  String? _detectedBrand;
  String? _detectedNpk;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (photo != null) {
      setState(() => _image = File(photo.path));
      _analyze();
    }
  }

  Future<void> _pickFromGallery() async {
    final photo = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (photo != null) {
      setState(() => _image = File(photo.path));
      _analyze();
    }
  }

  Future<void> _analyze() async {
    if (_image == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final apiKey = ref.read(apiKeyProvider).value;
      if (apiKey == null) throw Exception('Kein API Key');

      final service = ClaudeService(apiKey);
      final result = await service.identifyFertilizer([_image!]);
      setState(() {
        _analysis = result;
        // Try to extract name from first line
        final lines = result.split('\n');
        if (lines.isNotEmpty) {
          _detectedName = lines.first.replaceAll(RegExp(r'[*#]'), '').trim();
          _nameController.text = _detectedName;
        }
        // Try to find NPK
        final npkMatch =
            RegExp(r'(\d+[-–]\d+[-–]\d+)').firstMatch(result);
        if (npkMatch != null) {
          _detectedNpk = npkMatch.group(1)?.replaceAll('–', '-');
        }
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final db = DatabaseService.instance;
    String? photoPath;
    if (_image != null) {
      photoPath = await db.persistImage(_image!);
    }

    await db.saveFertilizer(Fertilizer(
      id: db.generateId(),
      name: name,
      brand: _detectedBrand,
      description: _analysis,
      npkRatio: _detectedNpk,
      photoPath: photoPath,
      createdAt: DateTime.now(),
    ));

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Dünger hinzufügen')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_image == null) ...[
              Text(
                'Fotografiere deinen Dünger',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
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
            ],
            if (_image != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(_image!, height: 200, fit: BoxFit.cover),
              ),
              const SizedBox(height: 16),
            ],
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Dünger wird analysiert...'),
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
                onPressed: _analyze,
                icon: const Icon(Icons.refresh),
                label: const Text('Nochmal versuchen'),
              ),
            ],
            if (_analysis != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    _analysis!,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: const Text('Speichern'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
