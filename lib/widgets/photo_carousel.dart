import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/plant.dart';
import '../models/plant_photo.dart';
import '../providers/database_provider.dart';
import '../services/database_service.dart';

class PhotoCarousel extends ConsumerWidget {
  final Plant plant;
  final List<PlantPhoto> photos;

  const PhotoCarousel({
    super.key,
    required this.plant,
    required this.photos,
  });

  void _openFullscreen(BuildContext context, List<PlantPhoto> validPhotos, int initialIndex, DatabaseService db) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (ctx, anim1, anim2) => _FullscreenPhotoView(
          photos: validPhotos,
          initialIndex: initialIndex,
          db: db,
        ),
      ),
    );
  }

  Future<void> _showPhotoMenu(BuildContext context, WidgetRef ref, PlantPhoto photo, bool isCover) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isCover)
              ListTile(
                leading: const Icon(Icons.star),
                title: const Text('Als Titelbild setzen'),
                onTap: () => Navigator.pop(context, 'cover'),
              ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Foto löschen', style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Abbrechen'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted) return;

    if (action == 'cover') {
      plant.coverPhotoId = photo.id;
      plant.updatedAt = DateTime.now();
      await DatabaseService.instance.savePlant(plant);
      ref.invalidate(plantProvider(plant.id));
      ref.invalidate(plantsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Als Titelbild gesetzt')),
        );
      }
    } else if (action == 'delete') {
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Foto löschen'),
          content: const Text('Dieses Foto unwiderruflich löschen?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Löschen'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      if (plant.coverPhotoId == photo.id) {
        plant.coverPhotoId = null;
        plant.updatedAt = DateTime.now();
        await DatabaseService.instance.savePlant(plant);
      }
      await DatabaseService.instance.deletePhoto(photo.id);
      ref.invalidate(plantPhotosProvider(plant.id));
      ref.invalidate(plantProvider(plant.id));
      ref.invalidate(plantsProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = DatabaseService.instance;
    final validPhotos = photos
        .where((p) => File(db.resolveImagePath(p.filePath)).existsSync())
        .toList();
    if (validPhotos.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        itemCount: validPhotos.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final photo = validPhotos[index];
          final isCover = plant.coverPhotoId == photo.id;
          return GestureDetector(
            onTap: () => _openFullscreen(context, validPhotos, index, db),
            onLongPress: () => _showPhotoMenu(context, ref, photo, isCover),
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(db.resolveImagePath(photo.filePath)),
                          width: 160,
                          fit: BoxFit.cover,
                        ),
                      ),
                      if (isCover)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.star,
                              size: 16,
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${photo.takenAt.day}.${photo.takenAt.month}.${photo.takenAt.year}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FullscreenPhotoView extends StatefulWidget {
  final List<PlantPhoto> photos;
  final int initialIndex;
  final DatabaseService db;

  const _FullscreenPhotoView({
    required this.photos,
    required this.initialIndex,
    required this.db,
  });

  @override
  State<_FullscreenPhotoView> createState() => _FullscreenPhotoViewState();
}

class _FullscreenPhotoViewState extends State<_FullscreenPhotoView> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: PageView.builder(
          controller: _controller,
          itemCount: widget.photos.length,
          itemBuilder: (_, index) {
            final photo = widget.photos[index];
            return InteractiveViewer(
              child: Center(
                child: Image.file(
                  File(widget.db.resolveImagePath(photo.filePath)),
                  fit: BoxFit.contain,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
