import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Key für das „nicht mehr zeigen"-Flag in SharedPreferences
const _kHasSeenPhotoTips = 'has_seen_photo_tips';

/// Zeigt das Foto-Tipps-Sheet an, wenn der Nutzer es noch nie gesehen hat
/// (oder [force] = true). Gibt [true] zurück, wenn das Sheet angezeigt wurde.
Future<bool> maybeShowPhotoTipsSheet(BuildContext context,
    {bool force = false}) async {
  final prefs = await SharedPreferences.getInstance();
  final hasSeen = prefs.getBool(_kHasSeenPhotoTips) ?? false;

  if (hasSeen && !force) return false;

  if (!context.mounted) return false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _PhotoTipsSheet(),
  );
  return true;
}

class _PhotoTipsSheet extends StatefulWidget {
  const _PhotoTipsSheet();

  @override
  State<_PhotoTipsSheet> createState() => _PhotoTipsSheetState();
}

class _PhotoTipsSheetState extends State<_PhotoTipsSheet> {
  bool _dontShowAgain = false;

  static const _tips = [
    (icon: '📸', title: 'Nah ran', body: 'Halte die Kamera nah an Blatt oder Blüte, damit Details sichtbar sind.'),
    (icon: '☀️', title: 'Gutes Licht', body: 'Tageslicht oder helle Umgebung – kein Gegenlicht, kein Blitz.'),
    (icon: '🔍', title: 'Scharf stellen', body: 'Tippe auf das Motiv im Sucher, damit der Fokus sitzt.'),
    (icon: '🌿', title: 'Mehrere Winkel', body: 'Mach 2–3 Fotos: Blatt-Oberseite, Unterseite und die ganze Pflanze.'),
  ];

  Future<void> _dismiss() async {
    if (_dontShowAgain) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kHasSeenPhotoTips, true);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Für beste Erkennungsergebnisse',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Ein paar Tipps für ein gutes Foto',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Tipp-Kacheln
            ..._tips.map(
              (tip) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Emoji-Icon-Box
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(tip.icon,
                          style: const TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tip.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tip.body,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // „Nicht mehr zeigen"-Checkbox
            InkWell(
              onTap: () => setState(() => _dontShowAgain = !_dontShowAgain),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Checkbox(
                      value: _dontShowAgain,
                      onChanged: (v) =>
                          setState(() => _dontShowAgain = v ?? false),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Nicht mehr zeigen',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // CTA-Button
            FilledButton(
              onPressed: _dismiss,
              child: const Text('Los geht\'s 🌱'),
            ),
          ],
        ),
      ),
    );
  }
}
