import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hilfsfunktion: Rendert ein Widget in einem minimalen MaterialApp-Wrapper
Widget buildTestApp(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(child: child),
    ),
  );
}

void main() {
  // ────────────────────────────────────────────────────────────────────────────
  // T-01: MarkdownBody ist im Widget-Baum vorhanden (identification_screen)
  // ────────────────────────────────────────────────────────────────────────────
  testWidgets('T-01 MarkdownBody widget ist im Baum vorhanden', (tester) async {
    await tester.pumpWidget(buildTestApp(
      MarkdownBody(
        data: '**Fett** und normal',
        selectable: true,
      ),
    ));
    expect(find.byType(MarkdownBody), findsOneWidget);
  });

  // ────────────────────────────────────────────────────────────────────────────
  // T-02: Fett-Text wird gerendert (kein sichtbares **)
  // ────────────────────────────────────────────────────────────────────────────
  testWidgets('T-02 Fett-Markdown rendert ohne sichtbare Sterne', (tester) async {
    const markdown = '**Basilikum** ist eine Gewürzpflanze.';
    await tester.pumpWidget(buildTestApp(
      MarkdownBody(data: markdown, selectable: true),
    ));
    // Rohtext mit ** darf NICHT als ganzer String sichtbar sein
    expect(find.text(markdown), findsNothing);
    // Das gerenderte Wort erscheint irgendwo im Widget-Baum
    expect(find.textContaining('Basilikum'), findsWidgets);
  });

  // ────────────────────────────────────────────────────────────────────────────
  // T-03: ## Überschriften werden gerendert
  // ────────────────────────────────────────────────────────────────────────────
  testWidgets('T-03 ## Überschriften rendern korrekt', (tester) async {
    const markdown = '## Pflegehinweise\nGieße täglich.';
    await tester.pumpWidget(buildTestApp(
      MarkdownBody(data: markdown, selectable: true),
    ));
    // Die ## Zeichen selbst dürfen nicht sichtbar sein
    expect(find.text('## Pflegehinweise'), findsNothing);
    // Text der Überschrift muss erscheinen
    expect(find.textContaining('Pflegehinweise'), findsWidgets);
  });

  // ────────────────────────────────────────────────────────────────────────────
  // T-04: Aufzählungslisten werden gerendert
  // ────────────────────────────────────────────────────────────────────────────
  testWidgets('T-04 Aufzählungen rendern korrekt', (tester) async {
    const markdown = '- Punkt eins\n- Punkt zwei\n- Punkt drei';
    await tester.pumpWidget(buildTestApp(
      MarkdownBody(data: markdown, selectable: true),
    ));
    expect(find.textContaining('Punkt eins'), findsWidgets);
    expect(find.textContaining('Punkt zwei'), findsWidgets);
    expect(find.textContaining('Punkt drei'), findsWidgets);
    // Rohe Bindestriche als Markdown-Marker dürfen nicht als "- Punkt eins" sichtbar sein
    expect(find.text('- Punkt eins'), findsNothing);
  });

  // ────────────────────────────────────────────────────────────────────────────
  // T-05: selectable: true → intern SelectableText.rich im Baum
  // flutter_markdown@0.7.7 rendert selectable text via SelectableText.rich,
  // NICHT via SelectionArea (geprüft in builder.dart des Packages).
  // ────────────────────────────────────────────────────────────────────────────
  testWidgets('T-05 selectable:true erzeugt SelectableText im Baum', (tester) async {
    await tester.pumpWidget(buildTestApp(
      MarkdownBody(
        data: 'Kopierbarer Text hier.',
        selectable: true,
      ),
    ));
    // flutter_markdown nutzt SelectableText.rich intern → SelectableText im Baum
    expect(find.byType(SelectableText), findsAtLeastNWidgets(1));
  });

  // ────────────────────────────────────────────────────────────────────────────
  // T-06: selectable: false → normaler RichText, kein SelectableText
  // ────────────────────────────────────────────────────────────────────────────
  testWidgets('T-06 selectable:false nutzt keinen SelectableText', (tester) async {
    await tester.pumpWidget(buildTestApp(
      MarkdownBody(
        data: 'Nicht kopierbarer Text.',
        selectable: false,
      ),
    ));
    expect(find.byType(SelectableText), findsNothing);
  });

  // ────────────────────────────────────────────────────────────────────────────
  // T-07: Komplexes Claude-Antwort-Muster (identification_screen-typisch)
  // ────────────────────────────────────────────────────────────────────────────
  testWidgets('T-07 Komplexe Claude-Identifikations-Antwort rendert fehlerfrei',
      (tester) async {
    const claudeResponse = '''
NAME: Basilikum
WISSENSCHAFTLICH: Ocimum basilicum
SICHERHEIT: 92

## Pflanzenbeschreibung
**Basilikum** ist ein einjähriges Kraut aus der Familie der Lippenblütler.

## Pflegehinweise
- Sonniger Standort (min. 6h Sonne)
- Regelmäßig gießen, **kein Staunasser**
- Temperatur: **18–25 °C**

## Besonderheiten
Basilikum verträgt keine Kälte unter 10 °C.
''';
    await tester.pumpWidget(buildTestApp(
      MarkdownBody(data: claudeResponse, selectable: true),
    ));
    // Kein Crash, Widget gerendert
    expect(find.byType(MarkdownBody), findsOneWidget);
    // Wichtige Textinhalte sichtbar
    expect(find.textContaining('Basilikum'), findsWidgets);
    expect(find.textContaining('Pflegehinweise'), findsWidgets);
    expect(find.textContaining('Sonniger Standort'), findsWidgets);
    // Rohe Markdown-Syntax darf nicht sichtbar sein
    expect(find.text('## Pflegehinweise'), findsNothing);
    expect(find.text('**Basilikum**'), findsNothing);
  });

  // ────────────────────────────────────────────────────────────────────────────
  // T-08: Komplexes Claude-Antwort-Muster (diagnosis_screen-typisch)
  // ────────────────────────────────────────────────────────────────────────────
  testWidgets('T-08 Komplexe Claude-Diagnose-Antwort rendert fehlerfrei',
      (tester) async {
    const diagnosisResponse = '''
## Diagnose
**Mögliche Ursache:** Wurzelfäule durch Staunässe.

## Symptome
- Gelbe Blätter
- Welker Stängel
- Schlechter Geruch der Erde

## Empfehlungen
1. Topf sofort leeren
2. **Braune Wurzeln** entfernen
3. Frische, gut drainierte Erde verwenden

Viel Erfolg bei der Pflege!
''';
    await tester.pumpWidget(buildTestApp(
      MarkdownBody(data: diagnosisResponse, selectable: true),
    ));
    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(find.textContaining('Diagnose'), findsWidgets);
    expect(find.textContaining('Gelbe Blätter'), findsWidgets);
    expect(find.textContaining('Viel Erfolg'), findsWidgets);
    // Markdown-Syntax darf nicht raw sichtbar sein
    expect(find.text('## Diagnose'), findsNothing);
    expect(find.text('**Mögliche Ursache:**'), findsNothing);
  });

  // ────────────────────────────────────────────────────────────────────────────
  // T-09: Leerer String crasht nicht
  // ────────────────────────────────────────────────────────────────────────────
  testWidgets('T-09 Leerer Markdown-String crasht nicht', (tester) async {
    await tester.pumpWidget(buildTestApp(
      MarkdownBody(data: '', selectable: true),
    ));
    expect(find.byType(MarkdownBody), findsOneWidget);
  });

  // ────────────────────────────────────────────────────────────────────────────
  // T-10: DB-Bestandsdaten (gespeicherter Markdown-String) rendern korrekt
  // ────────────────────────────────────────────────────────────────────────────
  testWidgets('T-10 Bereits in DB gespeicherter Markdown-String rendert korrekt',
      (tester) async {
    // Simuliert einen alten, aus der DB geladenen identificationResult-String
    const dbStoredMarkdown = '''
NAME: Monstera
WISSENSCHAFTLICH: Monstera deliciosa
SICHERHEIT: 88

## Beschreibung
**Monstera deliciosa** – auch bekannt als Fensterblatt.

## Pflegetipps
- Halbschattig bis hell
- **Nicht zu viel gießen**
- Luftfeuchtigkeit: 50–70%
''';
    await tester.pumpWidget(buildTestApp(
      MarkdownBody(data: dbStoredMarkdown, selectable: true),
    ));
    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(find.textContaining('Monstera'), findsWidgets);
    expect(find.textContaining('Pflegetipps'), findsWidgets);
    // Keine sichtbaren Markdown-Zeichen
    expect(find.text('**Monstera deliciosa**'), findsNothing);
    expect(find.text('## Pflegetipps'), findsNothing);
  });

  // ────────────────────────────────────────────────────────────────────────────
  // T-11: MarkdownStyleSheet.fromTheme() konfiguriert korrekt
  // ────────────────────────────────────────────────────────────────────────────
  testWidgets('T-11 MarkdownStyleSheet.fromTheme mit copyWith rendert ohne Fehler',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(builder: (context) {
          final theme = Theme.of(context);
          return Scaffold(
            body: SingleChildScrollView(
              child: MarkdownBody(
                data: '## Titel\n**Fett** und *kursiv*\n\n- Liste 1\n- Liste 2',
                selectable: true,
                styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                  p: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          );
        }),
      ),
    );
    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(find.textContaining('Titel'), findsWidgets);
    expect(find.textContaining('Liste 1'), findsWidgets);
  });
}
