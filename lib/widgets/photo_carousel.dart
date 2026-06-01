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

  void _openFullscreen(
    BuildContext context,
    WidgetRef ref,
    List<PlantPhoto> validPhotos,
    int initialIndex,
    DatabaseService db,
  ) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (ctx, anim1, anim2) => _FullscreenPhotoView(
          photos: validPhotos,
          initialIndex: initialIndex,
          db: db,
          plant: plant,
          onDelete: (PlantPhoto photo) async {
            if (plant.coverPhotoId == photo.id) {
              plant.coverPhotoId = null;
              plant.updatedAt = DateTime.now();
              await DatabaseService.instance.savePlant(plant);
            }
            await DatabaseService.instance.deletePhoto(photo.id);
            ref.invalidate(plantPhotosProvider(plant.id));
            ref.invalidate(plantProvider(plant.id));
            ref.invalidate(plantsProvider);
          },
        ),
      ),
    );
  }

  Future<void> _showPhotoMenu(
    BuildContext context,
    WidgetRef ref,
    PlantPhoto photo,
    bool isCover,
  ) async {
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
            onTap: () => _openFullscreen(context, ref, validPhotos, index, db),
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
                      // Cover-Stern-Indikator (oben rechts)
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
                      // Aktions-Icon (oben links) – sichtbarer Einstiegspunkt für Menü
                      Positioned(
                        top: 4,
                        left: 4,
                        child: GestureDetector(
                          onTap: () => _showPhotoMenu(context, ref, photo, isCover),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.more_vert,
                              size: 16,
                              color: Colors.white,
                            ),
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

// ---------------------------------------------------------------------------
// Fullscreen-Viewer
// ---------------------------------------------------------------------------

class _FullscreenPhotoView extends StatefulWidget {
  final List<PlantPhoto> photos;
  final int initialIndex;
  final DatabaseService db;
  final Plant plant;

  /// Callback: Provider-Invalidierung und DB-Aufruf werden im Eltern-Widget
  /// (PhotoCarousel, das `ref` besitzt) ausgeführt. Der Fullscreen-Viewer
  /// bleibt ref-frei und damit einfacher testbar.
  final Future<void> Function(PlantPhoto photo) onDelete;

  const _FullscreenPhotoView({
    required this.photos,
    required this.initialIndex,
    required this.db,
    required this.plant,
    required this.onDelete,
  });

  @override
  State<_FullscreenPhotoView> createState() => _FullscreenPhotoViewState();
}

class _FullscreenPhotoViewState extends State<_FullscreenPhotoView> {
  late PageController _controller;
  late List<PlantPhoto> _photos;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _photos = List.of(widget.photos);
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  PlantPhoto get _currentPhoto => _photos[_currentIndex];

  Future<void> _confirmDelete() async {
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
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    final photoToDelete = _currentPhoto;

    // DB-Aufruf + Provider-Invalidierung über Callback im Eltern-Widget
    await widget.onDelete(photoToDelete);

    if (!mounted) return;

    setState(() {
      _photos.remove(photoToDelete);
    });

    if (_photos.isEmpty) {
      // Letztes Foto gelöscht → Viewer schließen
      if (mounted) Navigator.of(context).pop();
      return;
    }

    // Zum nächsten Foto wechseln (oder letztem, wenn am Ende)
    final newIndex = _currentIndex.clamp(0, _photos.length - 1);
    setState(() {
      _currentIndex = newIndex;
    });
    _controller.jumpToPage(newIndex);
  }

  @override
  Widget build(BuildContext context) {
    if (_photos.isEmpty) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black45,
        foregroundColor: Colors.white,
        elevation: 0,
        // Schließt den Viewer über den Zurück-Button (ersetzt onTap-to-close
        // für die AppBar-Zone; Body-Tap-to-close bleibt erhalten)
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Schließen',
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Foto löschen',
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: GestureDetector(
        // Tap auf den Body (außerhalb der AppBar) schließt den Viewer
        onTap: () => Navigator.of(context).pop(),
        child: PageView.builder(
          controller: _controller,
          itemCount: _photos.length,
          onPageChanged: (i) => setState(() => _currentIndex = i),
          itemBuilder: (_, index) {
            final photo = _photos[index];
            return InteractiveViewer(
              // InteractiveViewer verbraucht Tap-Events beim Zoomen –
              // GestureDetector außen bleibt als Fallback für einfachen Tap.
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
