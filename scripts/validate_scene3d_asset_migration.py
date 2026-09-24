"""Validate the lossless 3D asset metadata migration ledger.

The migration is deliberately conservative: pixel facts and alpha bounds may
be recovered from legacy metadata/PNG headers, while world-space semantics
remain unknown until an artist supplies them.  This validator makes that
boundary executable and produces a review report without editing the ledger.
"""

from __future__ import annotations

import argparse
import json
import math
from collections import Counter
from pathlib import Path
from typing import Any


PHYSICAL_FIELDS = ("size_m", "footprints_m", "contact", "sockets_m")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--migration",
        default="docs/design/SCENE3D-ASSET-MIGRATION.json",
    )
    parser.add_argument(
        "--output",
        default="docs/design/SCENE3D-ASSET-MIGRATION-VALIDATION-2026-09-21.json",
    )
    return parser.parse_args()


def finite_number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(float(value))


def valid_size(value: Any) -> bool:
    return isinstance(value, list) and len(value) == 2 and all(
        isinstance(item, int) and not isinstance(item, bool) and item > 0 for item in value
    )


def valid_bounds(value: Any, size: list[int]) -> bool:
    if not isinstance(value, list) or len(value) != 4 or not all(
        isinstance(item, int) and not isinstance(item, bool) for item in value
    ):
        return False
    left, top, right, bottom = value
    width, height = size
    return 0 <= left <= right < width and 0 <= top <= bottom < height


def valid_anchor(value: Any) -> bool:
    return isinstance(value, list) and len(value) == 2 and all(
        finite_number(item) and 0.0 <= float(item) <= 1.0 for item in value
    )


def main() -> int:
    args = parse_args()
    workspace = Path(__file__).resolve().parents[1]
    migration_path = (workspace / args.migration).resolve()
    output_path = (workspace / args.output).resolve()
    data: dict[str, Any] = json.loads(migration_path.read_text(encoding="utf-8"))
    failures: list[str] = []
    scene_count = 0
    asset_count = 0
    ids: list[str] = []
    source_counts: Counter[str] = Counter()
    status_counts: Counter[str] = Counter()
    physical_missing_counts: Counter[str] = Counter()
    alpha_edge_touch_count = 0

    scenes = data.get("scenes")
    if not isinstance(scenes, list) or not scenes:
        failures.append("scenes must be a non-empty array")
        scenes = []
    for scene in scenes:
        scene_count += 1
        if not isinstance(scene, dict):
            failures.append(f"scene {scene_count} is not an object")
            continue
        assets = scene.get("assets")
        if not isinstance(assets, list):
            failures.append(f"scene {scene.get('scene_id', scene_count)} has no assets array")
            continue
        for asset in assets:
            asset_count += 1
            if not isinstance(asset, dict):
                failures.append(f"scene {scene.get('scene_id', scene_count)} has a non-object asset")
                continue
            asset_id = asset.get("id")
            if not isinstance(asset_id, str) or not asset_id:
                failures.append(f"asset {asset_count} has no stable id")
                asset_id = f"<asset-{asset_count}>"
            ids.append(asset_id)
            size = asset.get("size_px")
            if not valid_size(size):
                failures.append(f"{asset_id} has invalid size_px")
                size = [1, 1]
            else:
                source_counts[str(asset.get("size_px_source", "<missing>"))] += 1
            if not valid_bounds(asset.get("alpha_bounds_px"), size):
                failures.append(f"{asset_id} has out-of-range alpha_bounds_px")
            if not valid_anchor(asset.get("anchor_uv")):
                failures.append(f"{asset_id} has invalid anchor_uv")
            edge_touch = asset.get("alpha_edge_touch")
            if not isinstance(edge_touch, bool):
                failures.append(f"{asset_id} has non-boolean alpha_edge_touch")
            elif edge_touch:
                alpha_edge_touch_count += 1
            status = asset.get("status")
            status_counts[str(status)] += 1
            for field in PHYSICAL_FIELDS:
                if asset.get(field) is not None:
                    failures.append(f"{asset_id} has guessed physical field {field}")
                else:
                    physical_missing_counts[field] += 1

    duplicates = sorted({asset_id for asset_id in ids if ids.count(asset_id) > 1})
    if duplicates:
        failures.append(f"duplicate asset ids: {duplicates}")
    if scene_count != 18:
        failures.append(f"expected 18 scenes, got {scene_count}")
    if asset_count != 329:
        failures.append(f"expected 329 assets, got {asset_count}")
    for field in PHYSICAL_FIELDS:
        if physical_missing_counts[field] != asset_count:
            failures.append(
                f"{field} missing on {physical_missing_counts[field]}/{asset_count}, expected all unknown"
            )

    report = {
        "schema_version": 1,
        "migration": args.migration.replace("\\", "/"),
        "scene_count": scene_count,
        "asset_count": asset_count,
        "size_px_known_count": sum(source_counts.values()),
        "size_px_source_counts": dict(sorted(source_counts.items())),
        "alpha_bounds_known_count": asset_count - sum(
            1 for failure in failures if "alpha_bounds_px" in failure
        ),
        "alpha_edge_touch_count": alpha_edge_touch_count,
        "physical_fields_missing_counts": dict(sorted(physical_missing_counts.items())),
        "status_counts": dict(sorted(status_counts.items())),
        "failures": failures,
        "status": "pass" if not failures else "fail",
        "rule": "Only explicit pixel/alpha facts are accepted; world-space semantics remain null until reviewed.",
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(
        f"SCENE3D_ASSET_MIGRATION_{report['status'].upper()} "
        f"scenes={scene_count} assets={asset_count} failures={len(failures)}"
    )
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
