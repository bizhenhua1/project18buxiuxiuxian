"""Create the immutable P00 context for the 3D scene production handoff.

This is repository evidence only. It does not run the game or mark any scene
visually accepted. The output is deliberately deterministic apart from the
recorded git status and tool version.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CORE = [
    "godot/scripts/world3d/route_view.gd",
    "godot/scripts/world3d/scenery.gd",
    "godot/scripts/world3d/projection.gd",
    "godot/scripts/spaces/layouts/fairytale_corridor.gd",
    "godot/scripts/world3d/successor_world.gd",
]
DOCS = [
    "docs/design/SCENE3D-PRODUCTION-STANDARD-2026-09-21.md",
    "docs/design/SCENE3D-LUNA-EXECUTION-2026-09-21.md",
    "docs/design/SCENE3D-LUNA-TASKS.json",
    "docs/design/SCENE3D-ASSET-INVENTORY.json",
]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git(*args: str) -> str:
    try:
        return subprocess.run(
            ["git", *args], cwd=ROOT, check=True, text=True,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        ).stdout
    except (OSError, subprocess.CalledProcessError) as exc:
        return f"unavailable: {exc}"


def godot_version() -> str:
    try:
        result = subprocess.run(
            ["godot", "--version"], cwd=ROOT, check=True, text=True,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=20,
        )
        return result.stdout.strip()
    except (OSError, subprocess.SubprocessError) as exc:
        return f"unavailable: {exc}"


def load_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path,
                        default=ROOT / "docs/design/SCENE3D-BASELINE-CONTEXT.json")
    args = parser.parse_args()

    core_hashes = {path: sha256(ROOT / path) for path in CORE if (ROOT / path).is_file()}
    doc_hashes = {path: sha256(ROOT / path) for path in DOCS if (ROOT / path).is_file()}
    catalog = load_json(ROOT / "godot/data/fairytale_scenes.json") or []
    tasks = load_json(ROOT / "docs/design/SCENE3D-LUNA-TASKS.json") or {}
    profile = load_json(ROOT / "godot/data/fairytale_scatter_profiles.json")

    context = {
        "schema_version": 1,
        "scope": "P00 repository baseline; not visual acceptance",
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "repository": str(ROOT),
        "godot_version": godot_version(),
        "git": {
            "head": git("rev-parse", "HEAD").strip(),
            "status_short": git("status", "--short").splitlines(),
        },
        "core_source_sha256": core_hashes,
        "protocol_sha256": doc_hashes,
        "catalog": {
            "scene_count": len(catalog),
            "scene_ids": [str(item.get("id")) for item in catalog if isinstance(item, dict)],
            "expected_scene_count": 18,
        },
        "task_graph": {
            "schema_version": tasks.get("schema_version"),
            "task_status": {item.get("id"): item.get("status") for item in tasks.get("tasks", [])},
            "runtime_profiles_accepted": tasks.get("runtime_profiles_accepted"),
            "image_generation_allowed": tasks.get("image_generation_allowed"),
        },
        "experimental_state": {
            "scatter_profile_file_present": profile is not None,
            "scatter_profiles_are_accepted": False,
            "baseline_measurement_status": tasks.get("measurement_status", "unknown"),
            "native_capture_status": "P01 not yet validated",
        },
        "constraints": [
            "3D scene work only; preserve existing battle, camera, save and web-demo behavior",
            "do not modify the six accepted baseline scenes while extending shared renderer capability",
            "P00/P01 do not generate images; later generation is conditional on a validated asset_request",
        ],
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(context, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"P00_BASELINE_CONTEXT path={args.output} scenes={len(catalog)} core_hashes={len(core_hashes)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
