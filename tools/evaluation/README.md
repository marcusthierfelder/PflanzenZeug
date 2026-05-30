# Pflanzenwart v2 – Evaluierungs-Spike

Dieses Verzeichnis enthält die Werkzeuge für den Evaluierungs-Spike der
Pflanzenerkennung v2 (Ticket #11).

## Struktur

```
evaluation/
  plant_test_set.json    – 20 bekannte Testpflanzen (maschinenlesbar)
  run_evaluation.py      – Hauptskript: testet APIs gegen Test-Set
  analyze_results.py     – Analysiert results.json, erzeugt Markdown-Report
  test_images/           – Testbilder ablegen (nicht im Git-Repo)
  results.json           – Ergebnisse (nach Ausführung, nicht ins Git)
  README.md              – Diese Datei
```

## Voraussetzungen

```bash
cd tools
pip install -r requirements.txt
```

## Testbilder bereitstellen

Naming-Konvention: `<TC-ID>_<organ>.jpg`

```
test_images/
  TC01_leaf.jpg      # Berg-Ahorn, Blatt
  TC01_bark.jpg      # Berg-Ahorn, Rinde
  TC02_leaf.jpg      # Spitz-Ahorn, Blatt
  TC03_leaf.jpg      # Schwarzer Holunder, Blatt
  TC08_leaf.jpg      # Monstera, Blatt
  TC16_bark.jpg      # Birke, Rinde (weiße Birkenrinde)
  ...
```

Verfügbare Organe: `leaf`, `bark`, `flower`, `fruit`, `habit`

**Hinweis:** Das primäre Organ je Testfall ist in `plant_test_set.json`
unter `organs_primary` definiert. Für die Schnellauswertung reicht das
primäre Organ.

## Verwendung

### Vollständige Evaluation

```bash
python evaluation/run_evaluation.py \
  --plantnet-key YOUR_PLANTNET_KEY \
  --plantid-key YOUR_PLANTID_KEY \
  --claude-key YOUR_CLAUDE_KEY \
  --images-dir evaluation/test_images/
```

### Nur Pl@ntNet (kostenlos, kein Key für Plant.id/Claude nötig)

```bash
python evaluation/run_evaluation.py \
  --plantnet-key YOUR_PLANTNET_KEY \
  --images-dir evaluation/test_images/ \
  --backends plantnet
```

### Schnelltest (erste 5 Fälle)

```bash
python evaluation/run_evaluation.py \
  --plantnet-key YOUR_PLANTNET_KEY \
  --images-dir evaluation/test_images/ \
  --max-cases 5
```

### Ergebnisse analysieren

```bash
# Text-Ausgabe
python evaluation/analyze_results.py evaluation/results.json

# Markdown-Report generieren
python evaluation/analyze_results.py evaluation/results.json \
  --output evaluation/report.md \
  --format markdown
```

## API-Keys beschaffen

### Pl@ntNet (kostenlos, 500 Calls/Tag)
1. https://my.plantnet.org/ → Account erstellen
2. Dashboard → API-Key kopieren

### Plant.id (Free-Tier: 100 Calls/Monat)
1. https://web.plant.id/ → Account erstellen
2. Dashboard → API-Key

### Claude
1. https://console.anthropic.com/ → API-Key

## Test-Set: 20 Testpflanzen

| ID | Pflanze | Schwierigkeit | Besonderheit |
|----|---------|--------------|-------------|
| TC01 | Berg-Ahorn | ⭐⭐⭐ | Tatiana-Referenzfall |
| TC02 | Spitz-Ahorn | ⭐⭐ | Verwechslung mit TC01 |
| TC03 | Schwarzer Holunder | ⭐⭐⭐ | Jungblätter wie Ahorn |
| TC04 | Weinrebe | ⭐⭐⭐ | Handförmig gelappt |
| TC05 | Echte Feige | ⭐⭐⭐ | Handförmig gelappt |
| TC06 | Gummibaum | ⭐⭐ | Zimmerpflanze |
| TC07 | Geigenblatt-Feige | ⭐⭐ | Zimmerpflanze |
| TC08 | Monstera | ⭐ | Zimmerpflanze (einfach) |
| TC09 | Efeutute | ⭐⭐ | Verwechslung mit Philodendron |
| TC10 | Herzblatt-Philodendron | ⭐⭐ | Verwechslung mit Efeutute |
| TC11 | Aloe vera | ⭐ | Sukkulente (einfach) |
| TC12 | Jade-Pflanze | ⭐⭐ | Sukkulente |
| TC13 | Phalaenopsis-Orchidee | ⭐ | Zimmerpflanze (einfach) |
| TC14 | Zimmer-Linde | ⭐⭐⭐ | Selten, schwierig |
| TC15 | Stiel-Eiche | ⭐⭐ | Baum mit Eicheln |
| TC16 | Hänge-Birke | ⭐ | Weiße Rinde ikonisch |
| TC17 | Rotbuche | ⭐⭐ | Rinde diagnostisch |
| TC18 | Rosmarin | ⭐ | Kraut (einfach) |
| TC19 | Echter Lavendel | ⭐⭐ | Kraut |
| TC20 | Basilikum | ⭐ | Kraut (einfach) |

## Erwartete Ergebnisse

Basierend auf publizierten Benchmarks (vor tatsächlicher Messung):

| Backend | Top-1 (erwartet) | Top-3 (erwartet) |
|---------|-----------------|-----------------|
| Claude Status Quo | ~55–70 % | ~75–85 % |
| Pl@ntNet | ~80–85 % | ~90–93 % |
| Plant.id v3 | ~87–93 % | ~93–96 % |

**Kritischer Cluster TC01–TC05** (handförmig gelappte Blätter):
- Claude: ~40–50 % Top-1 erwartet
- Pl@ntNet: ~80–85 % Top-1 erwartet
- Plant.id: ~85–90 % Top-1 erwartet
