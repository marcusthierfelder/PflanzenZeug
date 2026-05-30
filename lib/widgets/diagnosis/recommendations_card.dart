import 'package:flutter/material.dart';
import '../../models/diagnosis/recommendations.dart';

/// Strukturierte Karte mit allen Pflegeempfehlungen.
class RecommendationsCard extends StatelessWidget {
  final Recommendations recommendations;

  const RecommendationsCard({super.key, required this.recommendations});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Sammle alle Empfehlungen die nicht leer sind
    final items = <_RecommendationItem>[];

    if (recommendations.watering.isNotEmpty) {
      items.add(_RecommendationItem(
        icon: Icons.water_drop,
        label: 'Gießen',
        text: recommendations.watering,
        color: const Color(0xFF1565C0),
      ));
    }

    if (recommendations.fertilizer.advice.isNotEmpty) {
      final text = recommendations.fertilizer.product != null
          ? '${recommendations.fertilizer.advice}\n→ ${recommendations.fertilizer.product}'
          : recommendations.fertilizer.advice;
      items.add(_RecommendationItem(
        icon: Icons.eco,
        label: 'Düngen',
        text: text,
        color: const Color(0xFF2E7D32),
      ));
    }

    if (recommendations.location.isNotEmpty) {
      items.add(_RecommendationItem(
        icon: Icons.place,
        label: 'Standort',
        text: recommendations.location,
        color: const Color(0xFFF57C00),
      ));
    }

    for (final other in recommendations.other) {
      items.add(_RecommendationItem(
        icon: Icons.tips_and_updates,
        label: 'Tipp',
        text: other,
        color: const Color(0xFF6A1B9A),
      ));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.checklist,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Empfehlungen',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map((item) => _buildItem(item, theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(_RecommendationItem item, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(item.icon, color: item.color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.text,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationItem {
  final IconData icon;
  final String label;
  final String text;
  final Color color;

  const _RecommendationItem({
    required this.icon,
    required this.label,
    required this.text,
    required this.color,
  });
}
