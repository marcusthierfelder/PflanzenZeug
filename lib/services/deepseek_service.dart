import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/diagnosis/diagnosis_result.dart';
import '../models/fertilizer.dart';
import '../services/parsers/diagnosis_parser.dart';
import '../services/parsers/parse_result.dart';
import 'ai_service.dart';
import 'image_optimizer.dart';
import 'prompts/diagnosis_schema.dart';
import 'prompts/plant_care_schema.dart';

const _defaultSystemPrompt =
    'Du bist ein Pflanzenexperte. Antworte immer auf Deutsch. '
    'Sei konkret und praxisnah.';

class DeepSeekService implements AIService {
  final String apiKey;

  DeepSeekService(this.apiKey);

  /// Optimiert alle Bilder (max 1280px, JPEG 80 %) und kodiert sie als Base64.
  Future<List<Map<String, dynamic>>> _encodeImages(List<File> images) async {
    final result = <Map<String, dynamic>>[];
    for (final image in images) {
      final optimized = await ImageOptimizer.optimize(image);
      final bytes = await optimized.readAsBytes();
      final base64Image = base64Encode(bytes);
      const mediaType = 'image/jpeg';
      result.add({
        'type': 'image_url',
        'image_url': {'url': 'data:$mediaType;base64,$base64Image'},
      });
    }
    return result;
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
  Future<String> identifyPlant(
    List<File> images, {
    bool isMixedPot = false,
    String? previousIdentification,
  }) async {
    final content = <Map<String, dynamic>>[...await _encodeImages(images)];

    final promptText = PlantCareSchema.buildIdentifyPromptDeepSeek(
      imageCount: images.length,
      isMixedPot: isMixedPot,
    );

    // Re-Identifikations-Kontext anhängen wenn Pflanze bereits bekannt ist
    final fullPrompt = previousIdentification != null
        ? '$promptText\n\n'
          '⚠️ RE-IDENTIFIKATION: Diese Pflanze wurde zuvor als '
          '**$previousIdentification** identifiziert. '
          'Bestätige oder widerlege diese Bestimmung anhand der '
          'diagnostischen Merkmale auf den Fotos. '
          'Wechsele die Art nur bei klarem Widerspruch zu den sichtbaren '
          'Merkmalen. Begründe deine Entscheidung im Feld '
          '"diagnostic_notes".'
        : promptText;

    content.add({'type': 'text', 'text': fullPrompt});
    // DeepSeek unterstützt response_format: json_object nativ
    return _call(
      [{'role': 'user', 'content': content}],
      forceJsonMode: true,
      maxTokens: 3000,
    );
  }

  @override
  Future<ParseResult<DiagnosisResult>> diagnosePlant({
    required List<File> images,
    required String plantName,
    String? location,
    String? potInfo,
    bool isMixedPot = false,
    String? previousDiagnosis,
    List<File>? historicalImages,
    List<Fertilizer>? availableFertilizers,
    String? speciesNotes,
    String? userContext,
  }) async {
    final content = <Map<String, dynamic>>[];

    if (historicalImages != null && historicalImages.isNotEmpty) {
      content.addAll(await _encodeImages(historicalImages));
      content.add({
        'type': 'text',
        'text': '⬆️ Das sind ältere Fotos der Pflanze zum Vergleich.',
      });
    }
    content.addAll(await _encodeImages(images));

    // Fertilizernames für Prompt
    final fertilizerNames = availableFertilizers
            ?.map((f) =>
                '${f.name}${f.npkRatio != null ? ' (NPK: ${f.npkRatio})' : ''}')
            .toList() ??
        [];

    final prompt = DiagnosisSchema.buildDeepSeekPrompt(
      plantName: plantName,
      location: location,
      potInfo: potInfo,
      isMixedPot: isMixedPot,
      previousDiagnosis: previousDiagnosis,
      hasHistoricalImages:
          historicalImages != null && historicalImages.isNotEmpty,
      availableFertilizerNames: fertilizerNames,
      speciesNotes: speciesNotes,
      userContext: userContext,
    );

    content.add({'type': 'text', 'text': prompt});

    final raw = await _call(
      [{'role': 'user', 'content': content}],
      forceJsonMode: true,
      maxTokens: 3000,
    );

    return DiagnosisParser.parse(raw);
  }

  @override
  Future<String> identifyFertilizer(List<File> images) async {
    final content = <Map<String, dynamic>>[...await _encodeImages(images)];
    content.add({
      'type': 'text',
      'text': 'Analysiere dieses Düngerprodukt anhand der Fotos. Antworte immer auf Deutsch:\n\n'
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
    if (identificationResult != null) {
      prompt += 'Identifikation:\n$identificationResult\n\n';
    }
    if (diagnosisResult != null) {
      prompt += 'Diagnose:\n$diagnosisResult\n\n';
    }
    prompt +=
        'Schlage einen Pflege-Plan vor. Antworte NUR mit diesem JSON-Format, ohne weiteren Text:\n'
        '{"watering_interval_days": <Zahl>, "fertilizing_interval_days": <Zahl>, "notes": "<kurze Hinweise auf Deutsch>"}';

    return _call([{'role': 'user', 'content': prompt}]);
  }

  Future<String> _call(
    List<Map<String, dynamic>> messages, {
    bool includeSystem = true,
    int maxTokens = 2048,
    bool forceJsonMode = false,
  }) async {
    final body = <String, dynamic>{
      'model': 'deepseek-chat',
      'max_tokens': maxTokens,
      'temperature': 0,
      'messages': includeSystem
          ? [
              {'role': 'system', 'content': _defaultSystemPrompt},
              ...messages,
            ]
          : messages,
      if (forceJsonMode) 'response_format': {'type': 'json_object'},
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
      throw Exception(
          'Die Anfrage hat zu lange gedauert. Bitte versuche es erneut.');
    } on SocketException {
      throw Exception(
          'Keine Internetverbindung. Bitte prüfe deine Verbindung.');
    }

    if (response.statusCode == 401) {
      throw Exception(
          'Ungültiger DeepSeek API-Key. Bitte prüfe deinen Schlüssel.');
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
