import 'dart:io';
import 'package:flutter/material.dart';
import '../models/capture_context_tag.dart';
import '../screens/burst_camera_screen.dart';
import 'photo_tips_sheet.dart';

/// Rückgabe-Objekt von [openBurstCamera]:
/// die aufgenommenen Fotos + optionaler Kontext-Tag.
class BurstCameraCapture {
  final List<File> photos;
  final CaptureContextTag? contextTag;

  const BurstCameraCapture({required this.photos, this.contextTag});
}

/// Öffnet den [BurstCameraScreen] und gibt die aufgenommenen Fotos + Tag zurück.
///
/// Zeigt vorab einmalig den Foto-Tipps-Sheet an.
/// Gibt `null` zurück wenn der Nutzer abbricht oder keine Fotos aufnimmt.
Future<BurstCameraCapture?> openBurstCamera(BuildContext context) async {
  // Foto-Tipps beim ersten Mal anzeigen
  await maybeShowPhotoTipsSheet(context);
  if (!context.mounted) return null;

  final result = await Navigator.of(context).push<BurstCameraResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const BurstCameraScreen(),
    ),
  );

  if (result == null || result.photos.isEmpty) return null;
  return BurstCameraCapture(
    photos: result.photos,
    contextTag: result.contextTag,
  );
}
