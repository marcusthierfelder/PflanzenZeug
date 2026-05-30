"""
Smoke-Tests für den Pflanzenwart v2 Evaluierungs-Spike.
Tests prüfen: Test-Set-Integrität, Normalisierungsfunktionen, Analyse-Logik.
Keine echten API-Calls – alles gemockt.
"""

import json
import sys
import tempfile
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

# Pfad zum evaluation-Verzeichnis hinzufügen
sys.path.insert(0, str(Path(__file__).parent.parent / "evaluation"))


# ── Test-Set-Integrität ────────────────────────────────────────────────────────

class TestPlantTestSet:
    """Prüft die Integrität des plant_test_set.json."""

    @pytest.fixture
    def test_set_path(self):
        return Path(__file__).parent.parent / "evaluation" / "plant_test_set.json"

    def test_test_set_exists(self, test_set_path):
        assert test_set_path.exists(), "plant_test_set.json muss existieren"

    def test_test_set_has_20_cases(self, test_set_path):
        with open(test_set_path) as f:
            data = json.load(f)
        cases = data["test_cases"]
        assert len(cases) >= 20, f"Mindestens 20 Testfälle erwartet, gefunden: {len(cases)}"

    def test_all_cases_have_required_fields(self, test_set_path):
        required_fields = [
            "id", "common_name_de", "scientific_name",
            "expected_top1", "organs_primary",
        ]
        with open(test_set_path) as f:
            data = json.load(f)
        for tc in data["test_cases"]:
            for field in required_fields:
                assert field in tc, f"Feld '{field}' fehlt in Testfall {tc.get('id', '?')}"

    def test_tc01_is_berg_ahorn(self, test_set_path):
        """TC01 muss der Berg-Ahorn (Tatiana-Referenzfall) sein."""
        with open(test_set_path) as f:
            data = json.load(f)
        tc01 = next(tc for tc in data["test_cases"] if tc["id"] == "TC01")
        assert "Acer pseudoplatanus" in tc01["scientific_name"]
        assert tc01["difficulty"] == "high"
        assert len(tc01["confusable_with"]) >= 2

    def test_all_ids_unique(self, test_set_path):
        with open(test_set_path) as f:
            data = json.load(f)
        ids = [tc["id"] for tc in data["test_cases"]]
        assert len(ids) == len(set(ids)), "Alle Test-Case-IDs müssen eindeutig sein"

    def test_includes_trees_and_indoor_and_herbs(self, test_set_path):
        with open(test_set_path) as f:
            data = json.load(f)
        categories = {tc["category"] for tc in data["test_cases"]}
        assert "baum" in categories or "baum_zimmer" in categories
        assert "zimmerpflanze" in categories
        assert "kraut" in categories


# ── Normalisierungs-Logik ──────────────────────────────────────────────────────

class TestNormalization:
    """Testet die Normalisierung wissenschaftlicher Namen."""

    def setup_method(self):
        from run_evaluation import normalize_scientific_name, IdentificationCandidate, is_correct
        self.normalize = normalize_scientific_name
        self.is_correct = is_correct
        self.Candidate = IdentificationCandidate

    def test_normalize_strips_whitespace(self):
        assert self.normalize("  Acer pseudoplatanus  ") == "acer pseudoplatanus"

    def test_normalize_lowercases(self):
        assert self.normalize("Acer Pseudoplatanus") == "acer pseudoplatanus"

    def test_is_correct_exact_match(self):
        candidates = [
            self.Candidate(1, "Acer pseudoplatanus", "Berg-Ahorn", 0.87),
            self.Candidate(2, "Sambucus nigra", "Holunder", 0.08),
        ]
        assert self.is_correct(candidates, "Acer pseudoplatanus")

    def test_is_correct_partial_match_author(self):
        """Autoren-Suffix sollte ignoriert werden."""
        candidates = [
            self.Candidate(1, "Acer pseudoplatanus L.", "Berg-Ahorn", 0.87),
        ]
        assert self.is_correct(candidates, "Acer pseudoplatanus")

    def test_is_correct_false_for_wrong(self):
        candidates = [
            self.Candidate(1, "Sambucus nigra", "Holunder", 0.92),
        ]
        assert not self.is_correct(candidates, "Acer pseudoplatanus")

    def test_is_correct_empty_candidates(self):
        assert not self.is_correct([], "Acer pseudoplatanus")


# ── Analyse-Logik ──────────────────────────────────────────────────────────────

class TestAnalyzeResults:
    """Testet die Analyse-Funktionen für Evaluierungsergebnisse."""

    @pytest.fixture
    def sample_results(self):
        return {
            "meta": {
                "test_set": "evaluation/plant_test_set.json",
                "images_dir": "evaluation/test_images",
                "total_cases": 3,
                "backends": ["plantnet", "claude"],
            },
            "summaries": {
                "plantnet": {
                    "backend": "plantnet",
                    "total_tests": 3,
                    "top1_correct": 2,
                    "top3_correct": 3,
                    "errors": 0,
                    "avg_latency_ms": 850.0,
                },
                "claude": {
                    "backend": "claude",
                    "total_tests": 3,
                    "top1_correct": 1,
                    "top3_correct": 2,
                    "errors": 1,
                    "avg_latency_ms": 4500.0,
                },
            },
            "results": [
                {
                    "test_case_id": "TC01",
                    "organ": "leaf",
                    "backend": "plantnet",
                    "candidates": [
                        {"rank": 1, "scientific_name": "Acer pseudoplatanus", "common_name": "Berg-Ahorn", "score": 0.87},
                    ],
                    "top1_correct": True,
                    "top3_correct": True,
                    "latency_ms": 900,
                    "error": None,
                },
                {
                    "test_case_id": "TC01",
                    "organ": "leaf",
                    "backend": "claude",
                    "candidates": [
                        {"rank": 1, "scientific_name": "Sambucus nigra", "common_name": "Holunder", "score": 0.6},
                    ],
                    "top1_correct": False,
                    "top3_correct": False,
                    "latency_ms": 5000,
                    "error": None,
                },
            ],
        }

    def test_render_markdown_contains_summary_table(self, sample_results, tmp_path):
        """Markdown-Report muss eine Gesamtübersicht enthalten."""
        from analyze_results import render_markdown_report
        report = render_markdown_report(sample_results)
        assert "## Gesamtübersicht" in report
        assert "plantnet" in report.lower()
        assert "claude" in report.lower()

    def test_render_markdown_contains_percentage(self, sample_results):
        from analyze_results import render_markdown_report
        report = render_markdown_report(sample_results)
        # 2/3 = 66.7% für plantnet Top-1
        assert "66.7%" in report or "67.7%" in report or "2/3" in report

    def test_per_case_summary_correct(self, sample_results):
        from analyze_results import compute_per_case_summary
        per_case = compute_per_case_summary(sample_results["results"], "plantnet")
        assert "TC01" in per_case
        assert per_case["TC01"]["top1_correct"] is True
        assert per_case["TC01"]["top1_candidate"] == "Acer pseudoplatanus"

    def test_per_case_summary_claude_wrong(self, sample_results):
        from analyze_results import compute_per_case_summary
        per_case = compute_per_case_summary(sample_results["results"], "claude")
        assert "TC01" in per_case
        assert per_case["TC01"]["top1_correct"] is False


# ── Mocked Backend-Tests ───────────────────────────────────────────────────────

class TestPlantNetBackend:
    """Testet den PlantNetBackend mit gemocktem HTTP."""

    def test_identify_parses_response(self, tmp_path):
        from run_evaluation import PlantNetBackend

        # Minimales JPEG erstellen
        test_image = tmp_path / "test.jpg"
        test_image.write_bytes(b"\xff\xd8\xff\xe0" + b"\x00" * 100)  # Fake-JPEG Header

        mock_response = {
            "results": [
                {
                    "species": {
                        "scientificName": "Acer pseudoplatanus",
                        "commonNames": ["Berg-Ahorn"],
                    },
                    "score": 0.87,
                },
                {
                    "species": {
                        "scientificName": "Sambucus nigra",
                        "commonNames": ["Schwarzer Holunder"],
                    },
                    "score": 0.08,
                },
            ],
            "remainingIdentificationRequests": 450,
        }

        with patch("requests.post") as mock_post:
            mock_resp = MagicMock()
            mock_resp.raise_for_status.return_value = None
            mock_resp.json.return_value = mock_response
            mock_post.return_value = mock_resp

            backend = PlantNetBackend(api_key="test-key")
            candidates, latency = backend.identify(test_image, organ="leaf")

        assert len(candidates) == 2
        assert candidates[0].scientific_name == "Acer pseudoplatanus"
        assert candidates[0].score == pytest.approx(0.87)
        assert candidates[1].scientific_name == "Sambucus nigra"
        assert isinstance(latency, int)

    def test_identify_empty_results(self, tmp_path):
        from run_evaluation import PlantNetBackend

        test_image = tmp_path / "test.jpg"
        test_image.write_bytes(b"\xff\xd8\xff\xe0" + b"\x00" * 100)

        with patch("requests.post") as mock_post:
            mock_resp = MagicMock()
            mock_resp.raise_for_status.return_value = None
            mock_resp.json.return_value = {"results": []}
            mock_post.return_value = mock_resp

            backend = PlantNetBackend(api_key="test-key")
            candidates, _ = backend.identify(test_image)

        assert candidates == []
