"""Audit existing native 3D capture coverage without creating new images."""
from __future__ import annotations

import json
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / "tempassets/work"
OUTPUT = ROOT / "docs/design/SCENE3D-EVIDENCE-COVERAGE-2026-09-21.json"

REQUIRED = [
    "approach",
    "travel",
    "event",
    "battle",
    "junction_2_entry",
    "junction_2_left",
    "junction_2_right",
    "junction_3_entry",
    "junction_3_middle",
    "junction_3_side",
    "turn_sequence",
    "successor",
]


def classify_capture(capture: dict) -> str:
    phase = str(capture.get("phase", capture.get("expected_phase", ""))).lower()
    branch = int(capture.get("branch", 0))
    kind = str(capture.get("kind", "")).lower()
    if phase in {"approach", "travel", "event", "battle", "successor", "turn_sequence"}:
        return phase
    if phase in {"choose", "junction", "fork"} or kind in {"choose", "fork"}:
        exits = int(capture.get("exits", capture.get("tour_exits", 2)))
        if exits == 3:
            if branch == 0:
                return "junction_3_entry"
            return "junction_3_middle" if branch == 1 else "junction_3_side"
        if branch == 0:
            return "junction_2_entry"
        return "junction_2_left" if branch < 0 else "junction_2_right"
    # Existing P01 manifests often encode the branch but leave phase as approach.
    if phase == "approach" and branch != 0:
        return "approach"
    return "unknown"


def iter_manifests() -> list[Path]:
    roots = [
        WORK / "representative-diagnostic",
        WORK / "representative-travel",
        WORK / "representative-fork",
        WORK / "representative-multiseed-20260921",
        WORK / "scene3d-18-captures-20260921",
    ]
    paths: list[Path] = []
    for root in roots:
        if root.exists():
            paths.extend(root.glob("*/manifest.json"))
    return sorted(set(paths))


def main() -> None:
    by_scene: dict[str, dict] = defaultdict(lambda: {"manifests": [], "evidence": defaultdict(list)})
    parse_errors = []
    for path in iter_manifests():
        try:
            manifest = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            parse_errors.append({"path": path.relative_to(ROOT).as_posix(), "error": str(exc)})
            continue
        scene = str(manifest.get("actual_scene", manifest.get("requested_scene", "unknown")))
        row = by_scene[scene]
        row["manifests"].append(path.relative_to(ROOT).as_posix())
        captures = manifest.get("captures", [])
        for capture in captures:
            category = classify_capture(capture)
            row["evidence"][category].append(
                {
                    "manifest": path.relative_to(ROOT).as_posix(),
                    "image": str(capture.get("image", "")),
                    "kind": str(capture.get("kind", "")),
                    "phase": str(capture.get("phase", capture.get("expected_phase", ""))),
                    "branch": int(capture.get("branch", 0)),
                    "seed": capture.get("seed"),
                }
            )

    scenes = []
    for scene in sorted(by_scene):
        row = by_scene[scene]
        evidence = {key: value for key, value in sorted(row["evidence"].items())}
        present = sorted(key for key in evidence if key in REQUIRED)
        missing = [key for key in REQUIRED if key not in evidence]
        scenes.append(
            {
                "scene_id": scene,
                "manifest_count": len(set(row["manifests"])),
                "manifests": sorted(set(row["manifests"])),
                "present": present,
                "missing": missing,
                "visual_acceptance": "unreviewed",
                "evidence": evidence,
            }
        )

    payload = {
        "schema_version": 1,
        "scope": "existing capture manifests only; no screenshots generated",
        "required_categories": REQUIRED,
        "manifest_count": sum(scene["manifest_count"] for scene in scenes),
        "scene_count": len(scenes),
        "parse_errors": parse_errors,
        "status": "coverage_audit_complete_visual_acceptance_pending",
        "scenes": scenes,
    }
    OUTPUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(
        f"SCENE3D_EVIDENCE_COVERAGE_PASS scenes={len(scenes)} manifests={payload['manifest_count']} "
        f"parse_errors={len(parse_errors)} output={OUTPUT}"
    )


if __name__ == "__main__":
    main()
