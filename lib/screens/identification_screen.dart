import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/plant.dart';
import '../models/plant_photo.dart';
import '../models/care_profile/plant_identification_result.dart';
import '../providers/ai_provider.dart';
import '../providers/database_provider.dart';
import '../services/database_service.dart';
import '../services/parsers/care_profile_parser.dart';
import '../services/parsers/parse_result.dart';
import '../widgets/care_profile_grid.dart';
import 'diagnosis_screen.dart';

class IdentificationScreen extends ConsumerStatefulWidget {
  final List<File> images;
  final bool isMixedPot;
  final String? existingPlantId;

  const IdentificationScreen({
    super.key,
    required this.images,
    this.isMixedPot = false,
    this.existingPlantId,
  });

  @override
  ConsumerState<IdentificationScreen> createState() =>
      _IdentificationScreenState();
}

/// Hält die abweichende Einschätzung des Modells im Vergleich zur gespeicherten Art.
class _SpeciesConflict {
  /// Bisheriger (gespeicherter) wissenschaftlicher Name.
  final String previousScientificName;

  /// Neu vom Modell vorgeschlagener wissenschaftlicher Name.
  final String newScientificName;

  /// Neu vom Modell vorgeschlagener Anzeigename.
  final String newDisplayName;

  const _SpeciesConflict({
    required this.previousScientificName,
    required this.newScientificName,
    required this.newDisplayName,
  });
}

class _IdentificationScreenState extends ConsumerState<IdentificationScreen> {
  /// Roher LLM-Output (String).
  String? _rawResult;

  /// Geparster Identifikations-Ergebnis (null bei Parse-Fehler).
  ParseResult<PlantIdentificationResult>? _parseResult;

  String? _error;
  bool _loading = false;
  String? _savedPlantId;

  /// Gesetzt wenn das Modell eine andere Art nennt als bisher gespeichert.
  _SpeciesConflict? _speciesConflict;

  // ── Shortcuts auf geparste Daten ──────────────────────────────────────────
  PlantIdentificationResult? get _identified =>
      _parseResult?.valueOrNull;

  // ── API-Aufruf ─────────────────────────────────────────────────────────────
  Future<void> _identify() async {
    setState(() {
      _loading = true;
      _error = null;
      _rawResult = null;
      _parseResult = null;
      _speciesConflict = null;
    });

    try {
      final service = ref.read(aiServiceProvider);
      if (service == null) {
        throw Exception(
            'Kein API Key konfiguriert. Bitte in den Einstellungen hinterlegen.');
      }

      // Re-Identifikations-Kontext: wissenschaftlichen Namen der gespeicherten
      // Pflanze laden damit das Modell stabilisiert werden kann.
      String? previousScientificName;
      if (widget.existingPlantId != null) {
        final existing = ref.read(plantProvider(widget.existingPlantId!));
        previousScientificName = existing?.scientificName;
      }

      final raw = await service.identifyPlant(
        widget.images,
        isMixedPot: widget.isMixedPot,
        previousIdentification: previousScientificName,
      );

      final parsed = CareProfileParser.parse(raw);

      setState(() {
        _rawResult = raw;
        _parseResult = parsed;
      });

      await _autoSave(raw, parsed, previousScientificName: previousScientificName);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  // ── Auto-Speichern ─────────────────────────────────────────────────────────
  Future<void> _autoSave(
    String raw,
    ParseResult<PlantIdentificationResult> parsed, {
    String? previousScientificName,
  }) async {
    final db = DatabaseService.instance;
    final now = DateTime.now();

    // Namen, Vertrauen aus geparsten Daten oder Fallback-Regex
    String name = '';
    String? scientificName;
    double? confidence;

    if (parsed.isSuccess) {
      final r = parsed.valueOrNull!;
      name = r.name;
      scientificName = r.scientificName;
      confidence = r.confidence?.toDouble();
    } else {
      // Fallback: altes Regex-Parsing für den Namen
      final nameMatch = RegExp(r'NAME:\s*(.+)').firstMatch(raw);
      final sciMatch = RegExp(r'WISSENSCHAFTLICH:\s*(.+)').firstMatch(raw);
      final confMatch = RegExp(r'SICHERHEIT:\s*(\d+)').firstMatch(raw);
      name = nameMatch?.group(1)?.replaceAll(RegExp(r'[*#]'), '').trim() ?? '';
      scientificName =
          sciMatch?.group(1)?.replaceAll(RegExp(r'[*#]'), '').trim();
      confidence =
          confMatch != null ? double.tryParse(confMatch.group(1)!) : null;
    }

    // careProfileJson: JSON-String bei Erfolg, sonst null
    final careProfileJson = parsed.isSuccess
        ? jsonEncode(parsed.valueOrNull!.toJson())
        : null;

    if (widget.existingPlantId != null) {
      final existing = ref.read(plantProvider(widget.existingPlantId!));
      if (existing != null) {
        // ── Konflikt-Erkennung ────────────────────────────────────────────────
        // Liegt ein vorheriger wissenschaftlicher Name vor und nennt das Modell
        // jetzt eine andere Art? → NICHT still überschreiben, sondern Nutzer
        // informieren. "Bestätigung" liegt vor wenn der neue Name leer ist
        // oder mit dem gespeicherten übereinstimmt (case-insensitive Trim).
        final prevName = previousScientificName?.trim().toLowerCase();
        final newName = scientificName?.trim().toLowerCase();
        final isConflict = prevName != null &&
            prevName.isNotEmpty &&
            newName != null &&
            newName.isNotEmpty &&
            newName != prevName;

        if (isConflict) {
          // Art-Abweichung: Pflanzendaten NICHT überschreiben.
          // Nur Foto, Konfidenz und Care-Profil updaten (Pflegetipps können
          // sich verbessern), aber scientificName / speciesName bleiben.
          existing.identificationResult = raw;
          existing.identificationConfidence = confidence;
          if (careProfileJson != null) {
            existing.careProfileJson = careProfileJson;
          }
          existing.updatedAt = now;
          await db.savePlant(existing);
          ref.invalidate(plantProvider(widget.existingPlantId!));
          ref.invalidate(plantsProvider);
          // Beide Strings sind durch isConflict-Guard garantiert non-null.
          final prevSci = previousScientificName ?? '';
          final newSci = scientificName ?? '';
          setState(() {
            _savedPlantId = widget.existingPlantId;
            _speciesConflict = _SpeciesConflict(
              previousScientificName: prevSci,
              newScientificName: newSci,
              newDisplayName: name.isNotEmpty ? name : newSci,
            );
          });
          return;
        }

        // Bestätigung oder keine Voridentifikation: normal updaten.
        existing.speciesName =
            name.isNotEmpty ? name : existing.speciesName;
        existing.scientificName =
            scientificName ?? existing.scientificName;
        existing.identificationResult = raw;
        existing.identificationConfidence = confidence;
        existing.careProfileJson = careProfileJson;
        existing.updatedAt = now;
        await db.savePlant(existing);
        ref.invalidate(plantProvider(widget.existingPlantId!));
        ref.invalidate(plantsProvider);
        setState(() => _savedPlantId = widget.existingPlantId);
        return;
      }
    }

    final plantId = db.generateId();
    final plant = Plant(
      id: plantId,
      nickname: name.isNotEmpty
          ? name
          : (widget.isMixedPot ? 'Mischtopf' : 'Meine Pflanze'),
      speciesName: name.isNotEmpty ? name : null,
      scientificName: scientificName,
      isMixedPot: widget.isMixedPot,
      identificationResult: raw,
      identificationConfidence: confidence,
      careProfileJson: careProfileJson,
      createdAt: now,
      updatedAt: now,
    );
    await db.savePlant(plant);

    for (final image in widget.images) {
      final path = await db.persistImage(image);
      await db.savePhoto(PlantPhoto(
        id: db.generateId(),
        plantId: plantId,
        filePath: path,
        takenAt: now,
        purpose: 'identification',
      ));
    }

    ref.invalidate(plantsProvider);
    setState(() => _savedPlantId = plantId);
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Pflanze erkennen')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Foto-Vorschau
            _PhotoPreview(images: widget.images),
            const SizedBox(height: 24),

            // Startbutton
            if (_rawResult == null && !_loading && _error == null)
              FilledButton.icon(
                onPressed: _identify,
                icon: const Icon(Icons.search),
                label: const Text('Pflanze identifizieren'),
              ),

            // Ladeindikator
            if (_loading) const _LoadingState(),

            // Fehler
            if (_error != null) ...[
              _ErrorCard(error: _error!, theme: theme),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _identify,
                icon: const Icon(Icons.refresh),
                label: const Text('Nochmal versuchen'),
              ),
            ],

            // Ergebnis
            if (_rawResult != null && _parseResult != null) ...[
              _parseResult!.when(
                success: (result) => _StructuredResultSection(
                  result: result,
                  theme: theme,
                ),
                partial: (fallbackText, error) => _MarkdownFallbackSection(
                  rawText: fallbackText,
                  parseError: error,
                  theme: theme,
                ),
              ),
              const SizedBox(height: 16),

              // Konflikt-Banner: Modell schlägt andere Art vor
              if (_speciesConflict != null) ...[
                _SpeciesConflictBanner(
                  conflict: _speciesConflict!,
                  theme: theme,
                ),
                const SizedBox(height: 8),
              ],

              // Gespeichert-Badge (nur ohne Konflikt oder zusätzlich)
              if (_savedPlantId != null && _speciesConflict == null)
                _SavedBadge(theme: theme),
              const SizedBox(height: 8),

              // Diagnose starten
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DiagnosisScreen(
                        images: widget.images,
                        plantName: _identified?.name ?? _rawResult!,
                        plantId: _savedPlantId,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.medical_services),
                label: const Text('Diagnose starten'),
              ),
              const SizedBox(height: 8),

              // Nochmal erkennen
              OutlinedButton.icon(
                onPressed: _identify,
                icon: const Icon(Icons.refresh),
                label: const Text('Nochmal erkennen'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Sub-Widgets ────────────────────────────────────────────────────────────────

class _PhotoPreview extends StatelessWidget {
  final List<File> images;
  const _PhotoPreview({required this.images});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, _i) => const SizedBox(width: 8),
        itemBuilder: (_, index) => ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            images[index],
            width: 120,
            height: 120,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Pflanze wird erkannt…'),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String error;
  final ThemeData theme;
  const _ErrorCard({required this.error, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.error, color: theme.colorScheme.error),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Strukturiertes Karten-Layout (JSON wurde erfolgreich geparst).
class _StructuredResultSection extends StatelessWidget {
  final PlantIdentificationResult result;
  final ThemeData theme;

  const _StructuredResultSection({
    required this.result,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: Pflanzenname + Confidence
        _PlantHeader(result: result, theme: theme),
        const SizedBox(height: 16),

        // Pflege-Karten-Grid (Hauptinhalt)
        CareProfileGrid(
          careProfile: result.careProfile,
          difficulty: result.difficulty,
          toxicity: result.toxicity,
        ),

        // Diagnostische Notizen (ausklappbar)
        if (result.diagnosticNotes != null &&
            result.diagnosticNotes!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _ExpandableNotes(
            title: '🔬 Erkennungsmerkmale',
            text: result.diagnosticNotes!,
            theme: theme,
          ),
        ],

        // Zusätzliche Hinweise (ausklappbar)
        if (result.additionalNotes != null &&
            result.additionalNotes!.isNotEmpty) ...[
          const SizedBox(height: 8),
          _ExpandableNotes(
            title: '📝 Weitere Hinweise',
            text: result.additionalNotes!,
            theme: theme,
            isMarkdown: true,
          ),
        ],
      ],
    );
  }
}

/// Pflanzen-Header: Name, wissenschaftlicher Name, Familie, Confidence.
class _PlantHeader extends StatelessWidget {
  final PlantIdentificationResult result;
  final ThemeData theme;
  const _PlantHeader({required this.result, required this.theme});

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF3D7A4E);
    const lightGreenBg = Color(0xFFF0F7F1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: lightGreenBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryGreen.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titelzeile
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.eco, color: primaryGreen, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: primaryGreen,
                  ),
                ),
              ),
              if (result.confidence != null)
                _ConfidenceBadge(confidence: result.confidence!),
            ],
          ),
          // Wissenschaftlicher Name
          if (result.scientificName != null) ...[
            const SizedBox(height: 4),
            Text(
              result.scientificName!,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: const Color(0xFF555555),
              ),
            ),
          ],
          // Familie
          if (result.family != null) ...[
            const SizedBox(height: 2),
            Text(
              'Familie: ${result.family}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF777777),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Ausklappbarer Notiz-Block (für diagnosticNotes / additionalNotes).
class _ExpandableNotes extends StatefulWidget {
  final String title;
  final String text;
  final ThemeData theme;
  final bool isMarkdown;

  const _ExpandableNotes({
    required this.title,
    required this.text,
    required this.theme,
    this.isMarkdown = false,
  });

  @override
  State<_ExpandableNotes> createState() => _ExpandableNotesState();
}

class _ExpandableNotesState extends State<_ExpandableNotes> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFFF8F8F8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF444444),
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: _expanded ? 0.5 : 0,
                    child: const Icon(
                      Icons.expand_more,
                      size: 18,
                      color: Color(0xFF888888),
                    ),
                  ),
                ],
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: widget.isMarkdown
                      ? MarkdownBody(
                          data: widget.text,
                          selectable: true,
                          styleSheet:
                              MarkdownStyleSheet.fromTheme(widget.theme).copyWith(
                            p: widget.theme.textTheme.bodyMedium?.copyWith(
                              height: 1.6,
                              fontSize: 14,
                            ),
                          ),
                        )
                      : Text(
                          widget.text,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF555555),
                            height: 1.6,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Markdown-Fallback (JSON-Parsing fehlgeschlagen).
class _MarkdownFallbackSection extends StatelessWidget {
  final String rawText;
  final String? parseError;
  final ThemeData theme;

  const _MarkdownFallbackSection({
    required this.rawText,
    this.parseError,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hinweis: Altes Format
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFF5A623).withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              const Text('ℹ️', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ergebnis im Textformat (ältere Analyse)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade800,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Markdown-Anzeige
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.eco, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Ergebnis',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                MarkdownBody(
                  data: rawText,
                  selectable: true,
                  styleSheet:
                      MarkdownStyleSheet.fromTheme(theme).copyWith(
                    p: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Banner bei abweichender Art-Einschätzung des Modells.
///
/// Wird angezeigt wenn das Modell eine andere Art nennt als bisher gespeichert.
/// Die bestehende Klassifikation bleibt ERHALTEN – der Nutzer wird nur informiert.
class _SpeciesConflictBanner extends StatelessWidget {
  final _SpeciesConflict conflict;
  final ThemeData theme;

  const _SpeciesConflictBanner({
    required this.conflict,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    const warnColor = Color(0xFFE65100); // deep orange
    const warnBg = Color(0xFFFFF3E0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: warnBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: warnColor.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titelzeile
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: warnColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Abweichende Einschätzung',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: warnColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Bisherige Art
          _ConflictRow(
            icon: Icons.check_circle_outline,
            iconColor: const Color(0xFF3D7A4E),
            label: 'Bisher gespeichert:',
            value: conflict.previousScientificName,
            valueStyle: const TextStyle(
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w600,
              color: Color(0xFF3D7A4E),
            ),
          ),
          const SizedBox(height: 6),

          // Neue Einschätzung
          _ConflictRow(
            icon: Icons.swap_horiz,
            iconColor: warnColor,
            label: 'Neue Einschätzung:',
            value:
                '${conflict.newDisplayName} (${conflict.newScientificName})',
            valueStyle: TextStyle(
              fontStyle: FontStyle.italic,
              color: warnColor.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 12),

          // Erklärung
          Text(
            'Die bisherige Klassifikation wurde NICHT überschrieben. '
            'Schau dir die Erkennungsmerkmale an und entscheide selbst.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF6D4C41),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConflictRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final TextStyle valueStyle;

  const _ConflictRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF444444), height: 1.4),
              children: [
                TextSpan(
                    text: '$label ',
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                TextSpan(text: value, style: valueStyle),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Gespeichert-Badge.
class _SavedBadge extends StatelessWidget {
  final ThemeData theme;
  const _SavedBadge({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Text('In Sammlung gespeichert'),
          ],
        ),
      ),
    );
  }
}

/// Confidence-Badge (grün/orange/rot je nach Wert).
class _ConfidenceBadge extends StatelessWidget {
  final int confidence;
  const _ConfidenceBadge({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final color = confidence >= 80
        ? Colors.green
        : confidence >= 60
            ? Colors.orange
            : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            '$confidence%',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Zeigt strukturiertes Karten-Layout für eine bereits in der DB gespeicherte Pflanze.
///
/// Wird z.B. im PlantDetailScreen verwendet um das Care-Profil darzustellen.
/// Gibt null zurück wenn kein care_profile_json vorhanden (Fallback muss außerhalb gehandelt werden).
class PlantCareProfileView extends StatelessWidget {
  final Plant plant;
  final ThemeData theme;

  const PlantCareProfileView({
    super.key,
    required this.plant,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final jsonStr = plant.careProfileJson;
    if (jsonStr == null || jsonStr.isEmpty) {
      // Kein strukturiertes Profil – Fallback auf Markdown
      final markdown = plant.identificationResult ?? '';
      if (markdown.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.all(16),
        child: MarkdownBody(
          data: markdown,
          selectable: true,
          styleSheet: MarkdownStyleSheet.fromTheme(theme),
        ),
      );
    }

    final parseResult = CareProfileParser.parse(jsonStr);
    return parseResult.when(
      success: (result) => Padding(
        padding: const EdgeInsets.all(16),
        child: CareProfileGrid(
          careProfile: result.careProfile,
          difficulty: result.difficulty,
          toxicity: result.toxicity,
        ),
      ),
      partial: (fallbackText, _) {
        // Fallback: zeige Markdown-Identifikationsergebnis
        final md = plant.identificationResult ?? fallbackText;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: MarkdownBody(
            data: md,
            selectable: true,
            styleSheet: MarkdownStyleSheet.fromTheme(theme),
          ),
        );
      },
    );
  }
}
