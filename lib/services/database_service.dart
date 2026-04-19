import 'dart:io';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/plant.dart';
import '../models/plant_photo.dart';
import '../models/chat_message.dart';
import '../models/fertilizer.dart';
import '../models/care_schedule.dart';

const _uuid = Uuid();

class DatabaseService {
  DatabaseService._();
  static final instance = DatabaseService._();

  late Box<Map> _plantsBox;
  late Box<Map> _photosBox;
  late Box<Map> _chatBox;
  late Box<Map> _fertilizersBox;
  late Box<Map> _careBox;
  late Directory _imageDir;

  Future<void> init() async {
    await Hive.initFlutter();
    _plantsBox = await Hive.openBox<Map>('plants');
    _photosBox = await Hive.openBox<Map>('photos');
    _chatBox = await Hive.openBox<Map>('chat_messages');
    _fertilizersBox = await Hive.openBox<Map>('fertilizers');
    _careBox = await Hive.openBox<Map>('care_schedules');

    final appDir = await getApplicationDocumentsDirectory();
    _imageDir = Directory('${appDir.path}/plant_images');
    if (!_imageDir.existsSync()) {
      _imageDir.createSync(recursive: true);
    }
  }

  String generateId() => _uuid.v4();

  // --- Images ---

  Future<String> persistImage(File source) async {
    final id = generateId();
    final ext = source.path.split('.').last;
    final dest = '${_imageDir.path}/$id.$ext';
    await source.copy(dest);
    return dest;
  }

  // --- Plants ---

  Future<void> savePlant(Plant plant) async {
    await _plantsBox.put(plant.id, plant.toJson());
  }

  Plant? getPlant(String id) {
    final json = _plantsBox.get(id);
    if (json == null) return null;
    return Plant.fromJson(json);
  }

  List<Plant> getAllPlants() {
    return _plantsBox.values.map((json) => Plant.fromJson(json)).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> deletePlant(String id) async {
    await _plantsBox.delete(id);
    // Delete associated photos, messages, care schedules
    final photoKeys = _photosBox.keys
        .where((k) => _photosBox.get(k)?['plantId'] == id)
        .toList();
    for (final key in photoKeys) {
      final path = _photosBox.get(key)?['filePath'] as String?;
      if (path != null) {
        final file = File(path);
        if (file.existsSync()) file.deleteSync();
      }
      await _photosBox.delete(key);
    }
    final chatKeys =
        _chatBox.keys.where((k) => _chatBox.get(k)?['plantId'] == id).toList();
    for (final key in chatKeys) {
      await _chatBox.delete(key);
    }
    final careKeys =
        _careBox.keys.where((k) => _careBox.get(k)?['plantId'] == id).toList();
    for (final key in careKeys) {
      await _careBox.delete(key);
    }
  }

  // --- Plant Photos ---

  Future<void> savePhoto(PlantPhoto photo) async {
    await _photosBox.put(photo.id, photo.toJson());
  }

  List<PlantPhoto> getPhotosForPlant(String plantId) {
    return _photosBox.values
        .map((json) => PlantPhoto.fromJson(json))
        .where((p) => p.plantId == plantId)
        .toList()
      ..sort((a, b) => b.takenAt.compareTo(a.takenAt));
  }

  // --- Chat Messages ---

  Future<void> saveChatMessage(ChatMessage message) async {
    await _chatBox.put(message.id, message.toJson());
  }

  List<ChatMessage> getChatMessagesForPlant(String plantId) {
    return _chatBox.values
        .map((json) => ChatMessage.fromJson(json))
        .where((m) => m.plantId == plantId)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  // --- Fertilizers ---

  Future<void> saveFertilizer(Fertilizer fertilizer) async {
    await _fertilizersBox.put(fertilizer.id, fertilizer.toJson());
  }

  List<Fertilizer> getAllFertilizers() {
    return _fertilizersBox.values
        .map((json) => Fertilizer.fromJson(json))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> deleteFertilizer(String id) async {
    final fert = _fertilizersBox.get(id);
    if (fert != null) {
      final path = fert['photoPath'] as String?;
      if (path != null) {
        final file = File(path);
        if (file.existsSync()) file.deleteSync();
      }
    }
    await _fertilizersBox.delete(id);
  }

  // --- Care Schedules ---

  Future<void> saveCareSchedule(CareSchedule schedule) async {
    await _careBox.put(schedule.id, schedule.toJson());
  }

  List<CareSchedule> getCareSchedulesForPlant(String plantId) {
    return _careBox.values
        .map((json) => CareSchedule.fromJson(json))
        .where((s) => s.plantId == plantId)
        .toList();
  }

  List<CareSchedule> getOverdueCareSchedules() {
    final now = DateTime.now();
    return _careBox.values
        .map((json) => CareSchedule.fromJson(json))
        .where((s) => now.isAfter(s.nextDue))
        .toList()
      ..sort((a, b) => a.nextDue.compareTo(b.nextDue));
  }

  Future<void> deleteCareSchedule(String id) async {
    await _careBox.delete(id);
  }
}
