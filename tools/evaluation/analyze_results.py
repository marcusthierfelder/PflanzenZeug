#!/usr/bin/env python3
"""
Pflanzenwart v2 – Evaluierungs-Analyse
=======================================
Liest die Ergebnisse des Evaluierungs-Spikes (results.json) und gibt
eine Markdown-Tabelle + Detailanalyse aus.

Verwendung:
    python evaluation/analyze_results.py evaluation/results.json
    python evaluation/analyze_results.py evaluation/results.json --output evaluation/report.md
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def load_results(path: Path) -> dict:
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def compute_per_case_summary(results: list[dict], backend: str) -> dict[str, dict]:
    """Berechnet Top-1/Top-3 Korrektheit je Test-Case und Backend."""
    per_case = {}
    for r in results:
        if r["backend"] != backend:
            continue
        tc_id = r["test_case_id"]
        if tc_id not in per_case:
            per_case[tc_id] = {
                "top1_correct": r["top1_correct"],
                "top3_correct": r["top3_correct"],
                "top1_candidate": r["candidates"][0]["scientific_name"] if r["candidates"] else "(keine)",
                "error": r.get("error"),
            }
    return per_case


def render_markdown_report(data: dict) -> str:
    """Rendert einen vollständigen Markdown-Report."""
    lines = []
    backends = data["meta"]["backends"]
    results = data["results"]
    summaries = data["summaries"]

    lines.append("# Pflanzenwart v2 – Evaluierungs-Report\n")
    lines.append(f"**Test-Set:** {data['meta']['test_set']}  ")
    lines.append(f"**Getestete Backends:** {', '.join(backends)}  ")
    lines.append(f"**Anzahl Test-Fälle:** {data['meta']['total_cases']}\n")

    # Gesamtübersicht
    lines.append("## Gesamtübersicht\n")
    header = "| Backend | Top-1 % | Top-3 % | Ø Latenz | Fehler |"
    sep = "|---------|---------|---------|---------|--------|"
    lines.append(header)
    lines.append(sep)

    for backend in backends:
        s = summaries.get(backend, {})
        valid = s.get("total_tests", 0) - s.get("errors", 0)
        top1 = s.get("top1_correct", 0)
        top3 = s.get("top3_correct", 0)
        errors = s.get("errors", 0)
        avg_lat = s.get("avg_latency_ms", 0)
        top1_pct = f"{top1/valid*100:.1f}%" if valid > 0 else "–"
        top3_pct = f"{top3/valid*100:.1f}%" if valid > 0 else "–"
        lines.append(f"| **{backend}** | {top1_pct} ({top1}/{valid}) | {top3_pct} ({top3}/{valid}) | {avg_lat:.0f}ms | {errors} |")

    lines.append("")

    # Detail-Tabelle je Test-Case
    lines.append("## Detailergebnisse je Test-Fall\n")

    # Test-Case-IDs aus Ergebnissen sammeln
    tc_ids = list(dict.fromkeys(r["test_case_id"] for r in results))

    # Pro Backend die per-case Zusammenfassung berechnen
    per_case_summaries = {
        backend: compute_per_case_summary(results, backend)
        for backend in backends
    }

    # Tabellen-Header dynamisch nach Backends
    backend_cols = " | ".join(
        f"**{b}** Top-1 | **{b}** Kandidat" for b in backends
    )
    lines.append(f"| Test-Case | Erwartet | {backend_cols} |")
    sep_cols = " | ".join("--- | ---" for _ in backends)
    lines.append(f"|-----------|----------|{sep_cols}|")

    # Test-Set laden für expected_top1
    expected_map = {}
    test_set_path = Path(data["meta"]["test_set"])
    if test_set_path.exists():
        with open(test_set_path, encoding="utf-8") as f:
            test_set = json.load(f)
        for tc in test_set["test_cases"]:
            expected_map[tc["id"]] = {
                "expected": tc["expected_top1"],
                "name_de": tc["common_name_de"],
            }

    for tc_id in tc_ids:
        expected_info = expected_map.get(tc_id, {})
        expected = expected_info.get("expected", "?")
        name_de = expected_info.get("name_de", tc_id)

        row_parts = [f"**{tc_id}** {name_de}", expected]

        for backend in backends:
            case = per_case_summaries[backend].get(tc_id, {})
            if not case:
                row_parts.extend(["–", "–"])
                continue

            top1_correct = case.get("top1_correct", False)
            top1_candidate = case.get("top1_candidate", "–")
            error = case.get("error")

            if error:
                row_parts.extend([f"⚠️ Fehler", error[:40]])
            else:
                status = "✅" if top1_correct else "❌"
                row_parts.extend([status, top1_candidate])

        lines.append("| " + " | ".join(str(p) for p in row_parts) + " |")

    lines.append("")

    # Schwierige Fälle hervorheben
    lines.append("## Schwierige Fälle (kein Backend Top-1 korrekt)\n")
    failed_cases = []
    for tc_id in tc_ids:
        all_wrong = all(
            not per_case_summaries[b].get(tc_id, {}).get("top1_correct", False)
            for b in backends
            if tc_id in per_case_summaries[b]
        )
        if all_wrong:
            expected_info = expected_map.get(tc_id, {})
            failed_cases.append({
                "id": tc_id,
                "name_de": expected_info.get("name_de", tc_id),
                "expected": expected_info.get("expected", "?"),
                "candidates": {
                    b: per_case_summaries[b].get(tc_id, {}).get("top1_candidate", "–")
                    for b in backends
                },
            })

    if failed_cases:
        for fc in failed_cases:
            lines.append(f"### {fc['id']} – {fc['name_de']} (erwartet: *{fc['expected']}*)")
            for b, c in fc["candidates"].items():
                lines.append(f"- **{b}:** {c}")
            lines.append("")
    else:
        lines.append("*Keine Fälle bei denen alle Backends versagten.*\n")

    # Empfehlungs-Zusammenfassung
    lines.append("## Interpretation & Empfehlung\n")
    lines.append("> *Diese Sektion ist manuell auszufüllen nach Durchführung der Evaluierung.*\n")
    lines.append("- **Pl@ntNet vs. Plant.id:** Vergleiche Top-1 und Top-3 Quoten für die 5 schwierigen Ähnlichkeitsfälle (TC01–TC05).")
    lines.append("- **Status Quo (Claude):** Erwartete Top-1 ~55–70 % – tatsächlicher Wert bestätigt/widerlegt Analyse?")
    lines.append("- **Latenz:** Plant.id i.d.R. 500–2000ms; Pl@ntNet 300–1500ms; Claude 3000–10000ms.")
    lines.append("- **Fazit:** Empfiehlt sich die Umstellung auf Pl@ntNet/Plant.id als primären Klassifikator (Konzept B)?")

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="Pflanzenwart v2 – Evaluierungs-Analyse",
    )
    parser.add_argument("results_file", help="Pfad zur results.json")
    parser.add_argument(
        "--output",
        help="Optionaler Ausgabe-Pfad für Markdown-Report",
    )
    parser.add_argument(
        "--format",
        choices=["text", "markdown"],
        default="text",
        help="Ausgabeformat (Default: text)",
    )

    args = parser.parse_args()

    results_path = Path(args.results_file)
    if not results_path.exists():
        print(f"❌ Datei nicht gefunden: {results_path}")
        sys.exit(1)

    data = load_results(results_path)
    backends = data["meta"]["backends"]
    summaries = data["summaries"]

    # Konsolen-Ausgabe
    print("\n" + "=" * 60)
    print("PFLANZENWART V2 – EVALUIERUNGS-ZUSAMMENFASSUNG")
    print("=" * 60)
    print(f"Test-Set: {data['meta']['test_set']}")
    print(f"Backends: {', '.join(backends)}\n")

    for backend in backends:
        s = summaries.get(backend, {})
        valid = s.get("total_tests", 0) - s.get("errors", 0)
        top1 = s.get("top1_correct", 0)
        top3 = s.get("top3_correct", 0)
        errors = s.get("errors", 0)
        avg_lat = s.get("avg_latency_ms", 0)

        top1_pct = top1 / valid * 100 if valid > 0 else 0
        top3_pct = top3 / valid * 100 if valid > 0 else 0

        print(f"{backend.upper()}:")
        print(f"  Top-1: {top1}/{valid} = {top1_pct:.1f}%")
        print(f"  Top-3: {top3}/{valid} = {top3_pct:.1f}%")
        print(f"  Latenz: Ø {avg_lat:.0f}ms")
        print(f"  Fehler: {errors}")
        print()

    if args.output or args.format == "markdown":
        report = render_markdown_report(data)
        if args.output:
            output_path = Path(args.output)
            output_path.parent.mkdir(parents=True, exist_ok=True)
            with open(output_path, "w", encoding="utf-8") as f:
                f.write(report)
            print(f"Markdown-Report gespeichert: {output_path}")
        else:
            print(report)


if __name__ == "__main__":
    main()
