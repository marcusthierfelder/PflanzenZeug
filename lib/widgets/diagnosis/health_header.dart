import 'package:flutter/material.dart';
import '../../models/diagnosis/diagnosis_result.dart';

/// Großer Status-Header: Icon + Farbe + Health-Label + Summary.
class HealthHeader extends StatelessWidget {
  final OverallHealth health;
  final String summary;

  const HealthHeader({
    super.key,
    required this.health,
    required this.summary,
  });

  static IconData _iconFor(OverallHealth health) => switch (health) {
        OverallHealth.good => Icons.check_circle,
        OverallHealth.fair => Icons.info,
        OverallHealth.poor => Icons.warning_amber,
        OverallHealth.critical => Icons.dangerous,
      };

  static Color _colorFor(OverallHealth health, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return switch (health) {
      OverallHealth.good => isDark
          ? const Color(0xFF81C784) // lighter green for dark
          : const Color(0xFF388E3C),
      OverallHealth.fair => isDark
          ? const Color(0xFF64B5F6) // lighter blue for dark
          : const Color(0xFF1976D2),
      OverallHealth.poor => isDark
          ? const Color(0xFFFFB74D) // lighter orange for dark
          : const Color(0xFFF57C00),
      OverallHealth.critical => isDark
          ? const Color(0xFFEF5350) // lighter red for dark
          : const Color(0xFFD32F2F),
    };
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = _colorFor(health, brightness);
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_iconFor(health), color: color, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gesundheitszustand',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      health.label,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              summary,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}
