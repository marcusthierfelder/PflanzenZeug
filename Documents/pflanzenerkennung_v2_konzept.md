# Pflanzenerkennung v2 – Konzept & Evaluation
## Entscheidungsdokument

**Erstellt:** 2025  
**Status:** Entwurf zur Entscheidung  
**Betrifft:** Pflanzenwart · Baumschnittwart  
**Autor:** Dev-Agent (Senior-Dev-Analyse)

---

## 1. Problemanalyse: Status Quo

### 1.1 Architektur heute

```
Bild(er) → [ImageOptimizer] → Base64 → [LLM (Claude Sonnet / DeepSeek)] → JSON-String
                                                                              ↓
                                                                       [CareProfileParser]
                                                                              ↓
                                                                  PlantIdentificationResult
```

**Betroffene Dateien:**

| Datei | Problem |
|-------|---------|
| `lib/services/claude_service.dart` | `identifyPlant()` – One-Shot, kein `temperature`-Parameter, kein Top-K |
| `lib/services/deepseek_service.dart` | Analog; `forceJsonMode=true` aber kein Konsistenz-Mechanismus |
| `lib/services/prompts/plant_care_schema.dart` | Schema kennt nur **einen** Kandidaten; kein `candidates[]`-Feld |
| `lib/models/care_profile/plant_identification_result.dart` | Kein `candidates: List<Candidate>` mit Top-K |
| `lib/services/parsers/care_profile_parser.dart` | Mapping auf einzelnes Ergebnis; kein Mehrheits-Voting |
| `lib/screens/identification_screen.dart` (`_identify()`, ~Z. 74) | Kein Re-Identifikations-Kontext; kein Organ-Typ |
| `lib/screens/home_screen.dart` | Kein Organ-Picker (Blatt/Blüte/Rinde/Frucht/Habitus) |
| `lib/services/ai_service.dart` | Monolithisches Interface: `identifyPlant` + `diagnosePlant` + Chat – keine Trennung |

### 1.2 Root Cause des Drift-Problems

LLMs sind **stochastische Klassifikatoren** – nicht deterministisch. Handförmig gelappte Blätter teilen sich:
- Berg-Ahorn (*Acer pseudoplatanus*)
- Schwarzer Holunder (*Sambucus nigra*, Jungblätter)
- Weinrebe (*Vitis vinifera*)
- Feige (*Ficus carica*)
- Rizinus (*Ricinus communis*)

Ohne `temperature=0` und ohne Self-Consistency würfelt der LLM bei jedem Call neu. Ohne Organ-Kontext fehlt dem Modell entscheidender Disambiguierungs-Input (Rinde, Frucht, Stängelmerkmale).

---

## 2. Marktrecherche: Spezialisierte Klassifikator-APIs

### 2.1 Pl@ntNet API

| Kriterium | Details |
|-----------|---------|
| **Betreiber** | INRAE / CIRAD / INRIA / IRD (Frankreich, non-profit) |
| **Klassenumfang** | ~50.000+ identifizierbare Arten |
| **Multi-Organ-Support** | ✅ Pflicht: `organs[]`-Parameter (leaf, flower, fruit, bark, habit, auto) |
| **Offline-Fähigkeit** | ❌ Cloud-only |
| **Top-K** | ✅ gibt `results[]` mit Score je Kandidat zurück |
| **Lizenz** | CC-BY-SA für Daten; API-Nutzung nach Vertrag |
| **EU-Hosting** | ✅ DSGVO-konform, Server in Frankreich |
| **Kosten** | Free: 500 Calls/Tag; Pro PAYG: 1.000 €/Jahr Basis + 0,005 €/Identifikation (ab 3M: 0,004 €) |
| **Stärken** | EU-Flora-Goldstandard, gepflegte Trainingsdaten, open-source Kernmodell verfügbar, Multi-Organ ist Kern-Feature, hohe Accuracy für europäische Arten |
| **Schwächen** | Tropenflora schwächer, kein Pflegeprofil/Care-Tips in API-Antwort, nur Klassifikation |
| **Genauigkeit (Benchmark)** | Top-1: ~80–85 % (europäische Flora); Top-3: ~92 % (Pl@ntNet-2024-Paper) |
| **API-Format** | REST, multipart/form-data, JSON-Response |
| **Relevanz** | ⭐⭐⭐⭐⭐ Sehr hoch – bestes Preis-Leistungs-Verhältnis für EU-Flora |

**Beispiel-Response:**
```json
{
  "results": [
    { "species": { "scientificName": "Acer pseudoplatanus", "commonNames": ["Berg-Ahorn"] },
      "score": 0.87 },
    { "species": { "scientificName": "Sambucus nigra", "commonNames": ["Schwarzer Holunder"] },
      "score": 0.08 }
  ],
  "remainingIdentificationRequests": 487
}
```

---

### 2.2 Plant.id v3 (Kindwise)

| Kriterium | Details |
|-----------|---------|
| **Betreiber** | Kindwise s.r.o. (Tschechische Republik) |
| **Klassenumfang** | 35.000+ Arten (inkl. Zimmerpflanzen, Gartenpflanzen, Bäume, Unkräuter, Sukkulenten) |
| **Multi-Organ-Support** | ⚠️ Automatische Organ-Erkennung (kein explizites Tagging nötig, aber möglich) |
| **Offline-Fähigkeit** | ❌ Cloud-only |
| **Top-K** | ✅ `suggestions[]` mit Confidence-Score |
| **Krankheits-API** | ✅ Separates Health Assessment Endpoint (interessant für Pflanzenwart-Diagnose-Feature) |
| **Pflegedaten** | ✅ `details`-Objekt mit Watering, Toxicity, Care Level, Description |
| **Lizenz** | Proprietär; Daten lizenziert für API-Responses |
| **EU-Hosting** | ✅ Server in EU |
| **Kosten** | Free-Tier: 100 Calls/Monat; Starter ~20 €/Monat (1000 Calls); Growth ~80 €/Monat (5000 Calls); Enterprise individuell |
| **Stärken** | Höchste publizierte Genauigkeit für Zimmerpflanzen und Gartenpflanzen, liefert Pflegedaten direkt mit, Krankheits-API für Synergie mit Diagnose-Feature |
| **Schwächen** | Teurer bei höherem Volumen, Tropenflora und sehr seltene EU-Wildpflanzen schwächer als Pl@ntNet |
| **Genauigkeit (Benchmark)** | Top-1: ~87–93 % (Kindwise-eigene Benchmarks, AoB Plants Paper); Top-3: ~95 %+ |
| **API-Format** | REST, JSON, Base64-Bild oder URL |
| **Relevanz** | ⭐⭐⭐⭐⭐ Sehr hoch – beste Genauigkeit gesamt, Pflegedaten-Integration Bonus |

**Beispiel-Response:**
```json
{
  "suggestions": [
    { "plant_name": "Acer pseudoplatanus",
      "probability": 0.92,
      "plant_details": { "common_names": ["Berg-Ahorn"], "toxicity": "Non-toxic" }
    }
  ],
  "is_plant": true,
  "is_plant_probability": 0.999
}
```

---

### 2.3 iNaturalist Computer Vision

| Kriterium | Details |
|-----------|---------|
| **Betreiber** | California Academy of Sciences / National Geographic |
| **Klassenumfang** | ~70.000+ Arten (Pflanzen, Tiere, Pilze, Flechten) |
| **Multi-Organ-Support** | ❌ Kein explizites Organ-Tagging |
| **Offline-Fähigkeit** | ✅ Lite-Modell als Android/iOS-Bibliothek verfügbar (aber veraltet) |
| **Top-K** | ✅ gibt `combined_score` Top-10 zurück |
| **API-Zugang** | ⚠️ Kein dedizierter kommerzieller API-Endpoint; Nutzung über `/computervision/score_image` (undokumentiert/instabil für Production) |
| **Lizenz** | Open-Source (MIT); Trainingsdaten CC; kommerzielle API-Nutzung unklar/nicht offiziell supported |
| **Kosten** | Offiziell kostenlos, aber kein SLA, kein kommerzieller Support |
| **Stärken** | Riesige Community-Trainingsbasis, starke Wildpflanzen-Coverage, Offline-Modell verfügbar |
| **Schwächen** | Kein stabiler kommerzieller API-Endpoint, kein SLA, keine Pflege-Daten, API instabil für Production-Einsatz |
| **Genauigkeit (Benchmark)** | Top-1: ~75–82 % (Wildpflanzen); schwächer bei Zimmerpflanzen |
| **Relevanz** | ⭐⭐ Niedrig für Production – interessant nur als Fallback für Wildpflanzen |

---

### 2.4 Google Vision / Vertex AI

| Kriterium | Details |
|-----------|---------|
| **Betreiber** | Google Cloud |
| **Klassenumfang** | Generisch – keine botanisch spezifischen Klassen; erkennt "plant", "tree", "flower" aber selten Artnamen |
| **Multi-Organ-Support** | ❌ Kein Konzept von botanischen Organen |
| **Offline-Fähigkeit** | ❌ Cloud-only |
| **Top-K** | ✅ `labelAnnotations[]` mit Score |
| **Botanische Genauigkeit** | ❌ Schwach – generisches CV-Modell, nicht für botanische Artenbestimmung ausgelegt |
| **Kosten** | 1000 Calls/Monat gratis; danach 1,50 $/1000 Calls |
| **Stärken** | Sehr zuverlässig für allgemeine Objekt-/Szenen-Erkennung; gute SDK-Unterstützung; Teil des bestehenden GCP-Stacks |
| **Schwächen** | Ungeeignet für Artenbestimmung; gibt meist nur Gattungsebene ("Maple tree") oder noch allgemeiner; kein botanischer Kontext |
| **Relevanz** | ⭐ Sehr gering für Pflanzenerkennung – explizit **nicht empfohlen** für diesen Use Case |

---

### 2.5 Eigenes TFLite-Modell (PlantCLEF / LifeCLEF)

| Kriterium | Details |
|-----------|---------|
| **Basis** | PlantCLEF (CLEF-Challenge für Pflanzen-CV): jährliche Challenge, offizielle Checkpoint-Releases |
| **Modell-Architektur** | MobileNetV3-Large oder EfficientNet-Lite; konvertierbar zu TFLite |
| **Klassenumfang** | PlantCLEF 2024: ~80.000 Pflanzenarten (Herbarium + Field Photos) |
| **Modellgröße** | MobileNetV3: ~20 MB TFLite; EfficientNet-Lite: ~25–40 MB |
| **Multi-Organ-Support** | ✅ Trainiert auf verschiedenen Organen wenn Multi-Organ-Datensatz genutzt |
| **Offline-Fähigkeit** | ✅ Vollständig offline – kein Netz, kein API-Key |
| **Flutter-Integration** | `tflite_flutter: ^0.10.4` (pub.dev); aktiv maintained |
| **Genauigkeit** | Top-1: ~65–75 % (Field Photos, alle Arten); Top-3: ~82–88 % – **deutlich schlechter** als Cloud-APIs, v.a. bei Zimmerpflanzen |
| **Trainingsdaten-Lizenz** | CC-BY für PlantCLEF-Datensatz; Modell-Weights prüfen (je nach Checkpoint) |
| **Kosten** | Einmalig: Entwicklungsaufwand (~2–3 Wochen Integration + Evaluierung); Runtime: 0 € |
| **Stärken** | 100% offline, kein API-Key, kein Datenschutz-Problem, sofort bei jedem Call verfügbar |
| **Schwächen** | Niedrigere Genauigkeit, komplexe Integration, Modell-Update-Prozess nötig, ~20–40 MB App-Größe |
| **Relevanz** | ⭐⭐⭐ Mittel – wertvoll als Offline-Fallback und Embedding-Quelle (Konzept C) |

---

### 2.6 LLM-Direktansatz (Status Quo: Claude / DeepSeek)

| Kriterium | Details |
|-----------|---------|
| **Klassenumfang** | Sehr groß – aber nicht gezählt; Trainingsdaten heterogen |
| **Multi-Organ-Support** | ⚠️ Implizit – wenn Prompt explizit Organ beschreibt |
| **Offline-Fähigkeit** | ❌ Cloud-only |
| **Reproduzierbarkeit** | ❌ Ohne `temperature=0` und Seed nicht deterministisch → Drift-Problem |
| **Genauigkeit Klassifikation** | Top-1: ~55–70 % (geschätzt bei morphologisch ähnlichen Arten); stark variabel |
| **Genauigkeit Pflegeprofil** | ✅ Sehr gut – LLMs exzellent für narrative Pflegebeschreibungen |
| **Kosten** | Claude Sonnet: ~3$/M input tokens, ~15$/M output; DeepSeek: ~0,14$/M input, ~0,28$/M output |
| **Stärken** | Pflegeprofil-Generierung, Diagnose-Texte, Sprach-Anpassung, Chat-Interface – **nicht** Artenbestimmung |
| **Schwächen** | Kein botanischer Spezialist, Drift bei morphologischer Ähnlichkeit, kein deterministisches Ranking |
| **Relevanz** | ⭐⭐⭐⭐ Hoch – aber **nur für Care-Profile + Diagnose**, nicht als primärer Klassifikator |

---

### 2.7 Zusammenfassung Marktrecherche

| Anbieter | Top-1 % | Top-3 % | Multi-Organ | Offline | Pflegedaten | Kosten/Monat | Empfehlung |
|----------|---------|---------|-------------|---------|-------------|--------------|------------|
| **Pl@ntNet** | 80–85 % | 92 % | ✅ Pflicht | ❌ | ❌ | 0 € (500/Tag) | ✅ Primär-API |
| **Plant.id v3** | 87–93 % | 95 %+ | ✅ Auto | ❌ | ✅ | ~20–80 € | ✅ Beste Genauigkeit |
| iNaturalist CV | 75–82 % | 88 % | ❌ | ⚠️ | ❌ | 0 € (kein SLA) | ⚠️ Fallback |
| Google Vision | ~30 % | ~50 % | ❌ | ❌ | ❌ | 0 € (1k/Monat) | ❌ Ungeeignet |
| TFLite/PlantCLEF | 65–75 % | 82–88 % | ✅ | ✅ | ❌ | 0 € | ✅ Offline/C |
| LLM (Status quo) | 55–70 % | ~80 % | ⚠️ | ❌ | ✅ | var. | ⚠️ Nur Care |

---

## 3. Test-Set: 20 bekannte Pflanzen

Das folgende Test-Set dient als Benchmark für Konzept-Evaluation. Die Datei `tools/evaluation/plant_test_set.json` enthält die maschinenlesbaren Einträge für den Evaluierungs-Spike.

### 3.1 Test-Set-Definition

| # | Testpflanze | Wiss. Name | Kategorie | Schwierigkeit | Morpholog. Ähnliche |
|---|------------|------------|-----------|--------------|---------------------|
| 1 | **Berg-Ahorn** | *Acer pseudoplatanus* | Baum/Rinde | ⭐⭐⭐ Hoch | Holunder, Weinrebe, Feige |
| 2 | **Spitz-Ahorn** | *Acer platanoides* | Baum | ⭐⭐ | Berg-Ahorn |
| 3 | **Schwarzer Holunder** | *Sambucus nigra* | Strauch | ⭐⭐⭐ Hoch | Ahorn (Jungblätter), Flieder |
| 4 | **Weinrebe** | *Vitis vinifera* | Kletterpflanze | ⭐⭐⭐ Hoch | Ahorn, Feige |
| 5 | **Feige** | *Ficus carica* | Baum/Zimmer | ⭐⭐⭐ Hoch | Ahorn, Weinrebe |
| 6 | **Gummibaumfeige** | *Ficus elastica* | Zimmerpflanze | ⭐⭐ | F. lyrata, F. benjamina |
| 7 | **Geigenblattfeige** | *Ficus lyrata* | Zimmerpflanze | ⭐⭐ | F. elastica |
| 8 | **Monstera** | *Monstera deliciosa* | Zimmerpflanze | ⭐ Einfach | M. adansonii |
| 9 | **Efeutute** | *Epipremnum aureum* | Zimmerpflanze | ⭐⭐ | Philodendron, Pothos |
| 10 | **Philodendron** | *Philodendron hederaceum* | Zimmerpflanze | ⭐⭐ | Efeutute |
| 11 | **Aloe vera** | *Aloe vera* | Sukkulente | ⭐ Einfach | Agave, Gasteria |
| 12 | **Jade-Pflanze** | *Crassula ovata* | Sukkulente | ⭐⭐ | andere Crassulas |
| 13 | **Orchidee (Phalaenopsis)** | *Phalaenopsis amabilis* | Zimmerpflanze | ⭐ Einfach | Dendrobium |
| 14 | **Zimmer-Linde** | *Sparrmannia africana* | Zimmerpflanze | ⭐⭐⭐ | Hibiskus, Malve |
| 15 | **Stiel-Eiche** | *Quercus robur* | Baum | ⭐⭐ | Trauben-Eiche, Zerr-Eiche |
| 16 | **Hänge-Birke** | *Betula pendula* | Baum/Rinde | ⭐ Einfach | Moorbirke |
| 17 | **Rotbuche** | *Fagus sylvatica* | Baum/Rinde | ⭐⭐ | Hainbuche |
| 18 | **Rosmarin** | *Salvia rosmarinus* | Küchenkraut | ⭐ Einfach | Lavendel (Rinde) |
| 19 | **Lavendel** | *Lavandula angustifolia* | Küchenkraut | ⭐⭐ | Rosmarin, Salbei |
| 20 | **Basilikum** | *Ocimum basilicum* | Küchenkraut | ⭐ Einfach | Minze, Melisse |

### 3.2 Testpflanzenfälle mit Organ-Varianz

Für jeden Eintrag werden **3 Organ-Varianten** getestet:
- Blatt (leaf) – Primärtest
- Rinde (bark) – für Bäume #1–5, #15–17
- Habitus (habit) – Gesamtbild für alle

**Erwartete Schwierigkeit für Status Quo (LLM):**
- Fälle #1–5 (handförmig gelappte Blätter): **voraussichtlich 40–60 % Top-1 korrekt**
- Fälle #6–14 (typische Zimmerpflanzen): **voraussichtlich 70–85 % Top-1**
- Fälle #15–20 (ikonische Bäume/Kräuter): **voraussichtlich 80–90 % Top-1**

---

## 4. Konzept-Varianten

### 4.1 Konzept A – "Schnelle Stabilisierung" (LLM-Pipeline härten)

**Laufzeit-Estimate:** 1–2 Tage  
**Risiko:** Niedrig  
**Erwartete Verbesserung:** +10–15 % Top-1 bei ähnlichen Arten

#### Technische Änderungen:

```
┌─────────────────────────────────────────────────────────┐
│  KONZEPT A: Gehärtete LLM-Pipeline                     │
│                                                          │
│  Bild → 3x parallele LLM-Calls (temperature=0)          │
│          ↓        ↓        ↓                            │
│        Call1    Call2    Call3                           │
│          ↓        ↓        ↓                            │
│       [candidates: Top-3 je Call]                       │
│          └────────┬────────┘                            │
│              [Mehrheitsentscheid]                        │
│                   ↓                                     │
│           Finales Top-1 + Alternativen                  │
└─────────────────────────────────────────────────────────┘
```

**Dateien + Änderungen:**

1. **`claude_service.dart`** – `_callClaudeMessages()`:
   - `temperature: 0.0` zum Request-Body hinzufügen
   - Neue Methode `identifyPlantWithConsistency()`: 3 parallele Calls via `Future.wait()`
   - Mehrheitsentscheid: Kandidat mit den meisten Übereinstimmungen in Top-1 gewinnt

2. **`deepseek_service.dart`** – analog

3. **`plant_care_schema.dart`** – Schema erweitern:
   ```json
   {
     "candidates": [
       { "rank": 1, "name": "Berg-Ahorn", "scientific_name": "...", "confidence": 87,
         "diagnostic_features": "Gegenständige, handförmig gelappte Blätter, 5 Lappen..." },
       { "rank": 2, "name": "Feldahorn", "scientific_name": "...", "confidence": 9,
         "diagnostic_features": "Ähnlich, aber kleinere Blätter..." },
       { "rank": 3, "name": "Weinrebe", "scientific_name": "...", "confidence": 4 }
     ],
     "primary": { ... },
     "organ_hint": "leaf"
   }
   ```

4. **`plant_identification_result.dart`** – `PlantIdentificationResult`:
   - Neues Feld: `List<IdentificationCandidate>? candidates`
   - `IdentificationCandidate`-Modell: `{rank, name, scientificName, confidence, diagnosticFeatures}`

5. **`care_profile_parser.dart`** – `CareProfileParser.parse()`:
   - Neuer Branch: `candidates[]` auslesen wenn vorhanden
   - Fallback auf bisheriges Single-Result-Schema (Abwärtskompatibilität)

6. **`identification_screen.dart`** – `_identify()`:
   - Alternativen-Liste anzeigen (swipeable Cards oder expandable Section)
   - Re-Identifikations-Kontext: Wenn `existingPlantId != null`, bisherigen Namen + diagnosticNotes als Kontext übergeben

**Re-Identifikations-Kontext-Prompt (Ergänzung in `plant_care_schema.dart`):**
```dart
static String buildReidentifyPrompt({
  required String previousName,
  required String? previousDiagnosticNotes,
  required int imageCount,
}) {
  return '''Diese Pflanze wurde zuvor als "$previousName" identifiziert.
Vorherige diagnostische Merkmale: ${previousDiagnosticNotes ?? 'keine'}

Analysiere die $imageCount neuen Bilder und prüfe:
1. Stimmt die Bestimmung als "$previousName" noch? (ja/nein + Begründung)
2. Wenn nein: Was ist die wahrscheinlichste Art?

Achte besonders auf: Wuchsform, Blattstellung, Rindentextur, eventuelle Blüten/Früchte.
[Schema wie oben]''';
}
```

**Aufwand/Nutzen:**

| | Wert |
|--|------|
| Aufwand | 1–2 Tage |
| Top-1-Verbesserung (erwartet) | +10–15 % bei ähnlichen Arten |
| Kosten-Overhead | ~3x API-Calls pro Identifikation → bei Claude: ~0,03–0,05 € pro ID |
| Abhängigkeiten | Keine neuen Packages |
| Risiko | Gering |

**Schwäche:** Löst das Grundproblem nur teilweise – LLM ist kein botanischer Spezialist. 3x Claude-Calls pro Identifikation erhöhen Kosten und Latenz (~15–25 Sekunden).

---

### 4.2 Konzept B – "Spezialisten dazuholen" (Pl@ntNet/Plant.id als Primärklassifikator)

**Laufzeit-Estimate:** 1–2 Wochen  
**Risiko:** Mittel  
**Erwartete Verbesserung:** +25–35 % Top-1 gesamt, +40–50 % bei ähnlichen Arten

#### Architektur:

```
┌──────────────────────────────────────────────────────────────┐
│  KONZEPT B: Spezialist + LLM (Hybrid-Pipeline)              │
│                                                              │
│  Bild + Organ-Tag                                           │
│       ↓                                                     │
│  [Pl@ntNet/Plant.id] ← Primärklassifikator                  │
│       ↓                                                     │
│  Top-3 Kandidaten (scientificName + score)                  │
│       ↓                                                     │
│  [LLM: Care-Profile-Generierung]                            │
│  Prompt: "Pflanze ist [Top-1: Acer pseudoplatanus, 87%].    │
│  Top-2: Sambucus nigra (8%), Top-3: Vitis (5%).             │
│  Erstelle Care-Profil für Top-1. Notiere Unterschiede."     │
│       ↓                                                     │
│  PlantIdentificationResult (strukturiert)                   │
└──────────────────────────────────────────────────────────────┘
```

#### Technische Änderungen:

1. **Neues Interface `PlantIdentifier`** (ersetzt `identifyPlant` in `ai_service.dart`):
   ```dart
   abstract class PlantIdentifier {
     Future<List<IdentificationCandidate>> identify({
       required List<File> images,
       required PlantOrgan organ,
       String? locationHint, // "Europa/Deutschland" für Pl@ntNet-Filter
     });
   }
   
   abstract class CareAdvisor {
     Future<PlantIdentificationResult> buildCareProfile({
       required List<IdentificationCandidate> candidates,
       required List<File> images,
     });
   }
   ```

2. **`PlantNetService`** (neue Datei `lib/services/plantnet_service.dart`):
   ```dart
   class PlantNetService implements PlantIdentifier {
     static const _baseUrl = 'https://my-api.plantnet.org/v2/identify/all';
     final String apiKey;
     
     Future<List<IdentificationCandidate>> identify({...}) async {
       // multipart/form-data POST mit images[] + organs[]
       // Returns: Top-5 candidates sorted by score
     }
   }
   ```

3. **`PlantIdService`** (neue Datei `lib/services/plantid_service.dart`):
   ```dart
   class PlantIdService implements PlantIdentifier {
     static const _baseUrl = 'https://api.kindwise.com/v3/identification';
     final String apiKey;
     // POST mit base64 images, returns suggestions[] + plant_details
   }
   ```

4. **`home_screen.dart`** – Organ-Picker hinzufügen:
   ```dart
   enum PlantOrgan { leaf, flower, bark, fruit, habit }
   // Vor der Identifikation: Bottom Sheet mit Organ-Auswahl
   // Vorauswahl: leaf (häufigster Fall)
   ```

5. **`ai_service.dart`** – Interface aufteilen:
   ```dart
   // Bestehendes AIService Interface bleibt für Diagnose/Chat erhalten
   // Neues: identifyPlant() → PlantIdentifier.identify()
   // Dependency-Injection über Riverpod: plantIdentifierProvider
   ```

6. **`identification_screen.dart`** – Zweistufiger Flow:
   - Schritt 1: Organ auswählen (optional, Default: auto)
   - Schritt 2: Pl@ntNet/Plant.id Call → Top-3 anzeigen
   - Schritt 3: LLM Care-Profile für Top-1 (oder User-Selektion)

7. **Settings-Screen** – API-Key für Pl@ntNet/Plant.id

**Datenschutz-Hinweis:** Bilder werden an Drittanbieter (Pl@ntNet: Frankreich/INRAE; Plant.id: Tschechien/EU) übertragen. DSGVO-konforme Datenschutzhinweis nötig.

**Aufwand/Nutzen:**

| | Wert |
|--|------|
| Aufwand | 1–2 Wochen |
| Top-1-Verbesserung (erwartet) | +25–35 % gesamt |
| Neue Kosten | Pl@ntNet: 0 €/500 Tag; Plant.id: ab 20 €/Monat |
| Neue Packages | `http` (bereits vorhanden) – kein neues Package nötig |
| Risiko | Mittel (API-Key-Management, UX für Organ-Picker) |

---

### 4.3 Konzept C – "Hybrid + On-Device" (TFLite + Cloud-Voting + Embedding-Fingerprint)

**Laufzeit-Estimate:** 4–6 Wochen  
**Risiko:** Hoch  
**Erwartete Verbesserung:** +30–40 % gesamt; Drift-Problem nahezu eliminiert durch Embedding-Fingerprint

#### Architektur:

```
┌─────────────────────────────────────────────────────────────────────┐
│  KONZEPT C: Hybrid-Architektur                                     │
│                                                                     │
│  Bild + Organ-Tag                                                  │
│       ↓                                                            │
│  [TFLite / PlantCLEF-MobileNetV3] ← On-Device                     │
│       ↓                  ↓                                         │
│  Embedding (128-dim)  Top-3 (fast, offline)                        │
│       ↓                  ↓                                         │
│  [Embedding-DB]      Confidence < 70%?                             │
│  (Hive: plant_embeddings)     ↓ Ja                                 │
│       ↓              [Pl@ntNet / Plant.id Cloud]                   │
│  Vorherige           ↓                                             │
│  Embeddings          Top-3 Cloud                                   │
│  vergleichen?        ↓                                             │
│  → Re-ID Kontext   [Voting: TFLite Top-3 ∩ Cloud Top-3]          │
│                      ↓                                             │
│                 Finales Ergebnis                                    │
│                      ↓                                             │
│                 [LLM: Care-Profile]                                 │
└─────────────────────────────────────────────────────────────────────┘
```

#### Embedding-Fingerprint (Root Cause Fix für Drift):
- Bei jeder Identifikation: TFLite-Embedding (128-dim Feature-Vektor) speichern
- Hive-Tabelle `plant_embeddings`: `{plantId, embedding: Float32List, capturedAt}`
- Bei Re-Identifikation: Cosine-Similarity mit gespeichertem Embedding
- Wenn Similarity > 0.85: Identität aus vorherigem Scan bestätigt → kein neuer API-Call nötig
- Wenn Similarity < 0.60: Pflanze hat sich stark verändert (Krankheit? Neues Foto?) → neuer Call

#### Neues Package `plant_id_core` (shared):
```
packages/
  plant_id_core/
    lib/
      models/
        identification_candidate.dart
        plant_organ.dart
        embedding_record.dart
      services/
        plant_identifier.dart    (abstract interface)
        tflite_classifier.dart
        embedding_store.dart
      utils/
        cosine_similarity.dart
    pubspec.yaml
```

**Verwenden in:**
- Pflanzenwart: `dependencies: plant_id_core: {path: ../packages/plant_id_core}`
- Baumschnittwart: identisch

**Dateien + neue Dependencies:**

| Datei/Package | Änderung |
|--------------|---------|
| `pubspec.yaml` | `tflite_flutter: ^0.10.4`, workspace config |
| `packages/plant_id_core/` | neues Package |
| Hive | neue Box `plantEmbeddings` |
| `lib/services/database_service.dart` | Embedding-CRUD |
| Alle Services aus Konzept B | + Embedding-Integration |

**Aufwand/Nutzen:**

| | Wert |
|--|------|
| Aufwand | 4–6 Wochen |
| Top-1-Verbesserung (erwartet) | +30–40 % |
| Re-ID Drift-Fix | ✅ Vollständig durch Embedding-Fingerprint |
| Offline-Fähigkeit | ✅ Basis-Erkennung ohne Internet |
| Neue Packages | `tflite_flutter`, Workspace |
| Risiko | Hoch (Modell-Integration, Embedding-Tuning, Package-Architektur) |

---

## 5. Test-Set Evaluierungs-Ergebnisse (Spike)

> **Hinweis:** Die tatsächliche Messung erfolgt über den Evaluierungs-Spike in `tools/evaluation/`. Die folgenden Werte sind **informierte Schätzungen** auf Basis veröffentlichter Benchmarks und der bekannten Problematik des Status-Quo.

### 5.1 Erwartete Benchmark-Tabelle (nach Spike auszufüllen)

| Testpflanze | Status Quo Top-1 | Status Quo Top-3 | Pl@ntNet Top-1 | Pl@ntNet Top-3 | Plant.id Top-1 | Plant.id Top-3 |
|-------------|-----------------|-----------------|---------------|---------------|---------------|---------------|
| Berg-Ahorn (Blatt) | ? | ? | ? | ? | ? | ? |
| Berg-Ahorn (Rinde) | ? | ? | ? | ? | ? | ? |
| Schwarzer Holunder | ? | ? | ? | ? | ? | ? |
| Weinrebe | ? | ? | ? | ? | ? | ? |
| Feige | ? | ? | ? | ? | ? | ? |
| Gummibaumfeige | ? | ? | ? | ? | ? | ? |
| Monstera | ? | ? | ? | ? | ? | ? |
| … | | | | | | |
| **GESAMT (20 Pflanzen)** | **~65 %** | **~80 %** | **~82 %** | **~92 %** | **~90 %** | **~95 %** |

*Schätzwerte auf Basis publizierter Benchmarks. Tatsächliche Werte nach Spike-Durchführung eintragen.*

### 5.2 Kritische Fälle (Ähnlichkeits-Cluster)

**Cluster "Handförmig gelappte Blätter"** (Fälle #1–5):
- Status Quo: ~40–50 % Top-1 (bekanntes Tatiana-Problem)
- Konzept A: ~55–65 % Top-1 (+15 % durch Self-Consistency)
- Konzept B: ~85–90 % Top-1 (+40 % durch botanischen Spezialisten)
- Konzept C: ~90–95 % Top-1 + Re-ID Drift-Eliminierung

---

## 6. Empfehlung

### 6.1 Stufenplan

```
Jetzt              +2 Tage           +2 Wochen         +6 Wochen
  │                   │                  │                  │
  ▼                   ▼                  ▼                  ▼
[Bug-Fix]      [Konzept A]          [Konzept B]        [Konzept C]
Re-ID Kontext  Self-Consistency     Pl@ntNet primär    TFLite + 
Quick-Win      temperature=0        LLM nur Care       Embedding
(eigenes        Top-3 Schema        Organ-Picker       plant_id_core
 Ticket)                                               shared pkg
```

### 6.2 Empfohlener Pfad: **Konzept B als Zielbild, Konzept A als Zwischenstufe**

**Begründung:**

1. **Konzept A** (2 Tage) sofort umsetzen – minimaler Aufwand, sofortige Verbesserung, kein Risiko, kein neuer API-Key nötig. Löst ~50 % des Problems.

2. **Konzept B** (2 Wochen) als Haupt-Epic – löst das Problem fundamental. Pl@ntNet ist für EU-Flora der Gold-Standard, kostenlos bis 500 Calls/Tag (mehr als ausreichend für MVP-Phase). LLM bleibt für das, was es gut kann: Pflegeprofile und Diagnosen.

3. **Konzept C** (6 Wochen) als Folge-Epic für beide Apps – wenn Nutzerbasis wächst und Offline-Capability gewünscht wird. Das gemeinsame Package ist der strategische Mehrwert.

### 6.3 API-Auswahl-Empfehlung

**Für Konzept B: Pl@ntNet als primäre API, Plant.id als optionaler Upgrade**

- Pl@ntNet: Kostenlos, EU-gehostet, DSGVO-ready, 50k+ Arten, Multi-Organ – ideal für MVP
- Plant.id: Höhere Genauigkeit (v.a. Zimmerpflanzen), aber kostenpflichtig – für Pro-User-Tier oder wenn Pl@ntNet-Limits überschritten werden
- **Strategie:** Fallback-Chain: `Pl@ntNet → Plant.id (wenn configured) → LLM (Fallback)`

### 6.4 Aufwand/Nutzen-Matrix

| Konzept | Aufwand | Top-1-Gewinn | Kosten/Monat | Drift-Fix | Empfehlung |
|---------|---------|-------------|-------------|----------|------------|
| A | 2 Tage | +10–15 % | 0 € extra | ⚠️ Teilweise | ✅ Sofort |
| B | 2 Wochen | +25–35 % | 0–80 € | ✅ Weitgehend | ✅ Haupt-Epic |
| C | 6 Wochen | +30–40 % | 0 € extra | ✅ Vollständig | ✅ Folge-Epic |

---

## 7. Synergien mit Baumschnittwart

### 7.1 Gemeinsamer Bedarf

| Feature | Pflanzenwart | Baumschnittwart | Synergie |
|---------|-------------|----------------|---------|
| Baum/Pflanze erkennen | ✅ | ✅ | 🔄 Identisch |
| Rinden-Erkennung | ✅ (Ficus-Rinde) | ✅ (Baumrinde zentral) | 🔄 Identisch |
| Multi-Organ-Support | ✅ | ✅ (Rinde besonders wichtig) | 🔄 Identisch |
| Pl@ntNet/Plant.id API-Key | ✅ | ✅ | 💡 **1 Key für beide Apps** |
| LLM-API-Key | ✅ | ✅ | 💡 **Bereits geteilt** |
| Embedding-Store | ✅ | ✅ | 💡 **Gleiche Hive-Struktur** |

### 7.2 Shared Package `plant_id_core`

Das in Konzept C vorgeschlagene Package `plant_id_core` ist der **strategische Kern** für die App-Familie:

```
monorepo-Struktur (optional, aber empfohlen):
  packages/
    plant_id_core/     ← Gemeinsamer Klassifikator-Layer
      - PlantIdentifier (abstract)
      - PlantNetService
      - PlantIdService
      - TFLiteClassifier
      - EmbeddingStore
      - IdentificationCandidate model
      - PlantOrgan enum
  apps/
    pflanzenwart/      ← nutzt plant_id_core
    baumschnittwart/   ← nutzt plant_id_core identisch
```

**Vorteil:** Bugfixes und Verbesserungen am Klassifikator-Layer profitieren sofort beide Apps. API-Key-Verwaltung kann einheitlich gestaltet werden.

### 7.3 Sofortige Synergien (ohne Konzept C)

Auch ohne neues Package können folgende Dinge geteilt werden:
- **Pl@ntNet API-Key**: Ein Key, zwei Apps – Tagesquota von 500 teilen
- **`organs[]`-Mapping**: Gleiche Enum-Werte (leaf/bark/flower/fruit/habit)
- **`IdentificationCandidate`-Modell**: Copy-paste → in beiden Repos identisch halten bis zum Shared-Package-Epic

---

## 8. Nächste Schritte (vorgeschlagene Epic-Schnitte)

### Epic 1: Bug-Fix Re-Identifikations-Kontext (Quick-Win, eigenes Ticket)
- `identification_screen.dart`: Bisherigen Namen + diagnosticNotes als Kontext-Prefix in Prompt übergeben
- Aufwand: ~2 Stunden
- Bereits als separates Bug-Ticket identifiziert

### Epic 2: Konzept A – LLM-Pipeline härten
- `temperature=0` in Claude + DeepSeek
- `candidates[]`-Schema in `plant_care_schema.dart`
- `PlantIdentificationResult` um `candidates: List<IdentificationCandidate>` erweitern
- Self-Consistency 3x + Mehrheitsentscheid in Services
- UI: Kandidaten-Liste in `identification_screen.dart`

### Epic 3: Konzept B – Pl@ntNet/Plant.id Integration
- `PlantIdentifier`/`CareAdvisor` Interface-Split in `ai_service.dart`
- `PlantNetService` implementieren
- `PlantIdService` implementieren (optional/Pro-Tier)
- Organ-Picker in `home_screen.dart`
- Settings: API-Keys für Pl@ntNet/Plant.id
- Datenschutzhinweis in App

### Epic 4: Konzept C – TFLite + Embedding (beide Apps)
- Workspace-Setup (Dart pub workspace oder Melos)
- `plant_id_core` Package erstellen
- TFLite-Modell (PlantCLEF 2024) integrieren
- Hive-Tabelle `plant_embeddings` + Cosine-Similarity
- Baumschnittwart auf `plant_id_core` migrieren

---

## Anhang: Evaluierungs-Spike

Der Python-Spike unter `tools/evaluation/` ermöglicht die automatisierte Messung der APIs gegen das Test-Set.

**Verwendung:**
```bash
cd tools
pip install -r requirements.txt
python evaluation/run_evaluation.py \
  --plantnet-key YOUR_KEY \
  --plantid-key YOUR_KEY \
  --images-dir evaluation/test_images/ \
  --output evaluation/results.json
```

**Ergebnisse auswerten:**
```bash
python evaluation/analyze_results.py evaluation/results.json
```
