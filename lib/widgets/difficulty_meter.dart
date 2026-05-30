import 'package:flutter/material.dart';
import '../models/care_profile/difficulty.dart';

/// Ampel-Widget für die Pflegeschwierigkeit.
///
/// Zeigt drei Kreise (Einfach / Mittel / Anspruchsvoll) in Ampelfarben.
/// Der aktive Level leuchtet auf, inaktive sind gedimmt.
class DifficultyMeter extends StatelessWidget {
  final Difficulty difficulty;

  const DifficultyMeter({super.key, required this.difficulty});

  @override
  Widget build(BuildContext context) {
    if (difficulty == Difficulty.unknown) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star, size: 14, color: const Color(0xFFF39C12)),
        const SizedBox(width: 4),
        Text(
          'Schwierigkeit: ',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF666666),
          ),
        ),
        _dot(
          color: const Color(0xFF27AE60),
          active: difficulty == Difficulty.easy ||
              difficulty == Difficulty.medium ||
              difficulty == Difficulty.hard,
          label: 'Einfach',
        ),
        const SizedBox(width: 4),
        _dot(
          color: const Color(0xFFF5A623),
          active: difficulty == Difficulty.medium ||
              difficulty == Difficulty.hard,
          label: 'Mittel',
        ),
        const SizedBox(width: 4),
        _dot(
          color: const Color(0xFFE74C3C),
          active: difficulty == Difficulty.hard,
          label: 'Anspruchsvoll',
        ),
        const SizedBox(width: 6),
        Text(
          difficulty.label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _labelColor(difficulty),
          ),
        ),
      ],
    );
  }

  Widget _dot({
    required Color color,
    required bool active,
    required String label,
  }) {
    return Tooltip(
      message: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? color : color.withValues(alpha: 0.2),
          border: Border.all(
            color: active ? color : color.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
      ),
    );
  }

  Color _labelColor(Difficulty d) => switch (d) {
        Difficulty.easy => const Color(0xFF27AE60),
        Difficulty.medium => const Color(0xFFF5A623),
        Difficulty.hard => const Color(0xFFE74C3C),
        Difficulty.unknown => const Color(0xFF999999),
      };
}
