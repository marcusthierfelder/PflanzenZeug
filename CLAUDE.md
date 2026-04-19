# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PflanzenZeug is a Flutter/Dart mobile app for plant identification and care. Users photograph a plant, the app identifies it via the Claude API (vision), diagnoses diseases/deficiencies, and provides care recommendations. A follow-up chat allows asking further questions about the identified plant.

The entire UI and all prompts are in **German**.

## Common Commands

```bash
flutter run              # Run on connected device/emulator
flutter build apk        # Build Android APK
flutter build ios        # Build iOS app
flutter analyze          # Run static analysis (uses flutter_lints)
flutter test             # Run all tests
flutter test test/widget_test.dart  # Run a single test file
```

## Architecture

**State management:** Riverpod (`flutter_riverpod`). The app wraps in `ProviderScope` at the root.

**Screen flow (imperative Navigator.push):**
1. `ApiKeyWizardScreen` — shown when no API key is stored; collects and persists a Claude API key via `shared_preferences`
2. `HomeScreen` — camera/gallery image picker; collects one or more photos
3. `IdentificationScreen` — sends images to Claude for plant identification
4. `DiagnosisScreen` — sends images + plant name for health/disease/care analysis (auto-starts on mount)
5. `ChatScreen` — multi-turn conversation about the identified plant, seeded with identification + diagnosis context

**Key service:** `ClaudeService` (`lib/services/claude_service.dart`) — handles all Claude API calls. Sends base64-encoded images with German-language prompts to `POST /v1/messages`. Uses `claude-sonnet-4-20250514` with a German system prompt.

**API key management:** `ApiKeyNotifier` (Riverpod `AsyncNotifier`) reads/writes the key from `shared_preferences`. The root `MaterialApp` conditionally renders the wizard or home screen based on key presence.

## Dependencies

- `image_picker` — camera and gallery access
- `http` — raw HTTP for Claude API (no Anthropic SDK)
- `shared_preferences` — local API key storage
- `flutter_riverpod` — state management
