/// Statischer Helper zum Extrahieren von JSON aus rohem LLM-Output.
///
/// Entfernt Markdown-Code-Fences (```json … ```) und extrahiert
/// den JSON-Block (erstes `{` bis letztes `}`).
/// Kann von beliebigen Parser-Modulen genutzt werden (shared Infrastruktur).
class JsonExtractor {
  JsonExtractor._();

  /// Extrahiert den ersten JSON-Object-Block aus [raw].
  ///
  /// Strategie:
  /// 1. Code-Fences entfernen (```json ... ``` oder ``` ... ```)
  /// 2. Erstes `{` bis letztes `}` extrahieren
  ///
  /// Gibt null zurück wenn kein gültiger JSON-Block gefunden wurde.
  static String? extract(String raw) {
    if (raw.isEmpty) return null;

    // Code-Fences entfernen
    var cleaned = _stripCodeFences(raw);

    // Erstes { bis letztes } extrahieren
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');

    if (start == -1 || end == -1 || end <= start) return null;

    return cleaned.substring(start, end + 1).trim();
  }

  static String _stripCodeFences(String raw) {
    // Entfernt ```json ... ``` oder ``` ... ``` Blöcke (auch ohne Sprach-Tag)
    return raw
        .replaceAll(RegExp(r'```json\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();
  }
}
