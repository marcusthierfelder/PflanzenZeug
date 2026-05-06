import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/fertilizer.dart';
import 'ai_service.dart';

const _defaultSystemPrompt =
    'Du bist ein Pflanzenexperte. Antworte immer auf Deutsch. '
    'Sei konkret und praxisnah.';

class DeepSeekService implements AIService {
  final String apiKey;

  DeepSeekService(this.apiKey);

  List<Map<String, dynamic>> _encodeImages(List<File> images) {
    return images.map((image) {
      final bytes = image.readAsBytesSync();
      final base64Image = base64Encode(bytes);
      final extension = image.path.split('.').last.toLowerCase();
      final mediaType = switch (extension) {
        'png' => 'image/png',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      return {
        'type': 'image_url',
        'image_url': {'url': 'data:$mediaType;base64,$base64Image'},
      };
    }).toList();
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

  @override
  Future<String> identifyPlant(List<File> images, {bool isMixedPot = false}) async {
    final content = <Map<String, dynamic>>[..._encodeImages(images)];

    final promptText = isMixedPot
        ? 'In diesem Topf wachsen MEHRERE Pflanzen zusammen. '
            'Identifiziere ALLE sichtbaren Arten anhand der ${images.length} Fotos.\n\n'
            'Antworte EXAKT in diesem Format:\n'
            'NAME: Mischtopf: <Art 1> & <Art 2>[ & ...]\n'
            'WISSENSCHAFTLICH: <Gattung Art 1>, <Gattung Art 2>[, ...]\n\n'
            'PFLANZEN:\n'
            '1. <Deutscher Name> (<Gattung Art>) — kurze Beschreibung\n'
            '2. ...\n\n'
            'Beachte beim Beschreiben mögliche Konflikte zwischen den Arten. '
            'Antworte auf Deutsch, kurz und präzise.'
        : 'Identifiziere diese Pflanze anhand der ${images.length} Fotos. '
            'Achte genau auf Blattform, Blattanordnung, Blüten, Wuchsform und Wurzeln.\n\n'
            'Antworte EXAKT in diesem Format:\n'
            'NAME: <Deutscher Pflanzenname>\n'
            'WISSENSCHAFTLICH: <Gattung Art>\n\n'
            '<Weitere Details zur Pflanze, Beschreibung, Pflegehinweise etc.>\n\n'
            'Wenn du dir nicht sicher bist, gib die 2-3 wahrscheinlichsten '
            'Kandidaten mit geschätzter Wahrscheinlichkeit an. '
            'Antworte auf Deutsch, kurz und präzise.';

    content.add({'type': 'text', 'text': promptText});
    return _call([{'role': 'user', 'content': content}]);
  }

  @override
  Future<String> diagnosePlant({
    required List<File> images,
    required String plantName,
    String? location,
    String? potInfo,
    bool isMixedPot = false,
    String? previousDiagnosis,
    List<File>? historicalImages,
    List<Fertilizer>? availableFertilizers,
  }) async {
    final content = <Map<String, dynamic>>[];

    if (historicalImages != null && historicalImages.isNotEmpty) {
      content.addAll(_encodeImages(historicalImages));
      content.add({'type': 'text', 'text': '⬆️ Das sind ältere Fotos der Pflanze zum Vergleich.'});
    }
    content.addAll(_encodeImages(images));

    var prompt = isMixedPot
        ? 'In diesem Topf wachsen MEHRERE Pflanzen zusammen, identifiziert als "$plantName". '
            'Analysiere ALLE Arten gemeinsam.\n\n'
        : 'Diese Pflanze wurde als "$plantName" identifiziert.\n\n';

    if ((location != null && location.isNotEmpty) || (potInfo != null && potInfo.isNotEmpty)) {
      prompt += '**Aktuelle Bedingungen:**\n';
      if (location != null && location.isNotEmpty) prompt += '- Standort: $location\n';
      if (potInfo != null && potInfo.isNotEmpty) prompt += '- Topf: $potInfo\n';
      prompt += '\n';
    }
    if (previousDiagnosis != null && previousDiagnosis.isNotEmpty) {
      prompt += '**Letzte Diagnose:**\n$previousDiagnosis\n\n'
          'Berücksichtige die letzte Diagnose und erkenne Veränderungen.\n\n';
    }
    if (historicalImages != null && historicalImages.isNotEmpty) {
      prompt += 'Die älteren Fotos oben zeigen den früheren Zustand. '
          'Vergleiche mit den aktuellen Fotos.\n\n';
    }

    prompt += 'Bitte analysiere die aktuellen Bilder und beantworte auf Deutsch:\n\n'
        '1. **Gesundheitszustand**: Wie sieht die Pflanze aus?\n'
        '2. **Krankheiten**: Erkennst du Anzeichen von Krankheiten?\n'
        '3. **Mangelerscheinungen**: Nährstoffmangel?\n'
        '4. **Schädlinge**: Schädlingsbefall?\n'
        '5. **Veränderungen**: Vergleich zu früheren Fotos/Diagnosen?\n'
        '6. **Empfehlungen**: Dünger, Gießverhalten, Standort?\n\n'
        'Sei konkret und praxisnah.';

    if (availableFertilizers != null && availableFertilizers.isNotEmpty) {
      prompt += _fertilizerContext(availableFertilizers);
    }

    content.add({'type': 'text', 'text': prompt});
    return _call([{'role': 'user', 'content': content}]);
  }

  @override
  Future<String> identifyFertilizer(List<File> images) async {
    final content = <Map<String, dynamic>>[..._encodeImages(images)];
    content.add({
      'type': 'text',
      'text': 'Analysiere dieses Düngerprodukt anhand der Fotos. Antworte auf Deutsch:\n\n'
          '1. **Produktname** und **Marke**\n'
          '2. **NPK-Verhältnis**\n'
          '3. **Geeignet für** welche Pflanzen\n'
          '4. **Anwendungshinweise**\n\n'
          'Sei konkret und präzise.',
    });
    return _call([{'role': 'user', 'content': content}]);
  }

  @override
  Future<String> askQuestion({
    required List<Map<String, dynamic>> conversationHistory,
    required String question,
    List<Fertilizer>? availableFertilizers,
  }) async {
    String system = _defaultSystemPrompt;
    if (availableFertilizers != null && availableFertilizers.isNotEmpty) {
      system += _fertilizerContext(availableFertilizers);
    }
    final messages = [
      {'role': 'system', 'content': system},
      ...conversationHistory,
      {'role': 'user', 'content': question},
    ];
    return _call(messages, includeSystem: false);
  }

  @override
  Future<String> suggestCareSchedule({
    required String plantName,
    String? identificationResult,
    String? diagnosisResult,
  }) async {
    var prompt = 'Basierend auf folgenden Infos zur Pflanze "$plantName":\n\n';
    if (identificationResult != null) prompt += 'Identifikation:\n$identificationResult\n\n';
    if (diagnosisResult != null) prompt += 'Diagnose:\n$diagnosisResult\n\n';
    prompt += 'Schlage einen Pflege-Plan vor. Antworte NUR mit diesem JSON-Format, ohne weiteren Text:\n'
        '{"watering_interval_days": <Zahl>, "fertilizing_interval_days": <Zahl>, "notes": "<kurze Hinweise auf Deutsch>"}';

    return _call([{'role': 'user', 'content': prompt}]);
  }

  Future<String> _call(
    List<Map<String, dynamic>> messages, {
    bool includeSystem = true,
    int maxTokens = 2048,
  }) async {
    final body = <String, dynamic>{
      'model': 'deepseek-chat',
      'max_tokens': maxTokens,
      'messages': includeSystem
          ? [{'role': 'system', 'content': _defaultSystemPrompt}, ...messages]
          : messages,
    };

    final http.Response response;
    try {
      response = await http.post(
        Uri.parse('https://api.deepseek.com/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 120));
    } on TimeoutException {
      throw Exception('Die Anfrage hat zu lange gedauert. Bitte versuche es erneut.');
    } on SocketException {
      throw Exception('Keine Internetverbindung. Bitte prüfe deine Verbindung.');
    }

    if (response.statusCode == 401) {
      throw Exception('Ungültiger DeepSeek API-Key. Bitte prüfe deinen Schlüssel.');
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
    final text = data['choices']?[0]?['message']?['content'] as String?;
    if (text == null || text.isEmpty) {
      throw Exception('Keine Antwort von DeepSeek erhalten.');
    }
    return text;
  }
}
