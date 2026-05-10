import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../models/fertilizer.dart';
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
  final List<File> _images = [];
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addPhoto(ImageSource source) async {
    final picked = await _picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (picked.isEmpty) return;
    setState(() {
      _images.addAll(picked.map((x) => File(x.path)));
    });
  }

  Future<void> _addFromCamera() async {
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (photo != null) {
      setState(() => _images.add(File(photo.path)));
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);
    try {
      final db = DatabaseService.instance;
      final persistedPaths = <String>[];
      for (final img in _images) {
        persistedPaths.add(await db.persistImage(img));
      }

      await db.saveFertilizer(Fertilizer(
        id: db.generateId(),
        name: name,
        photoPaths: persistedPaths,
        createdAt: DateTime.now(),
      ));

      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canSave = _nameController.text.trim().isNotEmpty && !_saving;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dünger hinzufügen'),
        actions: [
          TextButton(
            onPressed: canSave ? _save : null,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Speichern'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Name *',
                hintText: 'z.B. Tomatendünger, Flüssigdünger',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            Text('Fotos', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SizedBox(
              height: 110,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ..._images.asMap().entries.map((entry) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                entry.value,
                                width: 110,
                                height: 110,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => setState(
                                    () => _images.removeAt(entry.key)),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.all(2),
                                  child: const Icon(Icons.close,
                                      size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                  _AddPhotoTile(
                    onCamera: _addFromCamera,
                    onGallery: () => _addPhoto(ImageSource.gallery),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Die KI-Analyse startet später über „Alle analysieren" in der Übersicht.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  const _AddPhotoTile({required this.onCamera, required this.onGallery});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Kamera'),
                onTap: () {
                  Navigator.pop(context);
                  onCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galerie'),
                onTap: () {
                  Navigator.pop(context);
                  onGallery();
                },
              ),
            ],
          ),
        ),
      ),
      child: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(8),
          color: theme.colorScheme.surfaceContainerHighest,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined,
                color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 4),
            Text('Foto',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
