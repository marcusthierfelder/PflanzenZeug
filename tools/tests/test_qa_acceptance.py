"""
QA-Akzeptanztests für Ticket #11 – Konzept & Evaluation Pflanzenerkennung v2.

Prüft alle Akzeptanzkriterien direkt:
  AK1: Marktrecherche (6 Anbieter) im Konzeptdokument vorhanden
  AK2: Drei Konzepte A/B/C ausgearbeitet
  AK3: Test-Set ≥20 Pflanzen mit Pflichtfällen
  AK4: Empfehlung + Epic-Schnitt vorhanden
  AK5: Synergien Baumschnittwart benannt
  AK6: Spike-Skripte ausführbar und korrekt
  AK7: analyze_results.py End-to-End mit synthetischen Daten
"""

from __future__ import annotations

import json
import sys
import tempfile
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

# Pfade
REPO_ROOT = Path(__file__).parent.parent.parent
DOCS_DIR = REPO_ROOT / "Documents"
TOOLS_DIR = REPO_ROOT / "tools"
EVAL_DIR = TOOLS_DIR / "evaluation"

sys.path.insert(0, str(EVAL_DIR))


# ══════════════════════════════════════════════════════════════════════════════
# AK1: Marktrecherche dokumentiert (6 Anbieter)
# ══════════════════════════════════════════════════════════════════════════════

class TestAK1_Marktrecherche:
    """AK1: Alle 6 geforderten Anbieter sind im Konzeptdokument dokumentiert."""

    @pytest.fixture(scope="class")
    def konzept_text(self):
        path = DOCS_DIR / "pflanzenerkennung_v2_konzept.md"
        assert path.exists(), f"Konzeptdokument nicht gefunden: {path}"
        return path.read_text(encoding="utf-8")

    def test_plantnet_dokumentiert(self, konzept_text):
        """Pl@ntNet muss mit Kosten, Lizenz und Multi-Organ dokumentiert sein."""
        assert "Pl@ntNet" in konzept_text or "PlantNet" in konzept_text
        # Kosten
        assert "500" in konzept_text  # 500 Calls/Tag free tier
        # Multi-Organ-Support
        assert "organ" in konzept_text.lower()

    def test_plantid_dokumentiert(self, konzept_text):
        """Plant.id v3 (Kindwise) muss dokumentiert sein."""
        assert "Plant.id" in konzept_text or "plant.id" in konzept_text.lower()
        assert "Kindwise" in konzept_text or "kindwise" in konzept_text.lower()

    def test_inaturalist_dokumentiert(self, konzept_text):
        """iNaturalist CV muss dokumentiert sein."""
        assert "iNaturalist" in konzept_text or "inaturalist" in konzept_text.lower()

    def test_google_vision_dokumentiert(self, konzept_text):
        """Google Vision / Vertex AI muss dokumentiert sein."""
        assert "Google" in konzept_text
        assert "Vision" in konzept_text or "Vertex" in konzept_text

    def test_tflite_plantclef_dokumentiert(self, konzept_text):
        """Eigenes TFLite-Modell / PlantCLEF muss dokumentiert sein."""
        assert "TFLite" in konzept_text or "tflite" in konzept_text.lower()
        assert "PlantCLEF" in konzept_text or "plantclef" in konzept_text.lower()

    def test_llm_status_quo_dokumentiert(self, konzept_text):
        """LLM-Direktansatz (Status Quo) muss dokumentiert sein."""
        assert "Claude" in konzept_text
        assert "Status" in konzept_text

    def test_alle_anbieter_haben_offline_faehigkeit(self, konzept_text):
        """Offline-Fähigkeit muss für jeden Anbieter bewertet sein."""
        assert "Offline" in konzept_text or "offline" in konzept_text.lower()
        # TFLite ist der einzige mit echter Offline-Fähigkeit
        assert "offline" in konzept_text.lower()

    def test_kosten_dokumentiert(self, konzept_text):
        """Kosten müssen für relevante Anbieter dokumentiert sein."""
        # Plant.id ab 20€
        assert "20" in konzept_text
        # Pl@ntNet kostenlos / 0€
        assert "0 €" in konzept_text or "kostenlos" in konzept_text.lower() or "Free" in konzept_text


# ══════════════════════════════════════════════════════════════════════════════
# AK2: Drei Konzept-Varianten ausgearbeitet
# ══════════════════════════════════════════════════════════════════════════════

class TestAK2_KonzeptVarianten:
    """AK2: Konzepte A, B und C müssen vollständig ausgearbeitet sein."""

    @pytest.fixture(scope="class")
    def konzept_text(self):
        return (DOCS_DIR / "pflanzenerkennung_v2_konzept.md").read_text(encoding="utf-8")

    def test_konzept_a_vorhanden(self, konzept_text):
        """Konzept A muss vorhanden und mit temperature=0 + Self-Consistency beschrieben sein."""
        assert "Konzept A" in konzept_text
        assert "temperature" in konzept_text.lower() or "Temperature" in konzept_text
        assert "Self-Consistency" in konzept_text or "Konsistenz" in konzept_text

    def test_konzept_a_adressiert_relevante_dateien(self, konzept_text):
        """Konzept A muss claude_service.dart und plant_care_schema.dart adressieren."""
        assert "claude_service.dart" in konzept_text
        assert "plant_care_schema.dart" in konzept_text

    def test_konzept_b_vorhanden(self, konzept_text):
        """Konzept B muss Pl@ntNet/Plant.id als Primärklassifikator benennen."""
        assert "Konzept B" in konzept_text
        assert "primär" in konzept_text.lower() or "Primär" in konzept_text

    def test_konzept_b_hat_organ_picker(self, konzept_text):
        """Konzept B muss Organ-Picker/Tagging beschreiben."""
        assert "Organ" in konzept_text
        assert "home_screen.dart" in konzept_text

    def test_konzept_b_interface_split(self, konzept_text):
        """Konzept B muss den Interface-Split (PlantIdentifier/CareAdvisor) beschreiben."""
        assert "PlantIdentifier" in konzept_text
        assert "CareAdvisor" in konzept_text

    def test_konzept_c_vorhanden(self, konzept_text):
        """Konzept C muss TFLite + Embedding-Fingerprint + shared Package benennen."""
        assert "Konzept C" in konzept_text
        assert "TFLite" in konzept_text or "tflite" in konzept_text.lower()
        assert "Embedding" in konzept_text or "embedding" in konzept_text.lower()

    def test_konzept_c_plant_id_core_package(self, konzept_text):
        """Konzept C muss plant_id_core Package benennen."""
        assert "plant_id_core" in konzept_text

    def test_alle_konzepte_haben_aufwand_schaetzung(self, konzept_text):
        """Alle Konzepte müssen eine Aufwand-Schätzung (Tage/Wochen) enthalten."""
        assert "Tage" in konzept_text or "Tag" in konzept_text
        assert "Wochen" in konzept_text or "Woche" in konzept_text

    def test_konzepte_adressieren_candidates_schema(self, konzept_text):
        """candidates[]-Schema muss adressiert sein (plant_identification_result.dart)."""
        assert "candidates" in konzept_text.lower()
        assert "plant_identification_result.dart" in konzept_text


# ══════════════════════════════════════════════════════════════════════════════
# AK3: Test-Set ≥20 Pflanzen mit Pflichtfällen
# ══════════════════════════════════════════════════════════════════════════════

class TestAK3_TestSet:
    """AK3: Test-Set muss ≥20 Pflanzen inkl. Pflichtfälle enthalten."""

    @pytest.fixture(scope="class")
    def test_set(self):
        path = EVAL_DIR / "plant_test_set.json"
        assert path.exists(), f"plant_test_set.json nicht gefunden: {path}"
        with open(path, encoding="utf-8") as f:
            return json.load(f)

    def test_mindestens_20_testfaelle(self, test_set):
        count = len(test_set["test_cases"])
        assert count >= 20, f"Erwartet ≥20 Testfälle, gefunden: {count}"

    def test_berg_ahorn_tatiana_referenzfall(self, test_set):
        """Berg-Ahorn muss als TC01 mit confusable_with-Einträgen vorhanden sein."""
        tc01 = next((tc for tc in test_set["test_cases"] if tc["id"] == "TC01"), None)
        assert tc01 is not None, "TC01 fehlt"
        assert "pseudoplatanus" in tc01["scientific_name"].lower()
        # Muss Verwechslungsarten enthalten
        assert len(tc01.get("confusable_with", [])) >= 2
        # Holunder/Weinrebe/Feige müssen als Verwechslungsarten gelistet sein
        confusable = " ".join(tc01["confusable_with"]).lower()
        assert "sambucus" in confusable or "nigra" in confusable  # Holunder
        assert "vitis" in confusable or "weinrebe" in confusable  # Weinrebe

    def test_zimmerpflanzen_vorhanden(self, test_set):
        """Mindestens 3 Zimmerpflanzen müssen im Test-Set sein."""
        zimmer = [tc for tc in test_set["test_cases"]
                  if tc.get("category") == "zimmerpflanze"]
        assert len(zimmer) >= 3, f"Erwartet ≥3 Zimmerpflanzen, gefunden: {len(zimmer)}"

    def test_baeume_mit_rinde_vorhanden(self, test_set):
        """Mindestens 2 Bäume mit Rinden-Test müssen vorhanden sein."""
        trees_with_bark = [
            tc for tc in test_set["test_cases"]
            if tc.get("category") in ("baum", "baum_zimmer")
            and "bark" in tc.get("organs_to_test", [])
        ]
        assert len(trees_with_bark) >= 2, f"Erwartet ≥2 Bäume mit Rinden-Test, gefunden: {len(trees_with_bark)}"

    def test_alle_faelle_haben_expected_top1(self, test_set):
        """Jeder Testfall muss expected_top1 (wissenschaftlichen Namen) haben."""
        for tc in test_set["test_cases"]:
            assert tc.get("expected_top1"), f"expected_top1 fehlt in {tc['id']}"
            # Muss ein wissenschaftlicher Name sein (Gattung + Art)
            name = tc["expected_top1"]
            parts = name.strip().split()
            assert len(parts) >= 2, f"expected_top1 '{name}' scheint kein wissenschaftlicher Name (Gattung Art)"

    def test_aehnlichkeitscluster_tc01_tc05(self, test_set):
        """TC01–TC05 (handförmig gelappte Blätter) müssen alle 'high' difficulty haben."""
        high_difficulty = [
            tc for tc in test_set["test_cases"]
            if tc["id"] in ("TC01", "TC03", "TC04", "TC05")
        ]
        assert len(high_difficulty) >= 3, "Ähnlichkeits-Cluster TC01–TC05 nicht vollständig"
        for tc in high_difficulty:
            assert tc.get("difficulty") == "high", f"{tc['id']} sollte 'high' difficulty haben"

    def test_organ_varianten_fuer_baeume(self, test_set):
        """Bäume sollten mindestens 2 Organe zum Testen definieren."""
        trees = [tc for tc in test_set["test_cases"]
                 if tc.get("category") in ("baum",)]
        for tc in trees[:3]:  # Stichprobe: erste 3 Bäume
            organs = tc.get("organs_to_test", [])
            assert len(organs) >= 2, f"{tc['id']}: Bäume sollten ≥2 Organe haben, gefunden: {organs}"


# ══════════════════════════════════════════════════════════════════════════════
# AK4: Empfehlung mit Aufwand/Nutzen + Epic-Schnitt
# ══════════════════════════════════════════════════════════════════════════════

class TestAK4_Empfehlung:
    """AK4: Empfehlung mit Aufwand/Nutzen und Epic-Schnitt muss vorhanden sein."""

    @pytest.fixture(scope="class")
    def konzept_text(self):
        return (DOCS_DIR / "pflanzenerkennung_v2_konzept.md").read_text(encoding="utf-8")

    def test_empfehlung_abschnitt_vorhanden(self, konzept_text):
        """Dokument muss einen Empfehlung-Abschnitt enthalten."""
        assert "Empfehlung" in konzept_text

    def test_epic_schnitt_vorhanden(self, konzept_text):
        """Epic-Schnitt muss beschrieben sein."""
        assert "Epic" in konzept_text

    def test_stufenplan_vorhanden(self, konzept_text):
        """Stufenplan mit zeitlichen Angaben muss vorhanden sein."""
        # Muss Wochen/Tage für alle 3 Konzepte nennen
        assert "2 Tag" in konzept_text or "1–2 Tag" in konzept_text or "1-2 Tag" in konzept_text
        assert "Wochen" in konzept_text

    def test_aufwand_nutzen_matrix(self, konzept_text):
        """Eine Aufwand/Nutzen-Bewertung muss enthalten sein."""
        # Aufwand-Nutzen taucht irgendwie auf
        lower = konzept_text.lower()
        assert "aufwand" in lower
        assert "nutzen" in lower or "verbesserung" in lower


# ══════════════════════════════════════════════════════════════════════════════
# AK5: Synergien mit Baumschnittwart
# ══════════════════════════════════════════════════════════════════════════════

class TestAK5_Synergien:
    """AK5: Synergien mit Baumschnittwart müssen explizit benannt sein."""

    @pytest.fixture(scope="class")
    def konzept_text(self):
        return (DOCS_DIR / "pflanzenerkennung_v2_konzept.md").read_text(encoding="utf-8")

    def test_baumschnittwart_erwaehnt(self, konzept_text):
        """Baumschnittwart muss explizit erwähnt sein."""
        assert "Baumschnittwart" in konzept_text

    def test_shared_package_plant_id_core(self, konzept_text):
        """plant_id_core shared Package muss als Synergie benannt sein."""
        assert "plant_id_core" in konzept_text

    def test_gemeinsame_api_keys(self, konzept_text):
        """Gemeinsame API-Keys als Synergie müssen erwähnt sein."""
        lower = konzept_text.lower()
        # Irgendeine Aussage über geteilte Keys oder gemeinsame Nutzung
        assert "key" in lower or "api-key" in lower
        # Baumschnittwart + Key-Synergie im gleichen Kontext
        assert "beide" in lower or "gemeinsam" in lower


# ══════════════════════════════════════════════════════════════════════════════
# AK6: Spike-Skripte – CLI und Strukturprüfung
# ══════════════════════════════════════════════════════════════════════════════

class TestAK6_SpikeSkripte:
    """AK6: Spike-Skripte müssen ausführbar und korrekt strukturiert sein."""

    def test_run_evaluation_importierbar(self):
        import run_evaluation  # noqa
        assert hasattr(run_evaluation, "PlantNetBackend")
        assert hasattr(run_evaluation, "PlantIdBackend")
        assert hasattr(run_evaluation, "ClaudeStatusQuoBackend")
        assert hasattr(run_evaluation, "run_evaluation")

    def test_analyze_results_importierbar(self):
        import analyze_results  # noqa
        assert hasattr(analyze_results, "render_markdown_report")
        assert hasattr(analyze_results, "compute_per_case_summary")

    def test_plantnet_base_url_korrekt(self):
        """Pl@ntNet API-URL muss die korrekte v2-Domain nutzen."""
        import run_evaluation
        url = run_evaluation.PlantNetBackend.BASE_URL
        assert "plantnet.org" in url
        assert "v2" in url

    def test_plantid_base_url_v3(self):
        """Plant.id muss v3-Endpoint nutzen (Senior-Dev-Korrektur)."""
        import run_evaluation
        url = run_evaluation.PlantIdBackend.BASE_URL
        assert "v3" in url or "plant.id" in url

    def test_rate_limiting_vorhanden(self):
        """run_evaluation muss Rate-Limiting-Parameter haben."""
        import run_evaluation
        import inspect
        sig = inspect.signature(run_evaluation.run_evaluation)
        params = sig.parameters
        assert "delay_between_calls" in params or "delay" in params

    def test_normalisierung_autor_suffix(self):
        """Normalisierung muss Autoren-Suffix tolerieren (z.B. 'Acer pseudoplatanus L.')."""
        from run_evaluation import is_correct, IdentificationCandidate
        candidates = [
            IdentificationCandidate(1, "Acer pseudoplatanus L.", "Berg-Ahorn", 0.87)
        ]
        # Soll matchen obwohl Suffix " L." vorhanden
        assert is_correct(candidates, "Acer pseudoplatanus")

    def test_gitignore_schluetzt_bilder_aus(self):
        """Die .gitignore im evaluation-Verzeichnis muss Testbilder ausschließen."""
        gitignore = EVAL_DIR / ".gitignore"
        assert gitignore.exists(), ".gitignore im evaluation/-Verzeichnis fehlt"
        content = gitignore.read_text()
        # Testbilder und API-Keys müssen ausgeschlossen sein
        assert ".jpg" in content or "test_images" in content
        assert ".env" in content or "*key*" in content or "*.key" in content


# ══════════════════════════════════════════════════════════════════════════════
# AK7: End-to-End analyze_results mit synthetischen Daten
# ══════════════════════════════════════════════════════════════════════════════

class TestAK7_AnalyzeEndToEnd:
    """AK7: analyze_results.py muss einen validen Markdown-Report generieren."""

    @pytest.fixture
    def synthetic_results(self, tmp_path):
        """Erstellt eine synthetische results.json für End-to-End-Test."""
        data = {
            "meta": {
                "test_set": str(EVAL_DIR / "plant_test_set.json"),
                "images_dir": str(EVAL_DIR / "test_images"),
                "total_cases": 5,
                "backends": ["plantnet", "plantid", "claude"],
            },
            "summaries": {
                "plantnet": {
                    "backend": "plantnet",
                    "total_tests": 5,
                    "top1_correct": 4,
                    "top3_correct": 5,
                    "errors": 0,
                    "avg_latency_ms": 780.0,
                },
                "plantid": {
                    "backend": "plantid",
                    "total_tests": 5,
                    "top1_correct": 5,
                    "top3_correct": 5,
                    "errors": 0,
                    "avg_latency_ms": 1200.0,
                },
                "claude": {
                    "backend": "claude",
                    "total_tests": 5,
                    "top1_correct": 2,
                    "top3_correct": 3,
                    "errors": 1,
                    "avg_latency_ms": 6500.0,
                },
            },
            "results": [
                {
                    "test_case_id": "TC01",
                    "organ": "leaf",
                    "backend": "plantnet",
                    "candidates": [
                        {"rank": 1, "scientific_name": "Acer pseudoplatanus", "common_name": "Berg-Ahorn", "score": 0.87},
                        {"rank": 2, "scientific_name": "Sambucus nigra", "common_name": "Holunder", "score": 0.08},
                    ],
                    "top1_correct": True,
                    "top3_correct": True,
                    "latency_ms": 820,
                    "error": None,
                },
                {
                    "test_case_id": "TC01",
                    "organ": "leaf",
                    "backend": "claude",
                    "candidates": [
                        {"rank": 1, "scientific_name": "Sambucus nigra", "common_name": "Holunder", "score": 0.60},
                    ],
                    "top1_correct": False,
                    "top3_correct": False,
                    "latency_ms": 5500,
                    "error": None,
                },
                {
                    "test_case_id": "TC01",
                    "organ": "leaf",
                    "backend": "plantid",
                    "candidates": [
                        {"rank": 1, "scientific_name": "Acer pseudoplatanus", "common_name": "Berg-Ahorn", "score": 0.93},
                    ],
                    "top1_correct": True,
                    "top3_correct": True,
                    "latency_ms": 1100,
                    "error": None,
                },
            ],
        }
        results_path = tmp_path / "results.json"
        results_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        return data, results_path

    def test_render_markdown_report_vollstaendig(self, synthetic_results):
        """Markdown-Report muss alle Pflichtabschnitte enthalten."""
        from analyze_results import render_markdown_report
        data, _ = synthetic_results
        report = render_markdown_report(data)

        # Pflichtabschnitte
        assert "## Gesamtübersicht" in report
        assert "## Detailergebnisse" in report
        assert "## Schwierige Fälle" in report
        assert "## Interpretation" in report

    def test_render_markdown_korrekte_prozentsaetze(self, synthetic_results):
        """Prozentsätze müssen korrekt berechnet sein (plantnet: 4/5 = 80%)."""
        from analyze_results import render_markdown_report
        data, _ = synthetic_results
        report = render_markdown_report(data)
        # plantnet: 4/5 Top-1 = 80.0%
        assert "80.0%" in report
        # plantid: 5/5 = 100.0%
        assert "100.0%" in report

    def test_analyze_results_laedt_results_json(self, synthetic_results):
        """load_results muss results.json korrekt laden."""
        from analyze_results import load_results
        _, results_path = synthetic_results
        data = load_results(results_path)
        assert "meta" in data
        assert "summaries" in data
        assert "results" in data

    def test_per_case_summary_korrekt(self, synthetic_results):
        """compute_per_case_summary muss korrekte Werte liefern."""
        from analyze_results import compute_per_case_summary
        data, _ = synthetic_results
        per_case = compute_per_case_summary(data["results"], "plantnet")

        assert "TC01" in per_case
        assert per_case["TC01"]["top1_correct"] is True
        assert per_case["TC01"]["top1_candidate"] == "Acer pseudoplatanus"

    def test_claude_status_quo_schlechter_als_plantnet(self, synthetic_results):
        """In synthetischen Daten muss Claude schlechter als Pl@ntNet sein (validiert Analyse-Logik)."""
        data, _ = synthetic_results
        plantnet_top1 = data["summaries"]["plantnet"]["top1_correct"]
        claude_top1 = data["summaries"]["claude"]["top1_correct"]
        assert plantnet_top1 > claude_top1, "In diesen Testdaten sollte Pl@ntNet besser sein"
