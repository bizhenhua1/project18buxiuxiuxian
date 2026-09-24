"""Summarise unresolved AssetSpec fields for the Astra scene-production handoff.

This report is deliberately read-only: it does not infer dimensions, footprints,
or contact modes from legacy values. Unknown fields remain gaps and are grouped
so that structure/roof assets can be annotated before dressing assets.
"""
from __future__ import annotations

import json
from collections import Counter, defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / "docs/design/SCENE3D-ASSET-MIGRATION.json"
PROFILES = ROOT / "docs/design/SCENE3D-SCENE-PROFILES-2026-09-21.json"
OUTPUT = ROOT / "docs/design/SCENE3D-ASSET-GAP-REPORT-2026-09-21.json"


PRIORITY = {
    "structure": 0,
    "roof": 0,
    "wall": 0,
    "canopy": 1,
    "furnishing": 1,
    "cover": 2,
    "prop": 2,
    "litter": 3,
}


def main() -> None:
    migration = json.loads(MIGRATION.read_text(encoding="utf-8"))
    profiles = json.loads(PROFILES.read_text(encoding="utf-8"))
    family_by_scene = {str(item["scene_id"]): str(item["physical_family"]) for item in profiles["profiles"]}

    scene_rows = []
    total_missing = Counter()
    total_roles = Counter()
    size_px_known = 0
    alpha_bounds_known = 0
    alpha_edge_touch_count = 0
    for scene in migration.get("scenes", []):
        scene_id = str(scene["scene_id"])
        family = family_by_scene.get(scene_id, str(scene.get("physical_family", "unknown")))
        field_counts = Counter()
        role_counts = Counter()
        scene_size_px_known = 0
        scene_alpha_bounds_known = 0
        asset_rows = []
        for asset in scene.get("assets", []):
            role = str(asset.get("role_guess") or asset.get("legacy_role") or "unknown")
            missing = sorted(str(field) for field in asset.get("missing_fields", []))
            field_counts.update(missing)
            total_missing.update(missing)
            role_counts[role] += 1
            total_roles[role] += 1
            if isinstance(asset.get("size_px"), list) and len(asset["size_px"]) == 2 and all(value is not None for value in asset["size_px"]):
                size_px_known += 1
                scene_size_px_known += 1
            if isinstance(asset.get("alpha_bounds_px"), list):
                alpha_bounds_known += 1
                scene_alpha_bounds_known += 1
            if asset.get("alpha_edge_touch") is True:
                alpha_edge_touch_count += 1
            asset_rows.append(
                {
                    "id": str(asset.get("id", "")),
                    "role": role,
                    "status": str(asset.get("status", "unknown")),
                    "missing_fields": missing,
                    "priority": min((PRIORITY.get(role, 2), 9), default=2),
                }
            )
        asset_rows.sort(key=lambda row: (row["priority"], row["role"], row["id"]))
        scene_rows.append(
            {
                "scene_id": scene_id,
                "physical_family": family,
                "asset_count": len(asset_rows),
                "size_px_known_count": scene_size_px_known,
                "alpha_bounds_known_count": scene_alpha_bounds_known,
                "missing_by_field": dict(sorted(field_counts.items())),
                "role_counts": dict(sorted(role_counts.items())),
                "runtime_ready": bool(scene.get("runtime_ready", False)),
                "priority_order": ["structure_roof_wall", "canopy_furnishing", "cover_prop", "litter"],
                "assets": asset_rows,
            }
        )

    scene_rows.sort(key=lambda row: (row["physical_family"], row["scene_id"]))
    payload = {
        "schema_version": 1,
        "scope": "read-only AssetSpec gap summary for Astra; no dimensions or footprints inferred",
        "source": {
            "migration": "docs/design/SCENE3D-ASSET-MIGRATION.json",
            "profiles": "docs/design/SCENE3D-SCENE-PROFILES-2026-09-21.json",
        },
        "summary": {
            "scene_count": len(scene_rows),
            "asset_count": sum(row["asset_count"] for row in scene_rows),
            "size_px_known_count": size_px_known,
            "alpha_bounds_known_count": alpha_bounds_known,
            "alpha_edge_touch_count": alpha_edge_touch_count,
            "runtime_ready_count": sum(1 for row in scene_rows if row["runtime_ready"]),
            "missing_by_field": dict(sorted(total_missing.items())),
            "role_counts": dict(sorted(total_roles.items())),
        },
        "annotation_order": [
            "structure/roof/wall: size_m, footprints_m, contact, sockets_m",
            "canopy/furnishing: size_m, footprints_m, contact",
            "cover/prop: size_m, footprints_m, contact",
            "litter: size_m, contact",
        ],
        "scenes": scene_rows,
    }
    OUTPUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(
        "SCENE3D_ASSET_GAP_REPORT_BUILT "
        f"scenes={len(scene_rows)} assets={payload['summary']['asset_count']} "
        f"runtime_ready={payload['summary']['runtime_ready_count']} output={OUTPUT}"
    )


if __name__ == "__main__":
    main()
