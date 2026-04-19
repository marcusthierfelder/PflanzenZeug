import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/fertilizer.dart';

const _defaultSystemPrompt =
    'Du bist ein Pflanzenexperte. Antworte immer auf Deutsch. '
    'Sei konkret und praxisnah.';

class ClaudeService {
  final String apiKey;

  ClaudeService(this.apiKey);

  List<Map<String, dynamic>> _encodeImages(List<File> images) {
    final contents = <Map<String, dynamic>>[];
    for (final image in images) {
      final bytes = image.readAsBytesSync();
      final base64Image = base64Encode(bytes);
      final extension = image.path.split('.').last.toLowerCase();
      final mediaType = switch (extension) {
        'png' => 'image/png',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };

      contents.add({
        'type': 'image',
        'source': {
          'type': 'base64',
          'media_type': mediaType,
          'data': base64Image,
        },
      });
    }
    return contents;
  }

  static String _fertilizerContext(List<Fertilizer> fertilizers) {
    final lines = fertilizers
        .map((f) =>
            '- ${f.name}${f.npkRatio != null ? ' (NPK: ${f.npkRatio})' : ''}'
            '${f.brand != null ? ' von ${f.brand}' : ''}')
        .join('\n');
    return '\n\nDer Benutzer hat folgende Dünger verfügbar:\n$lines\n'
        'Empfehle wenn möglich einen der vorhandenen Dünger.';
  }

  Future<String> identifyPlant(List<File> images) async {
    final imageContents = _encodeImages(images);

    imageContents.add({
      'type': 'text',
      'text':
          'Identifiziere diese Pflanze anhand der ${images.length} Fotos. '
          'Achte genau auf Blattform, Blattanordnung, Blüten, Wuchsform und Wurzeln. '
          'Nenne den deutschen Namen und den wissenschaftlichen Namen (Gattung und Art). '
          'Wenn du dir nicht sicher bist, gib die 2-3 wahrscheinlichsten '
          'Kandidaten mit geschätzter Wahrscheinlichkeit an. '
          'Antworte auf Deutsch, kurz und präzise.',
    });

    return _callClaude(imageContents);
  }

  Future<String> diagnosePlant({
    required List<File> images,
    required String plantName,
    List<Fertilizer>? availableFertilizers,
  }) async {
    final imageContents = _encodeImages(images);

    var promptText =
        'Diese Pflanze wurde als "$plantName" identifiziert. '
        'Bitte analysiere die Bilder und beantworte auf Deutsch:\n\n'
        '1. **Gesundheitszustand**: Wie sieht die Pflanze aus? Gibt es sichtbare Probleme?\n'
        '2. **Krankheiten**: Erkennst du Anzeichen von Krankheiten? Wenn ja, welche?\n'
        '3. **Mangelerscheinungen**: Gibt es Anzeichen für Nährstoffmangel (z.B. Stickstoff, Eisen, Kalium)?\n'
        '4. **Schädlinge**: Siehst du Anzeichen von Schädlingsbefall?\n'
        '5. **Empfehlungen**: Was sollte der Besitzer tun?\n'
        '   - Welcher Dünger? (konkreter Vorschlag)\n'
        '   - Gießverhalten ändern?\n'
        '   - Standort ändern?\n'
        '   - Sonstige Maßnahmen?\n\n'
        'Sei konkret und praxisnah in deinen Empfehlungen.';

    if (availableFertilizers != null && availableFertilizers.isNotEmpty) {
      promptText += _fertilizerContext(availableFertilizers);
    }

    imageContents.add({'type': 'text', 'text': promptText});

    return _callClaude(imageContents);
  }

  Future<String> identifyFertilizer(List<File> images) async {
    final imageContents = _encodeImages(images);

    imageContents.add({
      'type': 'text',
      'text':
          'Analysiere dieses Düngerprodukt anhand der Fotos. Antworte auf Deutsch:\n\n'
          '1. **Produktname** und **Marke**\n'
          '2. **NPK-Verhältnis** (Stickstoff-Phosphor-Kalium), z.B. 7-3-6\n'
          '3. **Geeignet für** welche Pflanzen\n'
          '4. **Anwendungshinweise** (Dosierung, Häufigkeit)\n\n'
          'Sei konkret und präzise.',
    });

    return _callClaude(imageContents);
  }

  Future<String> askQuestion({
    required List<Map<String, dynamic>> conversationHistory,
    required String question,
    List<Fertilizer>? availableFertilizers,
  }) async {
    final messages = [
      ...conversationHistory,
      {
        'role': 'user',
        'content': question,
      },
    ];

    String? systemPrompt;
    if (availableFertilizers != null && availableFertilizers.isNotEmpty) {
      systemPrompt = '$_defaultSystemPrompt${_fertilizerContext(availableFertilizers)}';
    }

    return _callClaudeMessages(messages, systemPrompt: systemPrompt);
  }

  Future<String> suggestCareSchedule({
    required String plantName,
    String? identificationResult,
    String? diagnosisResult,
  }) async {
    var prompt =
        'Basierend auf folgenden Infos zur Pflanze "$plantName":\n\n';
    if (identificationResult != null) {
      prompt += 'Identifikation:\n$identificationResult\n\n';
    }
    if (diagnosisResult != null) {
      prompt += 'Diagnose:\n$diagnosisResult\n\n';
    }
    prompt +=
        'Schlage einen Pflege-Plan vor. Antworte NUR mit diesem JSON-Format, ohne weiteren Text:\n'
        '{"watering_interval_days": <Zahl>, "fertilizing_interval_days": <Zahl>, "notes": "<kurze Hinweise auf Deutsch>"}';

    return _callClaudeMessages([
      {'role': 'user', 'content': prompt},
    ]);
  }

  Future<String> _callClaude(List<Map<String, dynamic>> content) async {
    return _callClaudeMessages([
      {
        'role': 'user',
        'content': content,
      },
    ]);
  }

  Future<String> _callClaudeMessages(
    List<Map<String, dynamic>> messages, {
    String? systemPrompt,
  }) async {
    final response = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': 'claude-opus-4-20250514',
        'max_tokens': 2048,
        'system': systemPrompt ?? _defaultSystemPrompt,
        'messages': messages,
      }),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(
        error['error']?['message'] ?? 'API-Fehler (${response.statusCode})',
      );
    }

    final data = jsonDecode(response.body);
    final textBlocks = (data['content'] as List)
        .where((block) => block['type'] == 'text')
        .map((block) => block['text'] as String)
        .join('\n');
    return textBlocks;
  }
}
