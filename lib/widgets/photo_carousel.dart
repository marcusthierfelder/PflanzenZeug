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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final validPhotos =
        photos.where((p) => File(p.filePath).existsSync()).toList();
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
            onLongPress: () async {
              plant.coverPhotoId = photo.id;
              plant.updatedAt = DateTime.now();
              await DatabaseService.instance.savePlant(plant);
              ref.invalidate(plantProvider(plant.id));
              ref.invalidate(plantsProvider);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Als Titelbild gesetzt')),
              );
            },
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(photo.filePath),
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
