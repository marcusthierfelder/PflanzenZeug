import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'database_service.dart';
import 'icloud_service.dart';
import '../models/plant.dart';
import '../models/plant_photo.dart';
import '../models/chat_message.dart';
import '../models/fertilizer.dart';
import '../models/care_schedule.dart';

/// Metadaten im Keychain, Bilder in iCloud.
/// Beides überlebt App-Deinstallation und Reinstallation.
class KeychainBackupService {
  KeychainBackupService._();
  static final instance = KeychainBackupService._();

  static const _metadataKey = 'pflanzen_zeug_backup';

  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// Speichert Metadaten im Keychain + Bilder in iCloud.
  Future<void> backup() async {
    final db = DatabaseService.instance;

    final plants = db.getAllPlants();
    final photos = db.getAllPhotos();
    final messages = db.getAllChatMessages();
    final fertilizers = db.getAllFertilizers();
    final schedules = db.getAllCareSchedules();

    // Metadaten → Keychain
    final metadata = {
      'version': 2,
      'backupDate': DateTime.now().toIso8601String(),
      'plants': plants.map((p) => p.toJson()).toList(),
      'photos': photos.map((p) => p.toJson()).toList(),
      'chatMessages': messages.map((m) => m.toJson()).toList(),
      'fertilizers': fertilizers.map((f) => f.toJson()).toList(),
      'careSchedules': schedules.map((s) => s.toJson()).toList(),
    };
    await _storage.write(key: _metadataKey, value: jsonEncode(metadata));

    // Bilder → iCloud (best-effort, im Hintergrund)
    final icloud = ICloudService.instance;
    for (final photo in photos) {
      final file = _fileIfExists(photo.filePath);
      if (file != null) {
        icloud.saveImage(photo.id, file).ignore();
      }
    }
    for (final fert in fertilizers) {
      if (fert.photoPath != null) {
        final file = _fileIfExists(fert.photoPath!);
        if (file != null) {
          icloud.saveImage('fert_${fert.id}', file).ignore();
        }
      }
    }
  }

  /// Prüft ob ein Backup im Keychain vorhanden ist.
  Future<bool> hasBackup() async {
    final value = await _storage.read(key: _metadataKey);
    return value != null;
  }

  /// Stellt alle Daten wieder her: Metadaten aus Keychain, Bilder aus iCloud.
  Future<bool> restore() async {
    final json = await _storage.read(key: _metadataKey);
    if (json == null) return false;

    final data = jsonDecode(json) as Map<String, dynamic>;
    final db = DatabaseService.instance;
    final icloud = ICloudService.instance;

    // Pflanzen wiederherstellen
    for (final p in (data['plants'] as List?) ?? []) {
      await db.savePlant(Plant.fromJson(Map<String, dynamic>.from(p as Map)));
    }

    // Fotos wiederherstellen (Metadaten + Bilddateien aus iCloud)
    for (final p in (data['photos'] as List?) ?? []) {
      final photoMap = Map<String, dynamic>.from(p as Map);
      final photoId = photoMap['id'] as String;
      final filePath = photoMap['filePath'] as String;

      // Bild aus iCloud wiederherstellen
      await icloud.restoreImage(photoId, filePath);

      await db.savePhoto(PlantPhoto.fromJson(photoMap));
    }

    // Chat-Nachrichten wiederherstellen
    for (final m in (data['chatMessages'] as List?) ?? []) {
      await db.saveChatMessage(
          ChatMessage.fromJson(Map<String, dynamic>.from(m as Map)));
    }

    // Dünger wiederherstellen
    for (final f in (data['fertilizers'] as List?) ?? []) {
      final fertMap = Map<String, dynamic>.from(f as Map);
      final fertId = fertMap['id'] as String;
      final photoPath = fertMap['photoPath'] as String?;

      // Dünger-Foto aus iCloud wiederherstellen
      if (photoPath != null) {
        await icloud.restoreImage('fert_$fertId', photoPath);
      }

      await db.saveFertilizer(Fertilizer.fromJson(fertMap));
    }

    // Pflegepläne wiederherstellen
    for (final s in (data['careSchedules'] as List?) ?? []) {
      await db.saveCareSchedule(
          CareSchedule.fromJson(Map<String, dynamic>.from(s as Map)));
    }

    return true;
  }

  static File? _fileIfExists(String path) {
    final file = File(path);
    return file.existsSync() ? file : null;
  }
}
