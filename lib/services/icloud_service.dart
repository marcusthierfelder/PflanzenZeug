import 'dart:io';
import 'package:flutter/services.dart';

/// Zugriff auf den iCloud Documents Container.
/// Bilder dort überleben App-Deinstallation und Reinstallation.
class ICloudService {
  ICloudService._();
  static final instance = ICloudService._();

  static const _channel =
      MethodChannel('de.marcusthierfelder.pflanzenZeug/icloud');

  String? _containerPath;

  /// Gibt den iCloud Documents Pfad zurück, oder null falls nicht verfügbar.
  Future<String?> getContainerPath() async {
    if (_containerPath != null) return _containerPath;
    try {
      _containerPath = await _channel.invokeMethod<String>('getICloudContainerPath');
      return _containerPath;
    } on PlatformException {
      return null;
    }
  }

  /// Speichert eine Bilddatei in iCloud. Gibt true zurück bei Erfolg.
  Future<bool> saveImage(String imageId, File sourceFile) async {
    try {
      final path = await getContainerPath();
      if (path == null) return false;

      final imagesDir = Directory('$path/plant_images');
      if (!imagesDir.existsSync()) {
        imagesDir.createSync(recursive: true);
      }

      final ext = sourceFile.path.split('.').last;
      final dest = '${imagesDir.path}/$imageId.$ext';
      await sourceFile.copy(dest);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Stellt ein Bild aus iCloud wieder her. Gibt den lokalen Pfad zurück oder null.
  Future<String?> restoreImage(String imageId, String localDestPath) async {
    try {
      final path = await getContainerPath();
      if (path == null) return null;

      final imagesDir = Directory('$path/plant_images');
      if (!imagesDir.existsSync()) return null;

      // Datei finden (Extension kann variieren)
      final files = imagesDir.listSync().whereType<File>().where(
            (f) => f.path.split('/').last.startsWith(imageId),
          );
      if (files.isEmpty) return null;

      final source = files.first;
      final destFile = File(localDestPath);
      await destFile.parent.create(recursive: true);
      await source.copy(localDestPath);
      return localDestPath;
    } catch (_) {
      return null;
    }
  }

  /// Gibt alle in iCloud gespeicherten Bild-IDs zurück.
  Future<List<String>> listImageIds() async {
    try {
      final path = await getContainerPath();
      if (path == null) return [];

      final imagesDir = Directory('$path/plant_images');
      if (!imagesDir.existsSync()) return [];

      return imagesDir
          .listSync()
          .whereType<File>()
          .map((f) {
            final name = f.path.split('/').last;
            return name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name;
          })
          .toList();
    } catch (_) {
      return [];
    }
  }
}
