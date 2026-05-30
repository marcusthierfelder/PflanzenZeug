import 'dart:convert';
import '../../models/care_profile/plant_identification_result.dart';
import 'json_extractor.dart';
import 'parse_result.dart';

/// Parser für den strukturierten JSON-Output der Pflanzen-Identifikation.
///
/// Gibt bei Erfolg ein [ParseSuccess<PlantIdentificationResult>] zurück,
/// bei Parse-Fehler ein [ParsePartial] mit dem Original-Text als Markdown-Fallback.
class CareProfileParser {
  CareProfileParser._();

  /// Parst den rohen LLM-Output zu einem [PlantIdentificationResult].
  ///
  /// Ist tolerant gegenüber:
  /// - Markdown-Code-Fences (```json ... ```)
  /// - Zusätzlichem Text vor/nach dem JSON
  /// - Fehlenden oder unbekannten Feldern
  ///
  /// Gibt niemals null zurück und wirft nie – bei Fehler: [ParsePartial].
  static ParseResult<PlantIdentificationResult> parse(String raw) {
    if (raw.trim().isEmpty) {
      return ParseResult.partial(
        fallbackText: raw,
        error: 'Leere Antwort vom AI-Service',
      );
    }

    final jsonString = JsonExtractor.extract(raw);
    if (jsonString == null) {
      return ParseResult.partial(
        fallbackText: raw,
        error: 'Kein JSON-Block gefunden',
      );
    }

    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        return ParseResult.partial(
          fallbackText: raw,
          error: 'JSON ist kein Objekt (war: ${decoded.runtimeType})',
        );
      }
      final result = PlantIdentificationResult.fromJson(decoded);
      return ParseResult.success(result);
    } on FormatException catch (e) {
      return ParseResult.partial(
        fallbackText: raw,
        error: 'JSON-Parse-Fehler: ${e.message}',
      );
    } catch (e) {
      return ParseResult.partial(
        fallbackText: raw,
        error: 'Unerwarteter Fehler: $e',
      );
    }
  }
}
