import 'dart:async';
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
          'Achte genau auf Blattform, Blattanordnung, Blüten, Wuchsform und Wurzeln.\n\n'
          'Antworte EXAKT in diesem Format:\n'
          'NAME: <Deutscher Pflanzenname>\n'
          'WISSENSCHAFTLICH: <Gattung Art>\n\n'
          '<Weitere Details zur Pflanze, Beschreibung, Pflegehinweise etc.>\n\n'
          'Wenn du dir nicht sicher bist, gib die 2-3 wahrscheinlichsten '
          'Kandidaten mit geschätzter Wahrscheinlichkeit an. '
          'Antworte auf Deutsch, kurz und präzise.',
    });

    return _callClaude(imageContents);
  }

  Future<String> diagnosePlant({
    required List<File> images,
    required String plantName,
    String? location,
    String? potInfo,
    String? previousDiagnosis,
    List<File>? historicalImages,
    List<Fertilizer>? availableFertilizers,
  }) async {
    final imageContents = <Map<String, dynamic>>[];

    // Historische Fotos zuerst senden (ältere Aufnahmen als Kontext)
    if (historicalImages != null && historicalImages.isNotEmpty) {
      imageContents.addAll(_encodeImages(historicalImages));
      imageContents.add({
        'type': 'text',
        'text': '⬆️ Das sind ältere Fotos der Pflanze zum Vergleich.',
      });
    }

    // Aktuelle Fotos
    imageContents.addAll(_encodeImages(images));

    var promptText =
        'Diese Pflanze wurde als "$plantName" identifiziert.\n\n';

    // Standort- und Topf-Kontext
    if ((location != null && location.isNotEmpty) ||
        (potInfo != null && potInfo.isNotEmpty)) {
      promptText += '**Aktuelle Bedingungen:**\n';
      if (location != null && location.isNotEmpty) {
        promptText += '- Standort: $location\n';
      }
      if (potInfo != null && potInfo.isNotEmpty) {
        promptText += '- Topf: $potInfo\n';
      }
      promptText += '\n';
    }

    // Frühere Diagnose als Kontext
    if (previousDiagnosis != null && previousDiagnosis.isNotEmpty) {
      promptText += '**Letzte Diagnose:**\n$previousDiagnosis\n\n'
          'Berücksichtige die letzte Diagnose und erkenne '
          'Veränderungen (Verbesserung oder Verschlechterung).\n\n';
    }

    if (historicalImages != null && historicalImages.isNotEmpty) {
      promptText += 'Die älteren Fotos oben zeigen den früheren Zustand. '
          'Vergleiche mit den aktuellen Fotos und beschreibe Veränderungen.\n\n';
    }

    promptText +=
        'Bitte analysiere die aktuellen Bilder und beantworte auf Deutsch:\n\n'
        '1. **Gesundheitszustand**: Wie sieht die Pflanze aus? Gibt es sichtbare Probleme?\n'
        '2. **Krankheiten**: Erkennst du Anzeichen von Krankheiten? Wenn ja, welche?\n'
        '3. **Mangelerscheinungen**: Gibt es Anzeichen für Nährstoffmangel (z.B. Stickstoff, Eisen, Kalium)?\n'
        '4. **Schädlinge**: Siehst du Anzeichen von Schädlingsbefall?\n'
        '5. **Veränderungen**: Hat sich der Zustand im Vergleich zu früheren Fotos/Diagnosen verändert?\n'
        '6. **Empfehlungen**: Was sollte der Besitzer tun?\n'
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
    int maxTokens = 2048,
  }) async {
    final http.Response response;
    try {
      response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': 'claude-sonnet-4-20250514',
          'max_tokens': maxTokens,
          'system': systemPrompt ?? _defaultSystemPrompt,
          'messages': messages,
        }),
      ).timeout(const Duration(seconds: 120));
    } on TimeoutException {
      throw Exception(
        'Die Anfrage hat zu lange gedauert. Bitte versuche es erneut.',
      );
    } on SocketException {
      throw Exception(
        'Keine Internetverbindung. Bitte prüfe deine Verbindung.',
      );
    }

    if (response.statusCode == 401) {
      throw Exception('Ungültiger API-Key. Bitte prüfe deinen Schlüssel.');
    }
    if (response.statusCode == 429) {
      throw Exception('Zu viele Anfragen. Bitte warte einen Moment.');
    }
    if (response.statusCode != 200) {
      String message = 'API-Fehler (${response.statusCode})';
      try {
        final error = jsonDecode(response.body);
        message = error['error']?['message'] as String? ?? message;
      } catch (_) {}
      throw Exception(message);
    }

    final data = jsonDecode(response.body);
    final textBlocks = (data['content'] as List)
        .where((block) => block['type'] == 'text')
        .map((block) => block['text'] as String)
        .join('\n');
    if (textBlocks.isEmpty) {
      throw Exception('Keine Antwort von Claude erhalten.');
    }
    return textBlocks;
  }
}
