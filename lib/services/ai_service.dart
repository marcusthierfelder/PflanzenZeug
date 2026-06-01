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
  ///
  /// [speciesNotes] – optionale art-spezifische Hinweise aus der Pflanzen-
  /// bestimmung (aus careProfileJson + additionalNotes). Verbessert die
  /// Diagnose-Qualität erheblich, da der LLM artypische Merkmale kennt.
  ///
  /// [userContext] – optionaler Nutzer-Foto-Kontext aus dem Kontext-Tagging
  /// (z. B. Wurzeln-Kontext, Blüten-Kontext). Gibt dem LLM domänenspezifische
  /// Hinweise über den bewussten Foto-Fokus des Nutzers.
  Future<ParseResult<DiagnosisResult>> diagnosePlant({
    required List<File> images,
    required String plantName,
    String? location,
    String? potInfo,
    bool isMixedPot = false,
    String? previousDiagnosis,
    List<File>? historicalImages,
    List<Fertilizer>? availableFertilizers,
    String? speciesNotes,
    String? userContext,
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
