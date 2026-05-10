import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/fertilizer.dart';
import '../providers/ai_provider.dart';
import '../providers/fertilizer_provider.dart';
import '../services/database_service.dart';
import 'add_fertilizer_screen.dart';

class FertilizerInventoryScreen extends ConsumerStatefulWidget {
  const FertilizerInventoryScreen({super.key});

  @override
  ConsumerState<FertilizerInventoryScreen> createState() =>
      _FertilizerInventoryScreenState();
}

class _FertilizerInventoryScreenState
    extends ConsumerState<FertilizerInventoryScreen> {
  bool _analyzing = false;
  String? _analyzingName;

  Future<void> _analyzeAll() async {
    final service = ref.read(aiServiceProvider);
    if (service == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Kein API Key konfiguriert. Bitte in den Einstellungen hinterlegen.')),
      );
      return;
    }

    final fertilizers = ref.read(fertilizersProvider);
    final unanalyzed = fertilizers.where((f) => !f.isAnalyzed).toList();
    if (unanalyzed.isEmpty) return;

    setState(() => _analyzing = true);
    try {
      for (final fert in unanalyzed) {
        if (!mounted) break;
        setState(() => _analyzingName = fert.name);

        final images = fert.photoPaths
            .map((p) =>
                File(DatabaseService.instance.resolveImagePath(p)))
            .where((f) => f.existsSync())
            .toList();

        try {
          final result = await service.identifyFertilizer(images);
          fert.description = result;

          final npkMatch =
              RegExp(r'(\d+[-–]\d+[-–]\d+)').firstMatch(result);
          if (npkMatch != null) {
            fert.npkRatio =
                npkMatch.group(1)?.replaceAll('–', '-');
          }

          final lines = result.split('\n');
          if (lines.isNotEmpty) {
            final detected =
                lines.first.replaceAll(RegExp(r'[*#]'), '').trim();
            if (detected.isNotEmpty && detected.length < 60) {
              fert.name = detected;
            }
          }

          fert.brand = _extractBrand(result);

          await DatabaseService.instance.saveFertilizer(fert);
          ref.invalidate(fertilizersProvider);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Fehler bei „${fert.name}": $e')),
            );
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _analyzing = false;
          _analyzingName = null;
        });
      }
    }
  }

  String? _extractBrand(String text) {
    final match = RegExp(r'(?:Marke|Hersteller|Brand)[:\s]+([^\n,]+)',
            caseSensitive: false)
        .firstMatch(text);
    return match?.group(1)?.trim();
  }

  void _showAnalysis(BuildContext context, Fertilizer fert) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(fert.name,
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  fert.description ?? '',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fertilizers = ref.watch(fertilizersProvider);
    final theme = Theme.of(context);
    final unanalyzedCount =
        fertilizers.where((f) => !f.isAnalyzed).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meine Dünger'),
        actions: [
          if (unanalyzedCount > 0)
            _analyzing
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        if (_analyzingName != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            _analyzingName!,
                            style: theme.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  )
                : TextButton.icon(
                    onPressed: _analyzeAll,
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: Text('Analysieren ($unanalyzedCount)'),
                  ),
        ],
      ),
      body: fertilizers.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.science_outlined,
                      size: 80,
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Keine Dünger gespeichert',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Füge deine Dünger hinzu,\ndamit sie bei Empfehlungen\nvorgeschlagen werden.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: fertilizers.length,
              itemBuilder: (context, index) {
                final fert = fertilizers[index];
                final firstPhoto = fert.photoPaths.isNotEmpty
                    ? File(DatabaseService.instance
                        .resolveImagePath(fert.photoPaths.first))
                    : null;
                final photoExists =
                    firstPhoto != null && firstPhoto.existsSync();

                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: fert.isAnalyzed
                        ? () => _showAnalysis(context, fert)
                        : null,
                    child: ListTile(
                      leading: photoExists
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.file(
                                firstPhoto,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                              ),
                            )
                          : const Icon(Icons.science),
                      title: Row(
                        children: [
                          Expanded(child: Text(fert.name)),
                          if (fert.photoPaths.length > 1)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Text(
                                '${fert.photoPaths.length} Fotos',
                                style: theme.textTheme.labelSmall?.copyWith(
                                    color:
                                        theme.colorScheme.onSurfaceVariant),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Row(
                        children: [
                          Expanded(
                            child: Text([
                              if (fert.brand != null) fert.brand!,
                              if (fert.npkRatio != null)
                                'NPK: ${fert.npkRatio!}',
                            ].join(' — ')),
                          ),
                          if (!fert.isAnalyzed)
                            Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.tertiaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'nicht analysiert',
                                style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme
                                        .onTertiaryContainer),
                              ),
                            ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await DatabaseService.instance
                              .deleteFertilizer(fert.id);
                          ref.invalidate(fertilizersProvider);
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddFertilizerScreen()),
          );
          ref.invalidate(fertilizersProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('Dünger hinzufügen'),
      ),
    );
  }
}
