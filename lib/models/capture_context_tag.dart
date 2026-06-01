/// Kontext-Tag der beim Fotografieren optional ausgewählt werden kann.
///
/// Fließt als domänenspezifischer Kontext-Block in den Diagnose-Prompt ein.
enum CaptureTagKey {
  leaf,
  root,
  flower,
  custom,
}

class CaptureContextTag {
  final CaptureTagKey key;

  /// Nur bei [CaptureTagKey.custom] befüllt (max. 60 Zeichen, gesäubert).
  final String? customText;

  const CaptureContextTag({required this.key, this.customText});

  // ── Labels & Emoji ───────────────────────────────────────────────────────

  String get emoji {
    switch (key) {
      case CaptureTagKey.leaf:
        return '🌿';
      case CaptureTagKey.root:
        return '🌱';
      case CaptureTagKey.flower:
        return '🌸';
      case CaptureTagKey.custom:
        return '✏️';
    }
  }

  String get label {
    switch (key) {
      case CaptureTagKey.leaf:
        return 'Blätter';
      case CaptureTagKey.root:
        return 'Wurzeln';
      case CaptureTagKey.flower:
        return 'Blüten';
      case CaptureTagKey.custom:
        return customText?.isNotEmpty == true ? customText! : 'Eigenes';
    }
  }

  String get chipLabel => '$emoji $label';

  /// Zeigt den Root-Hinweis-Banner (nur bei Wurzeln-Tag).
  bool get showRootBanner => key == CaptureTagKey.root;

  // ── Prompt-Kontext-Texte ─────────────────────────────────────────────────

  /// Kontext-Block der in den Diagnose-Prompt eingefügt wird.
  static const String _leafContext =
      'Der Nutzer fotografiert bewusst die BLÄTTER der Pflanze. '
      'Bitte lege den Diagnose-Fokus auf Blatt-Symptome: Verfärbungen, Flecken, Nekrosen, '
      'Verformungen, Befall auf der Blatt-Ober- und Unterseite. '
      'Chlorosen, Schorfflecken, Mehltau, Schädlinge an Blättern haben erhöhte Relevanz.';

  static const String _rootContext =
      'Der Nutzer fotografiert bewusst die WURZELN der Pflanze. '
      'WICHTIG: Braune, korkige oder fadenförmige Luftwurzeln sind bei Monstera, '
      'Philodendron, Epipremnum und Orchideen absolut artypisch und KEIN Befund. '
      'Fokussiere auf echte Wurzelprobleme: Fäule (schwarz-matschig, fauliger Geruch), '
      'spiralförmiges Einwachsen, starke Topfüberselung. '
      'Gesunde Luftwurzeln nie als Problem einstufen.';

  static const String _flowerContext =
      'Der Nutzer fotografiert bewusst die BLÜTEN der Pflanze. '
      'Bitte lege den Diagnose-Fokus auf Blüten-Symptome: vorzeitiger Blütenfall, '
      'Verfärbungen der Blütenblätter, Botrytis-Grauschimmel, Schädlinge an Blüten, '
      'mangelhafte Knospentwicklung. '
      'Natürliches Verblühen und Petalen-Abwurf nach Blütezeit sind KEIN Befund.';

  /// Gibt den fertig formatierten Kontext-Block für den Diagnose-Prompt zurück.
  /// Gibt `null` zurück wenn kein Tag aktiv ist.
  String? toPromptContext() {
    switch (key) {
      case CaptureTagKey.leaf:
        return '=== NUTZER-FOTO-KONTEXT ===\n$_leafContext\n=== ENDE KONTEXT ===';
      case CaptureTagKey.root:
        return '=== NUTZER-FOTO-KONTEXT ===\n$_rootContext\n=== ENDE KONTEXT ===';
      case CaptureTagKey.flower:
        return '=== NUTZER-FOTO-KONTEXT ===\n$_flowerContext\n=== ENDE KONTEXT ===';
      case CaptureTagKey.custom:
        final text = customText;
        if (text == null || text.isEmpty) return null;
        return '=== NUTZER-KONTEXT ===\nNutzer-Kontext: $text\n=== ENDE KONTEXT ===';
    }
  }

  // ── Serialisierung (für PlantPhoto-Persistenz) ───────────────────────────

  String get tagKeyString {
    switch (key) {
      case CaptureTagKey.leaf:
        return 'leaf';
      case CaptureTagKey.root:
        return 'root';
      case CaptureTagKey.flower:
        return 'flower';
      case CaptureTagKey.custom:
        return 'custom';
    }
  }

  Map<String, dynamic> toJson() => {
        'key': tagKeyString,
        if (customText != null) 'customText': customText,
      };

  factory CaptureContextTag.fromJson(Map<dynamic, dynamic> json) {
    final keyStr = json['key'] as String? ?? 'leaf';
    final key = _parseKey(keyStr);
    return CaptureContextTag(
      key: key,
      customText: json['customText'] as String?,
    );
  }

  static CaptureTagKey _parseKey(String s) {
    switch (s) {
      case 'root':
        return CaptureTagKey.root;
      case 'flower':
        return CaptureTagKey.flower;
      case 'custom':
        return CaptureTagKey.custom;
      default:
        return CaptureTagKey.leaf;
    }
  }

  @override
  String toString() => chipLabel;
}
