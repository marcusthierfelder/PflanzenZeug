/// Generischer Sum-Type für Parsing-Ergebnisse.
///
/// - [ParseResult.success]: Parsing erfolgreich, enthält typisiertes Ergebnis [value].
/// - [ParseResult.partial]: Parsing fehlgeschlagen, enthält [fallbackText] (Markdown)
///   und optionale [error]-Nachricht für Logging.
sealed class ParseResult<T> {
  const ParseResult();

  /// Erfolgreich geparst.
  const factory ParseResult.success(T value) = ParseSuccess<T>;

  /// Parsing fehlgeschlagen – Fallback auf Markdown-Text.
  const factory ParseResult.partial({
    required String fallbackText,
    String? error,
  }) = ParsePartial<T>;

  /// True wenn Parsing erfolgreich war.
  bool get isSuccess => this is ParseSuccess<T>;

  /// True wenn nur Fallback verfügbar ist.
  bool get isPartial => this is ParsePartial<T>;

  /// Gibt [value] zurück wenn success, sonst null.
  T? get valueOrNull => switch (this) {
        ParseSuccess<T>(:final value) => value,
        ParsePartial<T>() => null,
      };

  /// Gibt [fallbackText] zurück wenn partial, sonst null.
  String? get fallbackText => switch (this) {
        ParseSuccess<T>() => null,
        ParsePartial<T>(:final fallbackText) => fallbackText,
      };

  /// Gibt [error] zurück wenn partial, sonst null.
  String? get error => switch (this) {
        ParseSuccess<T>() => null,
        ParsePartial<T>(:final error) => error,
      };

  R when<R>({
    required R Function(T value) success,
    required R Function(String fallbackText, String? error) partial,
  }) =>
      switch (this) {
        ParseSuccess<T>(:final value) => success(value),
        ParsePartial<T>(:final fallbackText, :final error) =>
          partial(fallbackText, error),
      };
}

/// Erfolgreicher Parse-Zustand.
final class ParseSuccess<T> extends ParseResult<T> {
  final T value;
  const ParseSuccess(this.value);
}

/// Partieller Parse-Zustand (Fallback auf Markdown).
final class ParsePartial<T> extends ParseResult<T> {
  @override
  final String fallbackText;
  @override
  final String? error;
  const ParsePartial({required this.fallbackText, this.error});
}
