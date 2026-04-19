import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/plant.dart';
import '../models/plant_photo.dart';
import '../models/chat_message.dart';
import '../models/care_schedule.dart';
import '../services/database_service.dart';

final databaseServiceProvider =
    Provider<DatabaseService>((_) => DatabaseService.instance);

final plantsProvider = Provider<List<Plant>>((ref) {
  return ref.watch(databaseServiceProvider).getAllPlants();
});

final plantProvider = Provider.family<Plant?, String>((ref, id) {
  return ref.watch(databaseServiceProvider).getPlant(id);
});

final plantPhotosProvider =
    Provider.family<List<PlantPhoto>, String>((ref, plantId) {
  return ref.watch(databaseServiceProvider).getPhotosForPlant(plantId);
});

final plantChatProvider =
    Provider.family<List<ChatMessage>, String>((ref, plantId) {
  return ref.watch(databaseServiceProvider).getChatMessagesForPlant(plantId);
});

final plantCareSchedulesProvider =
    Provider.family<List<CareSchedule>, String>((ref, plantId) {
  return ref.watch(databaseServiceProvider).getCareSchedulesForPlant(plantId);
});
