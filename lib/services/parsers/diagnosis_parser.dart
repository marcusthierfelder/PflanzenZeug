import 'dart:convert';
import '../../models/diagnosis/diagnosis_result.dart';
import 'json_extractor.dart';
import 'parse_result.dart';

/// Parser für den strukturierten JSON-Output der Pflanzen-Diagnose.
///
/// Nutzt die geteilten Low-Level-Helper [JsonExtractor] und [ParseResult]
/// aus der Shared-Parser-Infrastruktur.
///
/// Gibt bei Erfolg [ParseSuccess<DiagnosisResult>] zurück,
/// bei Fehler [ParsePartial] mit Roh-Text als Markdown-Fallback.
class DiagnosisParser {
  DiagnosisParser._();

  /// Parst den rohen LLM-Output zu einem [DiagnosisResult].
  ///
  /// Ist tolerant gegenüber:
  /// - Markdown-Code-Fences (```json ... ```)
  /// - Zusätzlichem Text vor/nach dem JSON
  /// - Fehlenden Feldern (defensives fromJson)
  ///
  /// Wirft nie – bei jedem Fehler: [ParsePartial] mit Fallback-Text.
  static ParseResult<DiagnosisResult> parse(String raw) {
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
        error: 'Kein JSON-Block in der Antwort gefunden',
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
      final result = DiagnosisResult.fromJson(decoded);
      return ParseResult.success(result);
    } on FormatException catch (e) {
      return ParseResult.partial(
        fallbackText: raw,
        error: 'JSON-Parse-Fehler: ${e.message}',
      );
    } catch (e) {
      return ParseResult.partial(
        fallbackText: raw,
        error: 'Unerwarteter Fehler beim Parsing: $e',
      );
    }
  }
}
