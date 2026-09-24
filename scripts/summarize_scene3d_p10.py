"""Summarize the bounded native 3D P10 benchmark without changing its raw data."""

from __future__ import annotations

import argparse
import json
from collections import defaultdict
from pathlib import Path
from statistics import median
from typing import Any


def percentile(values: list[float], fraction: float) -> float:
    ordered = sorted(values)
    if not ordered:
        return 0.0
    index = round((len(ordered) - 1) * fraction)
    return float(ordered[max(0, min(len(ordered) - 1, index))])


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--input",
        default="tempassets/work/scene3d-performance-20260921/p10-report.json",
    )
    parser.add_argument(
        "--output",
        default="docs/design/SCENE3D-P10-SUMMARY-2026-09-21.json",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    workspace = Path(__file__).resolve().parents[1]
    input_path = (workspace / args.input).resolve()
    output_path = (workspace / args.output).resolve()
    report: dict[str, Any] = json.loads(input_path.read_text(encoding="utf-8"))
    rows = report.get("results", [])
    failures: list[str] = []
    if not isinstance(rows, list) or not rows:
        failures.append("P10 report has no results")
        rows = []

    grouped: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        if not isinstance(row, dict):
            failures.append("P10 result is not an object")
            continue
        scene = row.get("scene")
        if not isinstance(scene, str) or not scene:
            failures.append("P10 result has no scene")
            continue
        if not row.get("draw_metrics_available", False):
            failures.append(f"draw metrics unavailable for {scene}")
        grouped[scene].append(row)

    scene_summary: dict[str, Any] = {}
    for scene, scene_rows in sorted(grouped.items()):
        p95 = [float(row.get("frame_ms_p95", 0.0)) for row in scene_rows]
        draws = [float(row.get("draws_p95", 0.0)) for row in scene_rows]
        sprites = [float(row.get("world_sprites_max", 0.0)) for row in scene_rows]
        uploads = [float(row.get("upload_peak_ms", 0.0)) for row in scene_rows]
        scene_summary[scene] = {
            "rounds": len(scene_rows),
            "frame_ms_p95_min": min(p95),
            "frame_ms_p95_median": median(p95),
            "frame_ms_p95_max": max(p95),
            "draws_p95_max": max(draws),
            "world_sprites_max": max(sprites),
            "upload_peak_ms_max": max(uploads),
        }

    reference = scene_summary.get("forest")
    candidate_results: dict[str, Any] = {}
    travel_gate_pass = reference is not None
    if reference is None:
        failures.append("reference scene forest is missing")
    else:
        reference_limit = max(float(reference["frame_ms_p95_median"]) * 0.10, 2.0)
        allowed = float(reference["frame_ms_p95_median"]) + reference_limit
        for scene, summary in scene_summary.items():
            if scene == "forest":
                continue
            value = float(summary["frame_ms_p95_median"])
            passed = value <= allowed
            travel_gate_pass = travel_gate_pass and passed
            candidate_results[scene] = {
                "frame_ms_p95_median": value,
                "reference_median": float(reference["frame_ms_p95_median"]),
                "allowed_limit": allowed,
                "pass": passed,
            }
    output = {
        "schema_version": 1,
        "input": args.input.replace("\\", "/"),
        "display_server": report.get("display_server"),
        "draw_metrics_available": bool(report.get("draw_metrics_available", False)),
        "scene_summary": scene_summary,
        "travel_frame_gate": {
            "pass": travel_gate_pass and not failures,
            "rule": "candidate P95 may exceed reference median by at most max(10%, 2ms)",
            "comparisons": candidate_results,
        },
        "scope_limitations": [
            "travel and streaming only",
            "no skill, AOE, multi-projectile, remote-effect or high-density battle stress",
            "visual acceptance remains separate from the numeric gate",
        ],
        "failures": failures,
        "status": "pass_travel_scope_stress_pending" if not failures else "fail",
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(
        f"SCENE3D_P10_SUMMARY_{output['status'].upper()} "
        f"scenes={len(scene_summary)} draw_metrics={output['draw_metrics_available']} failures={len(failures)}"
    )
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
