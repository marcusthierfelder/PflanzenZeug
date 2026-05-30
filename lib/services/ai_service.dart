import 'dart:io';
import '../models/diagnosis/diagnosis_result.dart';
import '../models/fertilizer.dart';
import '../services/parsers/parse_result.dart';

abstract class AIService {
  /// Identifiziert eine Pflanze anhand von [images].
  ///
  /// [previousIdentification] – wissenschaftlicher Name einer bereits
  /// dokumentierten Pflanze. Wenn übergeben, enthält der Prompt den
  /// Re-Identifikations-Kontext, der Drift verhindert.
  Future<String> identifyPlant(
    List<File> images, {
    bool isMixedPot = false,
    String? previousIdentification,
  });

  /// Analysiert Bilder und gibt ein strukturiertes [DiagnosisResult] zurück.
  ///
  /// Bei Parse-Fehler: [ParsePartial] mit Roh-Text als Markdown-Fallback.
  Future<ParseResult<DiagnosisResult>> diagnosePlant({
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
