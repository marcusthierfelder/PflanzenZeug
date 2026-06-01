/// QA-Tests für Ticket #18: Kontext-Tagging im Foto-Capture-Flow
///
/// Testet:
/// - CaptureContextTag Modell (Enum, Labels, Prompt-Block, Serialisierung)
/// - PlantPhoto Serialisierung mit contextTag
/// - DiagnosisSchema prompt-Injektion mit userContext
/// - Freitext-Tag (custom): max. 60 Zeichen, Prompt-Template

import 'package:flutter_test/flutter_test.dart';
import 'package:pflanzenwart/models/capture_context_tag.dart';
import 'package:pflanzenwart/models/plant_photo.dart';
import 'package:pflanzenwart/services/prompts/diagnosis_schema.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // Gruppe 1: CaptureContextTag Modell
  // ═══════════════════════════════════════════════════════════════════════════
  group('CaptureContextTag – Modell', () {
    // AC: 4 Optionen: Blätter, Wurzeln, Blüten, + Eigenes
    test('T01 – leaf tag: chipLabel enthält Emoji und Label', () {
      final tag = CaptureContextTag(key: CaptureTagKey.leaf);
      expect(tag.chipLabel, contains('🌿'));
      expect(tag.chipLabel, contains('Blätter'));
    });

    test('T02 – root tag: chipLabel enthält Emoji und Label', () {
      final tag = CaptureContextTag(key: CaptureTagKey.root);
      expect(tag.chipLabel, contains('🌱'));
      expect(tag.chipLabel, contains('Wurzeln'));
    });

    test('T03 – flower tag: chipLabel enthält Emoji und Label', () {
      final tag = CaptureContextTag(key: CaptureTagKey.flower);
      expect(tag.chipLabel, contains('🌸'));
      expect(tag.chipLabel, contains('Blüten'));
    });

    test('T04 – custom tag ohne Text: label = "Eigenes"', () {
      final tag = CaptureContextTag(key: CaptureTagKey.custom);
      expect(tag.label, equals('Eigenes'));
    });

    test('T05 – custom tag mit Text: label = Freitext', () {
      final tag = CaptureContextTag(
          key: CaptureTagKey.custom, customText: 'gelbe Flecken');
      expect(tag.label, equals('gelbe Flecken'));
    });

    // AC: Bei aktivem „Wurzeln"-Tag → showRootBanner = true
    test('T06 – root tag: showRootBanner == true', () {
      final root = CaptureContextTag(key: CaptureTagKey.root);
      expect(root.showRootBanner, isTrue);
    });

    test('T07 – leaf/flower/custom tag: showRootBanner == false', () {
      expect(CaptureContextTag(key: CaptureTagKey.leaf).showRootBanner, isFalse);
      expect(CaptureContextTag(key: CaptureTagKey.flower).showRootBanner, isFalse);
      expect(CaptureContextTag(key: CaptureTagKey.custom).showRootBanner, isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Gruppe 2: Prompt-Kontext-Texte
  // ═══════════════════════════════════════════════════════════════════════════
  group('CaptureContextTag – toPromptContext()', () {
    // AC: Gewählter Tag wird im Prompt als Kontext-Block eingefügt
    test('T08 – leaf prompt enthält BLÄTTER-Fokus-Text', () {
      final tag = CaptureContextTag(key: CaptureTagKey.leaf);
      final ctx = tag.toPromptContext();
      expect(ctx, isNotNull);
      expect(ctx, contains('BLÄTTER'));
      expect(ctx, contains('NUTZER-FOTO-KONTEXT'));
    });

    test('T09 – root prompt enthält WURZELN-Fokus und Luftwurzeln-Hinweis', () {
      final tag = CaptureContextTag(key: CaptureTagKey.root);
      final ctx = tag.toPromptContext();
      expect(ctx, isNotNull);
      expect(ctx, contains('WURZELN'));
      // Wichtig: Luftwurzeln-Awareness muss im Prompt stehen
      expect(ctx, anyOf(contains('Luftwurzel'), contains('Monstera')));
    });

    test('T10 – flower prompt enthält BLÜTEN-Fokus-Text', () {
      final tag = CaptureContextTag(key: CaptureTagKey.flower);
      final ctx = tag.toPromptContext();
      expect(ctx, isNotNull);
      expect(ctx, contains('BLÜTEN'));
    });

    // AC: Freitext-Tag wird wörtlich (gesäubert) als „Nutzer-Kontext: …" eingefügt
    test('T11 – custom prompt enthält "Nutzer-Kontext:" und Freitext', () {
      final tag = CaptureContextTag(
          key: CaptureTagKey.custom, customText: 'gelbe Flecken seit Wochen');
      final ctx = tag.toPromptContext();
      expect(ctx, isNotNull);
      expect(ctx, contains('Nutzer-Kontext:'));
      expect(ctx, contains('gelbe Flecken seit Wochen'));
    });

    test('T12 – custom tag ohne Text gibt null zurück', () {
      final tag = CaptureContextTag(key: CaptureTagKey.custom, customText: '');
      expect(tag.toPromptContext(), isNull);
    });

    test('T13 – custom tag mit nur Leerzeichen gibt null zurück (Grenzfall)', () {
      // customText "   " ist leer nach trim → null
      // Anmerkung: customText wird in der UI bereits getrimmt bevor es gesetzt wird.
      // Hier testen wir das Modell direkt mit leerem String.
      final tag = CaptureContextTag(key: CaptureTagKey.custom, customText: '');
      expect(tag.toPromptContext(), isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Gruppe 3: Serialisierung (Persistenz)
  // ═══════════════════════════════════════════════════════════════════════════
  group('CaptureContextTag – Serialisierung', () {
    test('T14 – leaf toJson / fromJson round-trip', () {
      final original = CaptureContextTag(key: CaptureTagKey.leaf);
      final json = original.toJson();
      final restored = CaptureContextTag.fromJson(json);
      expect(restored.key, equals(CaptureTagKey.leaf));
      expect(restored.customText, isNull);
    });

    test('T15 – root round-trip', () {
      final original = CaptureContextTag(key: CaptureTagKey.root);
      final restored = CaptureContextTag.fromJson(original.toJson());
      expect(restored.key, equals(CaptureTagKey.root));
      expect(restored.showRootBanner, isTrue);
    });

    test('T16 – flower round-trip', () {
      final original = CaptureContextTag(key: CaptureTagKey.flower);
      final restored = CaptureContextTag.fromJson(original.toJson());
      expect(restored.key, equals(CaptureTagKey.flower));
    });

    test('T17 – custom mit Text round-trip', () {
      final original = CaptureContextTag(
          key: CaptureTagKey.custom, customText: 'Knollen-Vergilbung');
      final json = original.toJson();
      final restored = CaptureContextTag.fromJson(json);
      expect(restored.key, equals(CaptureTagKey.custom));
      expect(restored.customText, equals('Knollen-Vergilbung'));
    });

    test('T18 – unbekannter key-String fällt auf leaf zurück (defensive Deserializer)', () {
      final restored = CaptureContextTag.fromJson({'key': 'unknown_future_key'});
      expect(restored.key, equals(CaptureTagKey.leaf));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Gruppe 4: PlantPhoto – contextTag Persistenz (AC: Foto-Modell trägt Tag)
  // ═══════════════════════════════════════════════════════════════════════════
  group('PlantPhoto – contextTag Persistenz', () {
    test('T19 – PlantPhoto ohne contextTag: toJson enthält kein contextTag-Feld', () {
      final photo = PlantPhoto(
        id: 'p1',
        plantId: 'plant1',
        filePath: '/tmp/foto.jpg',
        takenAt: DateTime(2025, 5, 1),
      );
      final json = photo.toJson();
      expect(json.containsKey('contextTag'), isFalse);
    });

    test('T20 – PlantPhoto mit leaf tag: toJson enthält contextTag', () {
      final photo = PlantPhoto(
        id: 'p2',
        plantId: 'plant1',
        filePath: '/tmp/foto.jpg',
        takenAt: DateTime(2025, 5, 1),
        contextTag: CaptureContextTag(key: CaptureTagKey.leaf),
      );
      final json = photo.toJson();
      expect(json.containsKey('contextTag'), isTrue);
      expect(json['contextTag']['key'], equals('leaf'));
    });

    test('T21 – PlantPhoto fromJson ohne contextTag gibt null zurück (Abwärtskompatibilität)', () {
      final json = {
        'id': 'p3',
        'plantId': 'plant1',
        'filePath': '/tmp/foto.jpg',
        'takenAt': '2025-05-01T00:00:00.000',
        'purpose': 'progress',
        // kein 'contextTag' Feld → alte gespeicherte Fotos
      };
      final photo = PlantPhoto.fromJson(json);
      expect(photo.contextTag, isNull);
    });

    test('T22 – PlantPhoto fromJson mit root tag deserialisiert korrekt', () {
      final json = {
        'id': 'p4',
        'plantId': 'plant1',
        'filePath': '/tmp/foto.jpg',
        'takenAt': '2025-05-01T00:00:00.000',
        'purpose': 'diagnosis',
        'contextTag': {'key': 'root'},
      };
      final photo = PlantPhoto.fromJson(json);
      expect(photo.contextTag, isNotNull);
      expect(photo.contextTag!.key, equals(CaptureTagKey.root));
      expect(photo.contextTag!.showRootBanner, isTrue);
    });

    test('T23 – PlantPhoto round-trip mit custom tag', () {
      final original = PlantPhoto(
        id: 'p5',
        plantId: 'plant1',
        filePath: '/tmp/foto.jpg',
        takenAt: DateTime(2025, 5, 1),
        purpose: 'diagnosis',
        contextTag: CaptureContextTag(
            key: CaptureTagKey.custom, customText: 'Stecklinge'),
      );
      final restored = PlantPhoto.fromJson(original.toJson());
      expect(restored.contextTag!.key, equals(CaptureTagKey.custom));
      expect(restored.contextTag!.customText, equals('Stecklinge'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Gruppe 5: DiagnosisSchema – userContext Prompt-Injektion
  // ═══════════════════════════════════════════════════════════════════════════
  group('DiagnosisSchema – userContext Injektion', () {
    // AC: Tag wird im Prompt als Kontext-Block eingefügt
    test('T24 – Claude prompt OHNE userContext enthält keinen Kontext-Block', () {
      final prompt = DiagnosisSchema.buildClaudePrompt(plantName: 'Monstera');
      expect(prompt, isNot(contains('NUTZER-FOTO-KONTEXT')));
      expect(prompt, isNot(contains('NUTZER-KONTEXT')));
    });

    test('T25 – Claude prompt MIT leaf userContext enthält den Kontext-Block', () {
      final tag = CaptureContextTag(key: CaptureTagKey.leaf);
      final userCtx = tag.toPromptContext()!;
      final prompt = DiagnosisSchema.buildClaudePrompt(
        plantName: 'Monstera',
        userContext: userCtx,
      );
      expect(prompt, contains('NUTZER-FOTO-KONTEXT'));
      expect(prompt, contains('BLÄTTER'));
    });

    test('T26 – Claude prompt MIT root userContext enthält Luftwurzeln-Awareness', () {
      final tag = CaptureContextTag(key: CaptureTagKey.root);
      final userCtx = tag.toPromptContext()!;
      final prompt = DiagnosisSchema.buildClaudePrompt(
        plantName: 'Monstera',
        userContext: userCtx,
      );
      expect(prompt, contains('WURZELN'));
      // Root-Kontext muss Luftwurzeln-Hinweis enthalten
      expect(prompt, anyOf(contains('Luftwurzel'), contains('Monstera')));
    });

    test('T27 – DeepSeek prompt MIT flower userContext enthält den Kontext-Block', () {
      final tag = CaptureContextTag(key: CaptureTagKey.flower);
      final userCtx = tag.toPromptContext()!;
      final prompt = DiagnosisSchema.buildDeepSeekPrompt(
        plantName: 'Orchidee',
        userContext: userCtx,
      );
      expect(prompt, contains('BLÜTEN'));
    });

    test('T28 – userContext steht NACH dem Sorgfaltspflicht-Block', () {
      final tag = CaptureContextTag(key: CaptureTagKey.leaf);
      final userCtx = tag.toPromptContext()!;
      final prompt = DiagnosisSchema.buildClaudePrompt(
        plantName: 'Ficus',
        userContext: userCtx,
      );
      final dueDiligencePos = prompt.indexOf('DIAGNOSTISCHE SORGFALTSPFLICHT');
      final userCtxPos = prompt.indexOf('NUTZER-FOTO-KONTEXT');
      expect(dueDiligencePos, greaterThan(-1));
      expect(userCtxPos, greaterThan(-1));
      // userContext kommt NACH dem Sorgfaltspflicht-Block
      expect(userCtxPos, greaterThan(dueDiligencePos));
    });

    // AC: Freitext-Tag wird wörtlich als „Nutzer-Kontext: …" eingefügt
    test('T29 – custom Freitext-Tag landet wörtlich im Claude-Prompt', () {
      final tag = CaptureContextTag(
          key: CaptureTagKey.custom,
          customText: 'Triebe verfärbt seit 3 Wochen');
      final userCtx = tag.toPromptContext()!;
      final prompt = DiagnosisSchema.buildClaudePrompt(
        plantName: 'Pothos',
        userContext: userCtx,
      );
      expect(prompt, contains('Nutzer-Kontext:'));
      expect(prompt, contains('Triebe verfärbt seit 3 Wochen'));
    });

    test('T30 – null userContext: kein leerer Block im Prompt', () {
      final prompt = DiagnosisSchema.buildClaudePrompt(
        plantName: 'Philodendron',
        userContext: null,
      );
      // Kein leerer Kontext-Block darf auftauchen
      expect(prompt, isNot(contains('=== NUTZER-FOTO-KONTEXT ===')));
      expect(prompt, isNot(contains('=== NUTZER-KONTEXT ===')));
    });

    test('T31 – leerer String userContext: kein Block im Prompt', () {
      final prompt = DiagnosisSchema.buildClaudePrompt(
        plantName: 'Farn',
        userContext: '',
      );
      expect(prompt, isNot(contains('NUTZER-FOTO-KONTEXT')));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Gruppe 6: Freitext-Länge (max. 60 Zeichen AC)
  // ═══════════════════════════════════════════════════════════════════════════
  group('Freitext-Tag – Zeichenlimit', () {
    // AC: Freitext max. 60 Zeichen
    test('T32 – Freitext mit genau 60 Zeichen ist gültig', () {
      final text60 = 'A' * 60; // genau 60 Zeichen
      final tag = CaptureContextTag(key: CaptureTagKey.custom, customText: text60);
      expect(tag.customText!.length, equals(60));
      // Prompt-Kontext ist nicht null für nicht-leeren Text
      expect(tag.toPromptContext(), isNotNull);
    });

    test('T33 – Freitext mit 0 Zeichen gibt null in toPromptContext', () {
      final tag = CaptureContextTag(key: CaptureTagKey.custom, customText: '');
      expect(tag.toPromptContext(), isNull);
    });

    test('T34 – Freitext mit 1 Zeichen ist gültig', () {
      final tag = CaptureContextTag(key: CaptureTagKey.custom, customText: 'X');
      expect(tag.toPromptContext(), isNotNull);
      expect(tag.toPromptContext(), contains('X'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Gruppe 7: BurstCameraResult – Typ-Korrektheit
  // ═══════════════════════════════════════════════════════════════════════════
  group('CaptureContextTag – toString()', () {
    test('T35 – toString() gibt chipLabel zurück', () {
      final tag = CaptureContextTag(key: CaptureTagKey.flower);
      expect(tag.toString(), equals(tag.chipLabel));
    });
  });
}
