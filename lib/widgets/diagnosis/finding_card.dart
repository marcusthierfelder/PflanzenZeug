import 'package:flutter/material.dart';
import '../../models/diagnosis/finding.dart';

/// Ausklappbare Severity-Karte für einen einzelnen Befund.
///
/// - Linker Rand: 4px farbig (Severity-Farbe)
/// - Hintergrund: ~8% Alpha Tint der Severity-Farbe
/// - Titel + Type-Icon + Severity-Label immer sichtbar
/// - Evidence + Treatment ausklappbar
class FindingCard extends StatefulWidget {
  final Finding finding;

  const FindingCard({super.key, required this.finding});

  @override
  State<FindingCard> createState() => _FindingCardState();
}

class _FindingCardState extends State<FindingCard> {
  bool _expanded = false;

  static Color _severityColor(Severity severity, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return switch (severity) {
      Severity.high =>
        isDark ? const Color(0xFFEF5350) : const Color(0xFFD32F2F),
      Severity.medium =>
        isDark ? const Color(0xFFFFB74D) : const Color(0xFFF57C00),
      Severity.low =>
        isDark ? const Color(0xFFFFD54F) : const Color(0xFFFBC02D),
    };
  }

  static IconData _typeIcon(FindingType type) => switch (type) {
        FindingType.disease => Icons.coronavirus,
        FindingType.pest => Icons.bug_report,
        FindingType.deficiency => Icons.science,
        FindingType.environmental => Icons.wb_sunny,
      };

  static Color _typeColor(FindingType type, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return switch (type) {
      FindingType.disease =>
        isDark ? const Color(0xFFEF5350) : const Color(0xFFC62828),
      FindingType.pest =>
        isDark ? const Color(0xFFFFB74D) : const Color(0xFFE65100),
      FindingType.deficiency =>
        isDark ? const Color(0xFF64B5F6) : const Color(0xFF1565C0),
      FindingType.environmental =>
        isDark ? const Color(0xFFFFD54F) : const Color(0xFFF57F17),
    };
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final severityColor =
        _severityColor(widget.finding.severity, brightness);
    final typeColor = _typeColor(widget.finding.type, brightness);
    final theme = Theme.of(context);

    final hasDetails = widget.finding.evidence.isNotEmpty ||
        widget.finding.treatment.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: severityColor.withValues(alpha: 0.08),
          border: Border(
            left: BorderSide(color: severityColor, width: 4),
          ),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(8),
            bottomRight: Radius.circular(8),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Immer sichtbarer Header
            InkWell(
              onTap: hasDetails
                  ? () => setState(() => _expanded = !_expanded)
                  : null,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  children: [
                    // Type-Icon mit Semantik-Label (Accessibility)
                    Tooltip(
                      message: widget.finding.type.label,
                      child: Icon(
                        _typeIcon(widget.finding.type),
                        color: typeColor,
                        size: 20,
                        semanticLabel: widget.finding.type.label,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.finding.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              // Type-Label (Text für Accessibility)
                              Text(
                                widget.finding.type.label,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: typeColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Severity-Chip
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: severityColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: severityColor.withValues(alpha: 0.4),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  widget.finding.severity.label,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: severityColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (hasDetails)
                      Icon(
                        _expanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                  ],
                ),
              ),
            ),

            // Ausklappbarer Detail-Bereich
            if (_expanded && hasDetails)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Divider(
                      height: 1,
                      color: severityColor.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: 8),
                    if (widget.finding.evidence.isNotEmpty) ...[
                      _DetailRow(
                        icon: Icons.search,
                        label: 'Befund',
                        text: widget.finding.evidence,
                        theme: theme,
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (widget.finding.treatment.isNotEmpty)
                      _DetailRow(
                        icon: Icons.healing,
                        label: 'Behandlung',
                        text: widget.finding.treatment,
                        theme: theme,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String text;
  final ThemeData theme;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.text,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 14,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                text,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
