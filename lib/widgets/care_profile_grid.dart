import 'package:flutter/material.dart';
import '../models/care_profile/care_profile.dart';
import '../models/care_profile/difficulty.dart';
import '../models/care_profile/toxicity.dart';
import 'care_profile_card.dart';
import 'difficulty_meter.dart';

/// Grid-Container der alle Pflege-Karten einer Pflanze anzeigt.
///
/// Zeigt 6 Kategorien in einem 2-Spalten-Grid plus optionale
/// Metazeile mit Schwierigkeit und Giftigkeitshinweis.
class CareProfileGrid extends StatelessWidget {
  final CareProfile careProfile;
  final Difficulty difficulty;
  final Toxicity toxicity;

  const CareProfileGrid({
    super.key,
    required this.careProfile,
    required this.difficulty,
    required this.toxicity,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Metazeile: Schwierigkeit + Giftigkeit
        _MetaRow(difficulty: difficulty, toxicity: toxicity),
        const SizedBox(height: 12),

        // 2-Spalten-Grid der Pflege-Karten
        _buildGrid(),
      ],
    );
  }

  Widget _buildGrid() {
    final cards = [
      (CareCardConfigs.water, careProfile.water),
      (CareCardConfigs.light, careProfile.light),
      (CareCardConfigs.temperature, careProfile.temperature),
      (CareCardConfigs.humidity, careProfile.humidity),
      (CareCardConfigs.fertilizer, careProfile.fertilizer),
      (CareCardConfigs.repotting, careProfile.repotting),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.05,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final (config, item) = cards[index];
        return CareProfileCard(config: config, item: item);
      },
    );
  }
}

/// Metazeile mit Pflegeschwierigkeit und optionalem Giftigkeitshinweis.
class _MetaRow extends StatelessWidget {
  final Difficulty difficulty;
  final Toxicity toxicity;

  const _MetaRow({required this.difficulty, required this.toxicity});

  @override
  Widget build(BuildContext context) {
    final hasToxicity = toxicity.isToxic;

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Schwierigkeit
        if (difficulty != Difficulty.unknown) DifficultyMeter(difficulty: difficulty),

        // Giftigkeitshinweis
        if (hasToxicity) _ToxicityBadge(toxicity: toxicity),
      ],
    );
  }
}

/// Kompakter Giftigkeits-Badge.
class _ToxicityBadge extends StatelessWidget {
  final Toxicity toxicity;

  const _ToxicityBadge({required this.toxicity});

  @override
  Widget build(BuildContext context) {
    final detail = toxicity.detail.isNotEmpty ? toxicity.detail : null;
    final affected = toxicity.affected.isNotEmpty
        ? toxicity.affected.join(', ')
        : null;

    final tooltip = [
      if (affected != null) 'Giftig für: $affected',
      if (detail != null) detail,
    ].join('\n');

    return Tooltip(
      message: tooltip.isNotEmpty ? tooltip : 'Giftig',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFE74C3C).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFE74C3C).withValues(alpha: 0.40),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('☠️', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text(
              affected != null ? 'Giftig für $affected' : 'Giftig',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFFC0392B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
