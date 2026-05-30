/// Pflegeschwierigkeit einer Pflanze.
enum Difficulty {
  easy,
  medium,
  hard,
  unknown;

  static Difficulty fromString(String? value) {
    return switch (value?.toLowerCase()) {
      'easy' => Difficulty.easy,
      'medium' => Difficulty.medium,
      'hard' => Difficulty.hard,
      _ => Difficulty.unknown,
    };
  }

  String get label => switch (this) {
        Difficulty.easy => 'Einfach',
        Difficulty.medium => 'Mittel',
        Difficulty.hard => 'Anspruchsvoll',
        Difficulty.unknown => 'Unbekannt',
      };
}
