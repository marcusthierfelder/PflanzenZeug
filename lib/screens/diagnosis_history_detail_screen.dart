import 'dart:io';
import 'package:flutter/material.dart';
import '../models/diagnosis/diagnosis_entry.dart';
import '../models/diagnosis/diagnosis_result.dart';
import '../models/diagnosis/finding.dart';
import '../services/database_service.dart';
import '../widgets/diagnosis/finding_card.dart';
import '../widgets/diagnosis/health_header.dart';
import '../widgets/diagnosis/recommendations_card.dart';

/// Detail-Ansicht für einen einzelnen historischen Diagnose-Eintrag.
///
/// Wiederverwendet die bewährten Diagnose-Widgets (HealthHeader, FindingCard,
/// RecommendationsCard) und zeigt zusätzlich Metadaten (Datum, Kontext-Tag,
/// verwendete Fotos).
class DiagnosisHistoryDetailScreen extends StatelessWidget {
  final DiagnosisEntry entry;

  const DiagnosisHistoryDetailScreen({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    DiagnosisResult? dr;
    String? parseError;
    try {
      dr = entry.diagnosisResult;
    } catch (e) {
      parseError = e.toString();
    }

    final sortedFindings = dr != null
        ? (List<Finding>.from(dr.findings)
          ..sort((a, b) => b.severity.weight.compareTo(a.severity.weight)))
        : <Finding>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnose-Detail'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _HealthBadge(health: entry.overallHealth),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Datum & Metadaten
            _MetaCard(entry: entry, theme: theme),

            const SizedBox(height: 12),

            // Health-Header
            if (dr != null)
              HealthHeader(health: dr.overallHealth, summary: dr.summary)
            else
              _ErrorCard(parseError: parseError, theme: theme),

            // Fotos der Diagnose-Session
            if (entry.photoPaths.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Verwendete Fotos',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              _PhotoStrip(photoPaths: entry.photoPaths),
            ],

            // Befunde
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

            // Empfehlungen
            if (dr != null) ...[
              const SizedBox(height: 8),
              RecommendationsCard(recommendations: dr.recommendations),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

/// Metadaten-Karte: Datum, Uhrzeit und optionaler Kontext-Tag.
class _MetaCard extends StatelessWidget {
  final DiagnosisEntry entry;
  final ThemeData theme;

  const _MetaCard({required this.entry, required this.theme});

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun',
      'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez',
    ];
    return '${dt.day}. ${months[dt.month - 1]} ${dt.year}  '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} Uhr';
  }

  String? _contextTagLabel(String? tag) {
    if (tag == null) return null;
    return switch (tag) {
      'leaf' => '🌿 Blätter',
      'root' => '🌱 Wurzeln',
      'flower' => '🌸 Blüten',
      'custom' => '✏️ Eigenes',
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final tagLabel = _contextTagLabel(entry.contextTag);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _formatDate(entry.createdAt),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            if (tagLabel != null) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tagLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Horizontaler Foto-Streifen der Diagnose-Session.
class _PhotoStrip extends StatelessWidget {
  final List<String> photoPaths;

  const _PhotoStrip({required this.photoPaths});

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService.instance;

    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photoPaths.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final resolved = db.resolveImagePath(photoPaths[index]);
          final file = File(resolved);
          return GestureDetector(
            onTap: () => _showFullImage(context, file),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: file.existsSync()
                  ? Image.file(
                      file,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 80,
                      height: 80,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.image_not_supported,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }

  void _showFullImage(BuildContext context, File file) {
    if (!file.existsSync()) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.file(file),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fehler-Karte wenn DiagnosisResult nicht geparsed werden konnte.
class _ErrorCard extends StatelessWidget {
  final String? parseError;
  final ThemeData theme;

  // ignore: unused_element
  const _ErrorCard({required this.parseError, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.warning_amber, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Diagnose-Daten konnten nicht geladen werden.',
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kleines Health-Badge für die AppBar.
class _HealthBadge extends StatelessWidget {
  final OverallHealth health;

  const _HealthBadge({required this.health});

  Color _color(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    if (health == OverallHealth.good) {
      return isDark ? const Color(0xFF81C784) : const Color(0xFF388E3C);
    } else if (health == OverallHealth.fair) {
      return isDark ? const Color(0xFF64B5F6) : const Color(0xFF1976D2);
    } else if (health == OverallHealth.poor) {
      return isDark ? const Color(0xFFFFB74D) : const Color(0xFFF57C00);
    } else {
      return isDark ? const Color(0xFFEF5350) : const Color(0xFFD32F2F);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        health.label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
