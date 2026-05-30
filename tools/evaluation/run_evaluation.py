#!/usr/bin/env python3
"""
Pflanzenwart v2 – Evaluierungs-Spike
====================================
Testet die Pflanzenerkennung gegen das definierte Test-Set (plant_test_set.json)
mit folgenden Backends:
  - Status Quo: Claude Sonnet (One-Shot, keine Optimierung)
  - Pl@ntNet API
  - Plant.id v3 (Kindwise)

Verwendung:
    pip install -r requirements.txt
    python evaluation/run_evaluation.py \
        --plantnet-key YOUR_PLANTNET_KEY \
        --plantid-key YOUR_PLANTID_KEY \
        --claude-key YOUR_CLAUDE_KEY \
        --images-dir evaluation/test_images/ \
        --output evaluation/results.json

    # Nur Pl@ntNet testen (kein Claude-Key nötig):
    python evaluation/run_evaluation.py \
        --plantnet-key YOUR_KEY \
        --images-dir evaluation/test_images/ \
        --output evaluation/results.json \
        --backends plantnet

Bild-Konvention:
    test_images/TC01_leaf.jpg        (Testfall-ID + Organ)
    test_images/TC01_bark.jpg
    test_images/TC16_bark.jpg
    ...

Ausgabe:
    evaluation/results.json   – Maschinenlesbare Ergebnisse je Test-Case + Backend
    (Analyse per analyze_results.py)
"""

from __future__ import annotations

import argparse
import base64
import json
import sys
import time
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Optional

# ── Optionale Dependencies mit hilfreichen Fehlermeldungen ─────────────────────
try:
    import requests
except ImportError:
    print("FEHLER: 'requests' nicht installiert. Bitte: pip install -r requirements.txt")
    sys.exit(1)

# ── Datenmodelle ────────────────────────────────────────────────────────────────

@dataclass
class IdentificationCandidate:
    rank: int
    scientific_name: str
    common_name: Optional[str]
    score: float  # 0.0 – 1.0


@dataclass
class EvaluationResult:
    test_case_id: str
    organ: str
    backend: str
    candidates: list  # List[IdentificationCandidate as dict]
    top1_correct: bool
    top3_correct: bool
    error: Optional[str] = None
    latency_ms: Optional[int] = None
    raw_response: Optional[str] = None


@dataclass
class BackendSummary:
    backend: str
    total_tests: int = 0
    top1_correct: int = 0
    top3_correct: int = 0
    errors: int = 0
    avg_latency_ms: float = 0.0


# ── Backend-Implementierungen ──────────────────────────────────────────────────

class PlantNetBackend:
    """Pl@ntNet API v2 – https://my.plantnet.org/"""

    BASE_URL = "https://my-api.plantnet.org/v2/identify/all"

    def __init__(self, api_key: str):
        self.api_key = api_key

    def identify(
        self,
        image_path: Path,
        organ: str = "leaf",
        nb_results: int = 5,
    ) -> list[IdentificationCandidate]:
        """
        Sendet ein Bild an Pl@ntNet und gibt Top-N Kandidaten zurück.
        
        organ: leaf | flower | bark | fruit | habit | auto
        """
        start = time.time()
        
        with open(image_path, "rb") as f:
            image_data = f.read()

        # Pl@ntNet erwartet multipart/form-data mit images[] und organs[]
        files = {
            "images": (image_path.name, image_data, "image/jpeg"),
        }
        params = {
            "api-key": self.api_key,
            "nb-results": nb_results,
            "lang": "de",
        }
        data = {
            "organs": organ,
        }

        response = requests.post(
            self.BASE_URL,
            params=params,
            files=files,
            data=data,
            timeout=30,
        )
        response.raise_for_status()
        latency_ms = int((time.time() - start) * 1000)

        result_json = response.json()
        candidates = []

        for i, suggestion in enumerate(result_json.get("results", []), start=1):
            species = suggestion.get("species", {})
            scientific_name = species.get("scientificName", "")
            common_names = species.get("commonNames", [])
            common_name = common_names[0] if common_names else None
            score = suggestion.get("score", 0.0)

            candidates.append(IdentificationCandidate(
                rank=i,
                scientific_name=scientific_name,
                common_name=common_name,
                score=score,
            ))

        return candidates, latency_ms


class PlantIdBackend:
    """Plant.id v3 (Kindwise) – https://web.plant.id/

    Nutzt den Kindwise-v3-Endpoint (api.plant.id/v3). Falls Kindwise später
    auf api.kindwise.com migriert, ggf. BASE_URL anpassen.
    """

    BASE_URL = "https://plant.id/api/v3/identification"

    def __init__(self, api_key: str):
        self.api_key = api_key

    def identify(
        self,
        image_path: Path,
        organ: str = "leaf",
        nb_results: int = 5,
    ) -> tuple[list[IdentificationCandidate], int]:
        """
        Sendet ein Bild an Plant.id v3 und gibt Top-N Kandidaten zurück.
        """
        start = time.time()

        with open(image_path, "rb") as f:
            image_b64 = base64.b64encode(f.read()).decode("utf-8")

        payload = {
            "images": [f"data:image/jpeg;base64,{image_b64}"],
            "similar_images": False,
            "classification_level": "species",
            "details": ["common_names"],
            "language": "de",
        }

        headers = {
            "Api-Key": self.api_key,
            "Content-Type": "application/json",
        }

        response = requests.post(
            self.BASE_URL,
            json=payload,
            headers=headers,
            timeout=30,
        )
        response.raise_for_status()
        latency_ms = int((time.time() - start) * 1000)

        result_json = response.json()
        candidates = []

        result_data = result_json.get("result", {})
        suggestions = result_data.get("classification", {}).get("suggestions", [])
        
        for i, suggestion in enumerate(suggestions[:nb_results], start=1):
            scientific_name = suggestion.get("name", "")
            details = suggestion.get("details", {})
            common_names = details.get("common_names", []) if details else []
            common_name = common_names[0] if common_names else None
            probability = suggestion.get("probability", 0.0)

            candidates.append(IdentificationCandidate(
                rank=i,
                scientific_name=scientific_name,
                common_name=common_name,
                score=probability,
            ))

        return candidates, latency_ms


class ClaudeStatusQuoBackend:
    """
    Status-Quo-Backend: Claude Sonnet – One-Shot ohne Optimierung.
    Entspricht dem aktuellen claude_service.dart identifyPlant().
    Gibt Top-1 zurück (kein echtes Top-K ohne Schema-Erweiterung).
    """

    API_URL = "https://api.anthropic.com/v1/messages"
    MODEL = "claude-sonnet-4-20250514"

    PROMPT = """Identifiziere diese Pflanze anhand des Fotos.
Antworte AUSSCHLIESSLICH mit einem JSON-Objekt in diesem Format:
{
  "name": "Deutscher Name",
  "scientific_name": "Gattung Art",
  "confidence": 85,
  "candidates": [
    {"rank": 1, "scientific_name": "...", "confidence": 85},
    {"rank": 2, "scientific_name": "...", "confidence": 10},
    {"rank": 3, "scientific_name": "...", "confidence": 5}
  ]
}
Gib immer die Top-3 wahrscheinlichsten Kandidaten an."""

    def __init__(self, api_key: str):
        self.api_key = api_key

    def identify(
        self,
        image_path: Path,
        organ: str = "leaf",
        nb_results: int = 3,
    ) -> tuple[list[IdentificationCandidate], int]:
        start = time.time()

        with open(image_path, "rb") as f:
            image_b64 = base64.b64encode(f.read()).decode("utf-8")

        headers = {
            "Content-Type": "application/json",
            "x-api-key": self.api_key,
            "anthropic-version": "2023-06-01",
        }

        payload = {
            "model": self.MODEL,
            "max_tokens": 512,
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "image",
                            "source": {
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": image_b64,
                            },
                        },
                        {"type": "text", "text": self.PROMPT},
                    ],
                },
                {"role": "assistant", "content": "{"},
            ],
        }

        response = requests.post(
            self.API_URL,
            json=payload,
            headers=headers,
            timeout=60,
        )
        response.raise_for_status()
        latency_ms = int((time.time() - start) * 1000)

        result_json = response.json()
        text_blocks = [
            block["text"]
            for block in result_json.get("content", [])
            if block.get("type") == "text"
        ]
        raw_text = "{" + "".join(text_blocks)

        try:
            data = json.loads(raw_text)
        except json.JSONDecodeError:
            # Versuche JSON aus dem Text zu extrahieren
            import re
            match = re.search(r"\{.*\}", raw_text, re.DOTALL)
            if match:
                data = json.loads(match.group())
            else:
                raise ValueError(f"Kein JSON in Antwort: {raw_text[:200]}")

        candidates = []
        raw_candidates = data.get("candidates", [])

        if raw_candidates:
            for c in raw_candidates[:nb_results]:
                candidates.append(IdentificationCandidate(
                    rank=c.get("rank", len(candidates) + 1),
                    scientific_name=c.get("scientific_name", ""),
                    common_name=c.get("name"),
                    score=c.get("confidence", 0) / 100.0,
                ))
        else:
            # Fallback: Nur Top-1 aus name/scientific_name
            scientific_name = data.get("scientific_name", "")
            common_name = data.get("name")
            confidence = data.get("confidence", 0) / 100.0
            if scientific_name:
                candidates.append(IdentificationCandidate(
                    rank=1,
                    scientific_name=scientific_name,
                    common_name=common_name,
                    score=confidence,
                ))

        return candidates, latency_ms


# ── Evaluierungs-Logik ─────────────────────────────────────────────────────────

def normalize_scientific_name(name: str) -> str:
    """Normalisiert wissenschaftliche Namen für Vergleich (Groß/Kleinschreibung, Whitespace)."""
    return name.strip().lower().replace("  ", " ")


def is_correct(candidates: list[IdentificationCandidate], expected: str) -> bool:
    """Prüft ob expected im Kandidaten-Set enthalten ist."""
    expected_norm = normalize_scientific_name(expected)
    for candidate in candidates:
        if normalize_scientific_name(candidate.scientific_name) == expected_norm:
            return True
        # Teilname-Match (z.B. "Acer pseudoplatanus L." matcht "Acer pseudoplatanus")
        if expected_norm in normalize_scientific_name(candidate.scientific_name):
            return True
        if normalize_scientific_name(candidate.scientific_name) in expected_norm:
            return True
    return False


def run_evaluation(
    test_set_path: Path,
    images_dir: Path,
    backends: dict,
    output_path: Path,
    max_cases: Optional[int] = None,
    delay_between_calls: float = 1.0,
) -> None:
    """
    Führt die vollständige Evaluation durch.

    backends: {"plantnet": PlantNetBackend, "plantid": PlantIdBackend, "claude": ClaudeStatusQuoBackend}
    """
    with open(test_set_path) as f:
        test_set = json.load(f)

    test_cases = test_set["test_cases"]
    if max_cases:
        test_cases = test_cases[:max_cases]

    results = []
    summaries: dict[str, BackendSummary] = {
        name: BackendSummary(backend=name) for name in backends
    }

    total = len(test_cases) * len(backends)
    current = 0

    for tc in test_cases:
        tc_id = tc["id"]
        expected_top1 = tc["expected_top1"]
        expected_top3 = tc.get("expected_in_top3", [expected_top1])
        primary_organ = tc.get("organs_primary", "leaf")

        # Primäres Organ testen (für schnellere Evaluierung)
        organs_to_test = [primary_organ]

        for organ in organs_to_test:
            # Bild-Pfad ermitteln
            image_path = images_dir / f"{tc_id}_{organ}.jpg"
            if not image_path.exists():
                # Versuche andere Extensions
                for ext in [".jpeg", ".png", ".JPG", ".JPEG"]:
                    alt = images_dir / f"{tc_id}_{organ}{ext}"
                    if alt.exists():
                        image_path = alt
                        break

            for backend_name, backend in backends.items():
                current += 1
                print(f"[{current}/{total}] {tc_id} ({organ}) → {backend_name} ... ", end="", flush=True)

                summary = summaries[backend_name]
                summary.total_tests += 1

                if not image_path.exists():
                    print(f"⚠️  Bild nicht gefunden: {image_path}")
                    results.append(asdict(EvaluationResult(
                        test_case_id=tc_id,
                        organ=organ,
                        backend=backend_name,
                        candidates=[],
                        top1_correct=False,
                        top3_correct=False,
                        error=f"Bild nicht gefunden: {image_path}",
                    )))
                    summary.errors += 1
                    continue

                try:
                    candidates, latency_ms = backend.identify(
                        image_path=image_path,
                        organ=organ,
                    )

                    top1_correct = len(candidates) > 0 and is_correct(
                        candidates[:1], expected_top1
                    )
                    top3_correct = any(
                        is_correct(candidates[:3], exp) for exp in expected_top3
                    )

                    result = EvaluationResult(
                        test_case_id=tc_id,
                        organ=organ,
                        backend=backend_name,
                        candidates=[asdict(c) for c in candidates],
                        top1_correct=top1_correct,
                        top3_correct=top3_correct,
                        latency_ms=latency_ms,
                    )

                    status = "✅" if top1_correct else ("⚠️ " if top3_correct else "❌")
                    top1_name = candidates[0].scientific_name if candidates else "(leer)"
                    print(f"{status} Top-1: {top1_name} ({latency_ms}ms)")

                    if top1_correct:
                        summary.top1_correct += 1
                    if top3_correct:
                        summary.top3_correct += 1

                    # Gleitender Latenz-Durchschnitt
                    n = summary.total_tests - summary.errors
                    if n > 0:
                        summary.avg_latency_ms = (
                            (summary.avg_latency_ms * (n - 1) + latency_ms) / n
                        )

                except requests.exceptions.HTTPError as e:
                    print(f"❌ HTTP-Fehler: {e}")
                    results.append(asdict(EvaluationResult(
                        test_case_id=tc_id,
                        organ=organ,
                        backend=backend_name,
                        candidates=[],
                        top1_correct=False,
                        top3_correct=False,
                        error=str(e),
                    )))
                    summary.errors += 1

                except Exception as e:
                    print(f"❌ Fehler: {e}")
                    results.append(asdict(EvaluationResult(
                        test_case_id=tc_id,
                        organ=organ,
                        backend=backend_name,
                        candidates=[],
                        top1_correct=False,
                        top3_correct=False,
                        error=str(e),
                    )))
                    summary.errors += 1

                else:
                    results.append(asdict(result))

                # Rate-Limiting: Pause zwischen API-Calls
                time.sleep(delay_between_calls)

    # Ausgabe schreiben
    output = {
        "meta": {
            "test_set": str(test_set_path),
            "images_dir": str(images_dir),
            "total_cases": len(test_cases),
            "backends": list(backends.keys()),
        },
        "summaries": {name: asdict(s) for name, s in summaries.items()},
        "results": results,
    }

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    # Kurze Zusammenfassung in der Konsole
    print("\n" + "=" * 60)
    print("EVALUIERUNGS-ZUSAMMENFASSUNG")
    print("=" * 60)
    for name, summary in summaries.items():
        valid = summary.total_tests - summary.errors
        top1_pct = (summary.top1_correct / valid * 100) if valid > 0 else 0
        top3_pct = (summary.top3_correct / valid * 100) if valid > 0 else 0
        print(f"\n{name.upper()}:")
        print(f"  Tests:          {valid}/{summary.total_tests} (Fehler: {summary.errors})")
        print(f"  Top-1 korrekt:  {summary.top1_correct}/{valid} = {top1_pct:.1f}%")
        print(f"  Top-3 korrekt:  {summary.top3_correct}/{valid} = {top3_pct:.1f}%")
        print(f"  Ø Latenz:       {summary.avg_latency_ms:.0f}ms")
    print(f"\nErgebnisse gespeichert: {output_path}")


# ── CLI ────────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Pflanzenwart v2 – Evaluierungs-Spike",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Beispiele:
  # Alle Backends
  python evaluation/run_evaluation.py \\
      --plantnet-key YOUR_KEY \\
      --plantid-key YOUR_KEY \\
      --claude-key YOUR_KEY \\
      --images-dir evaluation/test_images/

  # Nur Pl@ntNet (kostenlos):
  python evaluation/run_evaluation.py \\
      --plantnet-key YOUR_KEY \\
      --images-dir evaluation/test_images/ \\
      --backends plantnet

  # Nur ersten 5 Fälle (Schnelltest):
  python evaluation/run_evaluation.py \\
      --plantnet-key YOUR_KEY \\
      --images-dir evaluation/test_images/ \\
      --max-cases 5
        """,
    )
    parser.add_argument("--plantnet-key", help="Pl@ntNet API-Key (my.plantnet.org)")
    parser.add_argument("--plantid-key", help="Plant.id API-Key (kindwise.com)")
    parser.add_argument("--claude-key", help="Claude API-Key (anthropic.com)")
    parser.add_argument(
        "--images-dir",
        default="evaluation/test_images",
        help="Verzeichnis mit Testbildern (Default: evaluation/test_images/)",
    )
    parser.add_argument(
        "--test-set",
        default="evaluation/plant_test_set.json",
        help="Test-Set JSON (Default: evaluation/plant_test_set.json)",
    )
    parser.add_argument(
        "--output",
        default="evaluation/results.json",
        help="Ausgabe-Datei (Default: evaluation/results.json)",
    )
    parser.add_argument(
        "--backends",
        nargs="+",
        choices=["plantnet", "plantid", "claude"],
        help="Welche Backends testen (Default: alle konfigurierten)",
    )
    parser.add_argument(
        "--max-cases",
        type=int,
        help="Maximale Anzahl Test-Fälle (für Schnelltests)",
    )
    parser.add_argument(
        "--delay",
        type=float,
        default=1.0,
        help="Pause zwischen API-Calls in Sekunden (Default: 1.0, für Rate-Limiting)",
    )

    args = parser.parse_args()

    # Backends konfigurieren
    backends = {}
    requested = args.backends or ["plantnet", "plantid", "claude"]

    if "plantnet" in requested:
        if not args.plantnet_key:
            print("⚠️  --plantnet-key fehlt → Pl@ntNet wird übersprungen")
        else:
            backends["plantnet"] = PlantNetBackend(args.plantnet_key)
            print("✓ Pl@ntNet Backend konfiguriert")

    if "plantid" in requested:
        if not args.plantid_key:
            print("⚠️  --plantid-key fehlt → Plant.id wird übersprungen")
        else:
            backends["plantid"] = PlantIdBackend(args.plantid_key)
            print("✓ Plant.id Backend konfiguriert")

    if "claude" in requested:
        if not args.claude_key:
            print("⚠️  --claude-key fehlt → Claude (Status Quo) wird übersprungen")
        else:
            backends["claude"] = ClaudeStatusQuoBackend(args.claude_key)
            print("✓ Claude (Status Quo) Backend konfiguriert")

    if not backends:
        print("❌ Keine Backends konfiguriert. Mindestens einen API-Key angeben.")
        parser.print_help()
        sys.exit(1)

    test_set_path = Path(args.test_set)
    if not test_set_path.exists():
        print(f"❌ Test-Set nicht gefunden: {test_set_path}")
        sys.exit(1)

    images_dir = Path(args.images_dir)
    if not images_dir.exists():
        print(f"⚠️  Bilder-Verzeichnis existiert nicht: {images_dir}")
        print("   Erstelle Verzeichnis und füge Testbilder hinzu.")
        print("   Naming-Konvention: TC01_leaf.jpg, TC01_bark.jpg, ...")
        images_dir.mkdir(parents=True, exist_ok=True)

    output_path = Path(args.output)

    print(f"\nStarte Evaluation: {len(backends)} Backend(s)")
    print(f"Test-Set: {test_set_path}")
    print(f"Bilder:   {images_dir}")
    print(f"Output:   {output_path}\n")

    run_evaluation(
        test_set_path=test_set_path,
        images_dir=images_dir,
        backends=backends,
        output_path=output_path,
        max_cases=args.max_cases,
        delay_between_calls=args.delay,
    )


if __name__ == "__main__":
    main()
