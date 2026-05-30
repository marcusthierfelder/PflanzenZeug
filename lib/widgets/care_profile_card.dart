import 'package:flutter/material.dart';
import '../models/care_profile/care_item.dart';

/// Konfiguration für eine Pflege-Karte (Icon, Farbe, Label).
class CareCardConfig {
  final String emoji;
  final Color color;
  final String label;

  const CareCardConfig({
    required this.emoji,
    required this.color,
    required this.label,
  });
}

/// Vordefinierte Konfigurationen für alle Kategorien.
abstract class CareCardConfigs {
  static const water = CareCardConfig(
    emoji: '💧',
    color: Color(0xFF4A90D9),
    label: 'WASSER',
  );
  static const light = CareCardConfig(
    emoji: '☀️',
    color: Color(0xFFF5A623),
    label: 'LICHT',
  );
  static const temperature = CareCardConfig(
    emoji: '🌡️',
    color: Color(0xFFE74C3C),
    label: 'TEMPERATUR',
  );
  static const humidity = CareCardConfig(
    emoji: '💨',
    color: Color(0xFF7FB3D3),
    label: 'LUFTFEUCHTE',
  );
  static const fertilizer = CareCardConfig(
    emoji: '🌱',
    color: Color(0xFF27AE60),
    label: 'DÜNGER',
  );
  static const repotting = CareCardConfig(
    emoji: '🪴',
    color: Color(0xFF8D6E63),
    label: 'UMTOPFEN',
  );
}

/// Eine einzelne Pflege-Karte mit ausklappbarem Detailtext.
///
/// Zeigt: Icon + Kategoriename + Kurzwert + aufklappbaren Detailtext.
class CareProfileCard extends StatefulWidget {
  final CareCardConfig config;
  final CareItem item;

  const CareProfileCard({
    super.key,
    required this.config,
    required this.item,
  });

  @override
  State<CareProfileCard> createState() => _CareProfileCardState();
}

class _CareProfileCardState extends State<CareProfileCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final item = widget.item;
    final hasDetail = item.detail.isNotEmpty;

    return Card(
      elevation: 0,
      color: const Color(0xFFFFFFFF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: config.color.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: hasDetail ? () => setState(() => _expanded = !_expanded) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Kopfzeile: Icon + Label
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: config.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      config.emoji,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      config.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: config.color,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  if (hasDetail)
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 200),
                      turns: _expanded ? 0.5 : 0,
                      child: Icon(
                        Icons.expand_more,
                        size: 18,
                        color: config.color.withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // Kurzwert
              Text(
                item.shortValue,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              // Detailtext (Accordion)
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    item.detail,
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
