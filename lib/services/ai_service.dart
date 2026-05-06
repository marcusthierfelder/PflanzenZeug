import 'dart:io';
import '../models/fertilizer.dart';

abstract class AIService {
  Future<String> identifyPlant(List<File> images, {bool isMixedPot = false});

  Future<String> diagnosePlant({
    required List<File> images,
    required String plantName,
    String? location,
    String? potInfo,
    bool isMixedPot = false,
    String? previousDiagnosis,
    List<File>? historicalImages,
    List<Fertilizer>? availableFertilizers,
  });

  Future<String> identifyFertilizer(List<File> images);

  Future<String> askQuestion({
    required List<Map<String, dynamic>> conversationHistory,
    required String question,
    List<Fertilizer>? availableFertilizers,
  });

  Future<String> suggestCareSchedule({
    required String plantName,
    String? identificationResult,
    String? diagnosisResult,
  });
}
