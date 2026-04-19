import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/api_key_provider.dart';
import '../providers/database_provider.dart';
import '../providers/fertilizer_provider.dart';
import '../services/claude_service.dart';
import '../services/database_service.dart';
import 'chat_screen.dart';

class DiagnosisScreen extends ConsumerStatefulWidget {
  final List<File> images;
  final String plantName;
  final String? plantId;

  const DiagnosisScreen({
    super.key,
    required this.images,
    required this.plantName,
    this.plantId,
  });

  @override
  ConsumerState<DiagnosisScreen> createState() => _DiagnosisScreenState();
}

class _DiagnosisScreenState extends ConsumerState<DiagnosisScreen> {
  String? _result;
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
    });

    try {
      final apiKey = ref.read(apiKeyProvider).value;
      if (apiKey == null) throw Exception('Kein API Key');

      final service = ClaudeService(apiKey);
      final fertilizers = ref.read(fertilizersProvider);
      final result = await service.diagnosePlant(
        images: widget.images,
        plantName: widget.plantName,
        availableFertilizers: fertilizers.isNotEmpty ? fertilizers : null,
      );
      setState(() => _result = result);

      // Save diagnosis to plant if linked
      if (widget.plantId != null) {
        final plant =
            DatabaseService.instance.getPlant(widget.plantId!);
        if (plant != null) {
          plant.diagnosisResult = result;
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
                  if (_result != null) ...[
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
                                  style:
                                      theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SelectableText(
                              _result!,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              images: widget.images,
                              plantName: widget.plantName,
                              diagnosis: _result!,
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
}
