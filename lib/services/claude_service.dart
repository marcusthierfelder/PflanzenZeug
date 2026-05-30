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
    'Du bist ein Pflanzenexperte mit fundiertem Wissen aus Botanik, Landwirtschaft und Gartenbau. '
    'Dein Wissen stützt sich auf einschlägige Standardwerke: Zander Handwörterbuch der Pflanzennamen, '
    'Rothmaler Flora von Deutschland, Plants of the World Online (Kew), Tropicos (Missouri Botanical Garden), '
    'Mengel & Kirkby Principles of Plant Nutrition, Richter Pflanzenkrankheiten und Pflanzenschutz, '
    'Franke Nutzpflanzenkunde, Lüttge/Kluge/Thiel Botanik (Lehrbuch), '
    'sowie Lehrpläne der landwirtschaftlichen Berufsschulen und Fachhochschulen (D/A/CH). '
    'Antworte immer auf Deutsch. Sei konkret und praxisnah.';

class ClaudeService implements AIService {
  final String apiKey;

  ClaudeService(this.apiKey);

  /// Optimiert alle Bilder (max 1280px, JPEG 80 %) und kodiert sie als Base64.
  Future<List<Map<String, dynamic>>> _encodeImages(List<File> images) async {
    final contents = <Map<String, dynamic>>[];
    for (final image in images) {
      final optimized = await ImageOptimizer.optimize(image);
      final bytes = await optimized.readAsBytes();
      final base64Image = base64Encode(bytes);
      const mediaType = 'image/jpeg';

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

  @override
  Future<String> identifyPlant(
    List<File> images, {
    bool isMixedPot = false,
    String? previousIdentification,
  }) async {
    final imageContents = await _encodeImages(images);

    final promptText = PlantCareSchema.buildIdentifyPrompt(
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

    imageContents.add({'type': 'text', 'text': fullPrompt});

    // Assistant-Prefill-Trick: Claude beginnt mit `{` → erzwingt JSON-Start
    return _callClaudeMessages(
      [
        {'role': 'user', 'content': imageContents},
        {'role': 'assistant', 'content': '{'},
      ],
      prefillAssistant: true,
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
  }) async {
    final imageContents = <Map<String, dynamic>>[];

    // Historische Fotos zuerst senden (ältere Aufnahmen als Kontext)
    if (historicalImages != null && historicalImages.isNotEmpty) {
      imageContents.addAll(await _encodeImages(historicalImages));
      imageContents.add({
        'type': 'text',
        'text': '⬆️ Das sind ältere Fotos der Pflanze zum Vergleich.',
      });
    }

    // Aktuelle Fotos
    imageContents.addAll(await _encodeImages(images));

    // Fertilizernames für Prompt
    final fertilizerNames = availableFertilizers
            ?.map((f) =>
                '${f.name}${f.npkRatio != null ? ' (NPK: ${f.npkRatio})' : ''}')
            .toList() ??
        [];

    final promptText = DiagnosisSchema.buildClaudePrompt(
      plantName: plantName,
      location: location,
      potInfo: potInfo,
      isMixedPot: isMixedPot,
      previousDiagnosis: previousDiagnosis,
      hasHistoricalImages:
          historicalImages != null && historicalImages.isNotEmpty,
      availableFertilizerNames: fertilizerNames,
    );

    imageContents.add({'type': 'text', 'text': promptText});

    // Assistant-Prefill `{` erzwingt JSON-Output
    final raw = await _callClaudeMessages(
      [
        {'role': 'user', 'content': imageContents},
        {'role': 'assistant', 'content': '{'},
      ],
      prefillAssistant: true,
      maxTokens: 3000,
    );

    return DiagnosisParser.parse(raw);
  }

  @override
  Future<String> identifyFertilizer(List<File> images) async {
    final imageContents = await _encodeImages(images);

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

  @override
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
      systemPrompt =
          '$_defaultSystemPrompt${_fertilizerContext(availableFertilizers)}';
    }

    return _callClaudeMessages(messages, systemPrompt: systemPrompt);
  }

  @override
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
    bool prefillAssistant = false,
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
          'temperature': 0,
          'top_p': 0.1,
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
    // Bei Prefill-Trick: Claude antwortet OHNE das führende `{`.
    // Wir fügen es wieder hinzu damit der JSON-Block vollständig ist.
    if (prefillAssistant) {
      return '{$textBlocks';
    }
    return textBlocks;
  }
}
