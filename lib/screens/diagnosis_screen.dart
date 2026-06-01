import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/capture_context_tag.dart';
import '../models/care_profile/plant_identification_result.dart';
import '../models/diagnosis/diagnosis_entry.dart';
import '../models/diagnosis/diagnosis_result.dart';
import '../models/diagnosis/finding.dart';
import '../providers/ai_provider.dart';
import '../providers/database_provider.dart';
import '../providers/fertilizer_provider.dart';
import '../services/database_service.dart';
import '../services/parsers/parse_result.dart';
import '../widgets/diagnosis/comparison_banner.dart';
import '../widgets/diagnosis/finding_card.dart';
import '../widgets/diagnosis/health_header.dart';
import '../widgets/diagnosis/recommendations_card.dart';
import 'chat_screen.dart';

class DiagnosisScreen extends ConsumerStatefulWidget {
  final List<File> images;
  final String plantName;
  final String? plantId;

  /// Optionaler Kontext-Tag aus dem Foto-Capture-Flow.
  /// Wird als domänenspezifischer Kontext-Block in den Diagnose-Prompt eingefügt.
  final CaptureContextTag? contextTag;

  const DiagnosisScreen({
    super.key,
    required this.images,
    required this.plantName,
    this.plantId,
    this.contextTag,
  });

  @override
  ConsumerState<DiagnosisScreen> createState() => _DiagnosisScreenState();
}

class _DiagnosisScreenState extends ConsumerState<DiagnosisScreen> {
  ParseResult<DiagnosisResult>? _parseResult;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _diagnose();
  }

  Future<void> _diagnose() async {
    setState(() {
      _loading = true;
      _error = null;
      _parseResult = null;
    });

    try {
      final service = ref.read(aiServiceProvider);
      if (service == null) {
        throw Exception(
            'Kein API Key konfiguriert. Bitte in den Einstellungen hinterlegen.');
      }
      final fertilizers = ref.read(fertilizersProvider);

      // Kontext aus DB laden falls Pflanze verknüpft
      String? location;
      String? potInfo;
      bool isMixedPot = false;
      String? previousDiagnosis;
      List<File>? historicalImages;
      String? speciesNotes;

      if (widget.plantId != null) {
        final plant = DatabaseService.instance.getPlant(widget.plantId!);
        if (plant != null) {
          location = plant.location;
          potInfo = plant.potInfo;
          isMixedPot = plant.isMixedPot;
          // Für die AI-Kontext: bevorzuge strukturiertes Markdown, Fallback auf alten String
          if (plant.diagnosisResultJson != null) {
            // Bereits strukturiert gespeichert – Markdown für Prompt generieren
            try {
              final prev =
                  DiagnosisResult.fromJson(_decodeJson(plant.diagnosisResultJson!));
              previousDiagnosis = prev.toMarkdown();
            } catch (_) {
              previousDiagnosis = plant.diagnosisResult;
            }
          } else {
            previousDiagnosis = plant.diagnosisResult;
          }

          // Art-spezifische Hinweise aus careProfileJson extrahieren
          speciesNotes = _buildSpeciesNotes(plant.careProfileJson);
        }
        final photos = DatabaseService.instance.getPhotosForPlant(widget.plantId!);
        final db = DatabaseService.instance;
        final currentPaths = widget.images.map((f) => f.path).toSet();
        final older = photos
            .where((p) => !currentPaths.contains(db.resolveImagePath(p.filePath)))
            .take(3)
            .map((p) => File(db.resolveImagePath(p.filePath)))
            .where((f) => f.existsSync())
            .toList();
        if (older.isNotEmpty) historicalImages = older;
      }

      // Kontext-Tag → Prompt-Block
      final userContext = widget.contextTag?.toPromptContext();

      final result = await service.diagnosePlant(
        images: widget.images,
        plantName: widget.plantName,
        location: location,
        potInfo: potInfo,
        isMixedPot: isMixedPot,
        previousDiagnosis: previousDiagnosis,
        historicalImages: historicalImages,
        availableFertilizers: fertilizers.isNotEmpty ? fertilizers : null,
        speciesNotes: speciesNotes,
        userContext: userContext,
      );

      setState(() => _parseResult = result);

      // Pflanze in DB persistieren + DiagnosisEntry anlegen
      if (widget.plantId != null) {
        final plant = DatabaseService.instance.getPlant(widget.plantId!);
        if (plant != null) {
          if (result is ParseSuccess<DiagnosisResult>) {
            final dr = result.value;
            // Cache-Felder für previousDiagnosis-Prompt aktuell halten
            plant.diagnosisResultJson = dr.toJsonString();
            plant.diagnosisResult = dr.toMarkdown();

            // Fotos permanent speichern (Temp-Pfade → plant_images/)
            final persistedPaths = await _persistDiagnosisPhotos();

            // DiagnosisEntry anlegen
            final db = DatabaseService.instance;
            final entry = DiagnosisEntry(
              id: db.generateId(),
              plantId: widget.plantId!,
              createdAt: DateTime.now(),
              overallHealth: dr.overallHealth,
              summary: dr.summary,
              diagnosisResultJson: dr.toJsonString(),
              photoPaths: persistedPaths,
              contextTag: widget.contextTag?.tagKeyString,
            );
            await db.saveDiagnosisEntry(entry);
            ref.invalidate(diagnosisHistoryProvider(widget.plantId!));
          } else if (result is ParsePartial<DiagnosisResult>) {
            // Fallback: Roh-Text in Legacy-Feld speichern
            plant.diagnosisResult = result.fallbackText;
            plant.diagnosisResultJson = null;
          }
          plant.updatedAt = DateTime.now();
          await DatabaseService.instance.savePlant(plant);
          ref.invalidate(plantProvider(widget.plantId!));
        }
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  /// Kopiert alle Diagnose-Fotos aus möglicherweise temporären Pfaden
  /// in den permanenten App-Dokumenten-Ordner.
  /// Gibt die gespeicherten Dateinamen zurück (relativ, für resolveImagePath).
  Future<List<String>> _persistDiagnosisPhotos() async {
    final db = DatabaseService.instance;
    final persisted = <String>[];
    for (final file in widget.images) {
      if (!file.existsSync()) continue;
      try {
        final filename = await db.persistImage(file);
        persisted.add(filename);
      } catch (_) {
        // Defensiv: ein fehlgeschlagenes Foto darf den Rest nicht blockieren
      }
    }
    return persisted;
  }

  /// Hilfsfunktion: JSON-String zu Map decodieren.
  static Map<String, dynamic> _decodeJson(String jsonString) {
    return (jsonDecode(jsonString) as Map).cast<String, dynamic>();
  }

  /// Baut aus dem careProfileJson der Pflanze einen kompakten Art-Hinweis-String
  /// für den Diagnose-Prompt.
  static String? _buildSpeciesNotes(String? careProfileJson) {
    if (careProfileJson == null || careProfileJson.isEmpty) return null;
    try {
      final json = _decodeJson(careProfileJson);
      final result = PlantIdentificationResult.fromJson(json);
      final buf = StringBuffer();

      if (result.scientificName != null && result.scientificName!.isNotEmpty) {
        buf.writeln('Wissenschaftlicher Name: ${result.scientificName}');
      }
      if (result.family != null && result.family!.isNotEmpty) {
        buf.writeln('Familie: ${result.family}');
      }

      final cp = result.careProfile;
      if (cp.water.shortValue.isNotEmpty && cp.water.shortValue != '–') {
        buf.writeln('Wasserbedarf: ${cp.water.shortValue}');
        if (cp.water.detail.isNotEmpty) buf.writeln('  → ${cp.water.detail}');
      }
      if (cp.light.shortValue.isNotEmpty && cp.light.shortValue != '–') {
        buf.writeln('Lichtbedarf: ${cp.light.shortValue}');
        if (cp.light.detail.isNotEmpty) buf.writeln('  → ${cp.light.detail}');
      }
      if (cp.humidity.shortValue.isNotEmpty && cp.humidity.shortValue != '–') {
        buf.writeln('Luftfeuchtigkeit: ${cp.humidity.shortValue}');
      }

      if (result.additionalNotes != null && result.additionalNotes!.isNotEmpty) {
        buf.writeln();
        buf.writeln('Weitere Art-Hinweise: ${result.additionalNotes}');
      }
      if (result.diagnosticNotes != null && result.diagnosticNotes!.isNotEmpty) {
        buf.writeln('Botanische Bestimmungsmerkmale: ${result.diagnosticNotes}');
      }

      final notes = buf.toString().trim();
      return notes.isEmpty ? null : notes;
    } catch (_) {
      return null;
    }
  }

  /// Liefert den Diagnose-String für den Chat-Screen.
  String _diagnosisForChat() {
    final pr = _parseResult;
    if (pr == null) return '';
    return pr.when(
      success: (dr) => dr.toMarkdown(),
      partial: (fallback, _) => fallback,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Diagnose')),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Pflanze wird analysiert...'),
                  SizedBox(height: 4),
                  Text(
                    'Krankheiten, Mängel & Empfehlungen',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Fehler-Karte
                  if (_error != null) ...[
                    Card(
                      color: theme.colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(Icons.error, color: theme.colorScheme.error),
                            const SizedBox(height: 8),
                            Text(
                              _error!,
                              style:
                                  TextStyle(color: theme.colorScheme.error),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _diagnose,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Nochmal versuchen'),
                    ),
                  ],

                  // Ergebnis (strukturiert oder Fallback)
                  if (_parseResult != null) ...[
                    _parseResult!.when(
                      success: (dr) => _buildStructured(dr, theme),
                      partial: (fallback, error) =>
                          _buildFallback(fallback, error, theme),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              images: widget.images,
                              plantName: widget.plantName,
                              diagnosis: _diagnosisForChat(),
                              plantId: widget.plantId,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat),
                      label: const Text('Fragen stellen'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst);
                      },
                      icon: const Icon(Icons.home),
                      label: const Text('Neue Pflanze'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  /// Strukturierte Anzeige: Health-Header, Comparison-Banner, Findings, Recommendations.
  Widget _buildStructured(DiagnosisResult dr, ThemeData theme) {
    final sortedFindings = List<Finding>.from(dr.findings)
      ..sort((a, b) => b.severity.weight.compareTo(a.severity.weight));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HealthHeader(health: dr.overallHealth, summary: dr.summary),

        if (dr.comparisonToPrevious != null &&
            dr.comparisonToPrevious!.isNotEmpty) ...[
          const SizedBox(height: 12),
          ComparisonBanner(comparisonText: dr.comparisonToPrevious!),
        ],

        if (sortedFindings.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Befunde (${sortedFindings.length})',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          ...sortedFindings.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FindingCard(finding: f),
              )),
        ],

        const SizedBox(height: 8),
        RecommendationsCard(recommendations: dr.recommendations),
      ],
    );
  }

  /// Markdown-Fallback bei Parse-Fehler.
  Widget _buildFallback(String fallback, String? error, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Strukturierte Anzeige nicht verfügbar – Roh-Antwort wird gezeigt.',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.medical_services,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Diagnose & Empfehlungen',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                MarkdownBody(
                  data: fallback,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
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
