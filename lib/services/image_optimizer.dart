import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Optimiert ein Bild vor dem AI-Call:
/// - Max. 1280px Kantenlänge (minWidth/minHeight werden als Obergrenze verwendet)
/// - JPEG-Qualität 80 %
/// - Nutzt native Plattform-Encoder (schnell, keine spürbare Latenz)
class ImageOptimizer {
  ImageOptimizer._();

  static const int _maxEdge = 1280;
  static const int _quality = 80;

  /// Gibt eine optimierte Version des Bildes zurück.
  /// Falls die Komprimierung fehlschlägt, wird das Original zurückgegeben.
  static Future<File> optimize(File image) async {
    try {
      final tmpDir = await getTemporaryDirectory();
      final baseName = p.basenameWithoutExtension(image.path);
      final outPath = p.join(tmpDir.path, '${baseName}_opt.jpg');

      final result = await FlutterImageCompress.compressAndGetFile(
        image.absolute.path,
        outPath,
        minWidth: _maxEdge,
        minHeight: _maxEdge,
        quality: _quality,
        format: CompressFormat.jpeg,
        keepExif: false,
      );

      if (result == null) return image;
      return File(result.path);
    } catch (_) {
      // Fehler bei der Komprimierung → Original weiterverwenden
      return image;
    }
  }
}
