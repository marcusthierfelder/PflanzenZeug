# Pflanzenwart

Flutter-App zur Pflanzenerkennung, Gesundheitsdiagnose und Pflege-Begleitung. Fotografiere deine Zimmerpflanzen und erhalte KI-gestützte Analysen, Pflegetipps und Erinnerungen.

## Features

- **Pflanzenerkennung** -- Foto machen, Pflanze wird per Claude Vision API identifiziert (deutscher + wissenschaftlicher Name)
- **Gesundheitsdiagnose** -- Erkennung von Krankheiten, Mangelernährung, Schädlingsbefall und Pilzen mit konkreten Handlungsempfehlungen
- **Verlaufsanalyse** -- Historische Fotos und frühere Diagnosen fließen in neue Analysen ein, Veränderungen werden erkannt
- **Status-Wizard** -- Regelmäßiger Check-in für Pflanzen, die länger nicht geprüft wurden
- **Gieß- und Düngeplan** -- KI-generierter Pflegeplan mit Push-Notifications
- **Dünger-Inventar** -- Vorhandene Dünger erfassen (per Foto), werden bei Empfehlungen berücksichtigt
- **Chat** -- Follow-up-Fragen pro Pflanze mit vollem Kontext (Identifikation, Diagnose, Standort)

## Voraussetzungen

- Flutter SDK (getestet mit Flutter 3.x)
- Claude API Key von [console.anthropic.com](https://console.anthropic.com)
- Python 3.8+ (nur für das QR-Code-Hilfsskript unter `tools/`)

## Setup

```bash
flutter pub get
flutter run
```

Beim ersten Start fragt die App nach deinem Claude API Key. Der Key wird lokal auf dem Gerät gespeichert.

### QR-Code-Tool (optional)

Das Hilfsskript `tools/show_qr.py` erzeugt einen QR-Code für den API-Key, damit er bequem auf ein Mobilgerät übertragen werden kann.

**Einmalige Installation der Python-Abhängigkeit:**

```bash
# Empfohlen: virtuelle Umgebung anlegen
python3 -m venv tools/.venv
source tools/.venv/bin/activate   # macOS/Linux
# tools\.venv\Scripts\activate   # Windows

pip install -r tools/requirements.txt
```

**Verwendung:**

```bash
python3 tools/show_qr.py <dein-api-key>
```

> **Hinweis:** `tools/.venv/` ist in `.gitignore` eingetragen und wird nicht ins Repository eingecheckt. Die einzige versionierte Abhängigkeitsdatei ist `tools/requirements.txt`.

## Projektstruktur

```
lib/
  main.dart                  # App-Einstiegspunkt
  models/                    # Datenmodelle (Plant, PlantPhoto, CareSchedule, ...)
  providers/                 # Riverpod State Management
  screens/                   # UI-Screens
  services/
    claude_service.dart      # Claude API Integration
    database_service.dart    # Hive-basierte lokale Datenbank
    notification_service.dart # Push-Notifications für Pflegepläne
  widgets/                   # Wiederverwendbare UI-Komponenten
```

## Technologie

- **Flutter/Dart** -- Cross-Platform (iOS, Android, Web, Desktop)
- **Riverpod** -- State Management
- **Hive** -- Lokale NoSQL-Datenbank
- **Claude API** -- Pflanzenidentifikation und Diagnose (Vision + Text)

## Lizenz

Privates Projekt.
