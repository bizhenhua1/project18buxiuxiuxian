"""Create the draft SceneProfile contract for all fairytale scenes.

The generated profiles deliberately contain no invented density or size values.
Every unresolved layer points back to the production standard and remains
pending until a baseline measurement, approved asset, or user visual decision
exists.
"""
from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TASKS = ROOT / "docs/design/SCENE3D-LUNA-TASKS.json"
OUTPUT = ROOT / "docs/design/SCENE3D-SCENE-PROFILES-2026-09-21.json"


FAMILY_CONTRACTS = {
    "interior": {
        "topology": "closed",
        "scatter_namespace": "interior",
        "required_roles": ["structure", "roof", "furnishing", "prop", "litter"],
    },
    "cave": {
        "topology": "entrance_to_closed",
        "scatter_namespace": "cave",
        "required_roles": ["structure", "roof", "wall", "prop", "litter"],
    },
    "street": {
        "topology": "local",
        "scatter_namespace": "street",
        "required_roles": ["structure", "canopy", "furnishing", "prop", "litter"],
    },
    "garden": {
        "topology": "open",
        "scatter_namespace": "garden",
        "required_roles": ["structure", "canopy", "cover", "prop", "litter"],
    },
    "bridge": {
        "topology": "open",
        "scatter_namespace": "bridge",
        "required_roles": ["structure", "wall", "cover", "prop", "litter"],
    },
    "stage": {
        "topology": "closed",
        "scatter_namespace": "stage",
        "required_roles": ["structure", "roof", "furnishing", "prop", "litter"],
    },
    "clock": {
        "topology": "closed",
        "scatter_namespace": "clock",
        "required_roles": ["structure", "roof", "suspended", "prop", "litter"],
    },
}


def main() -> None:
    tasks = json.loads(TASKS.read_text(encoding="utf-8"))
    profiles = []
    for assignment in tasks["scene_assignments"]:
        scene = str(assignment["scene"])
        family = str(assignment["family"])
        baseline = str(assignment["structure_baseline"])
        roof = str(assignment["roof"])
        family_contract = FAMILY_CONTRACTS[family]
        profiles.append(
            {
                "profile_contract_version": 1,
                "scene_id": scene,
                "physical_family": family,
                "baseline_id": baseline,
                "baseline_revision": "SCENE3D-BASELINE-MEASUREMENTS.json:visual-review-pending",
                "roof_mode": roof,
                "family_contract": {
                    **family_contract,
                    "status": "contract_ready_values_pending",
                    "source": "docs/design/SCENE3D-PRODUCTION-STANDARD-2026-09-21.md#4-7",
                },
                "layer_rules": {
                    "structure": {
                        "status": "pending_measurement_and_asset_annotation",
                        "source": "docs/design/SCENE3D-PRODUCTION-STANDARD-2026-09-21.md#7",
                    },
                    "ceiling_or_canopy": {
                        "status": "pending_roof_profile",
                        "source": "docs/design/SCENE3D-LUNA-EXECUTION-2026-09-21.md#B9",
                    },
                    "functional_groups": {
                        "status": "pending_measurement_and_asset_annotation",
                        "source": "docs/design/SCENE3D-PRODUCTION-STANDARD-2026-09-21.md#5",
                    },
                    "ground_cover": {
                        "status": "pending_baseline_calibration",
                        "source": "docs/design/SCENE3D-LUNA-EXECUTION-2026-09-21.md#D4",
                    },
                },
                "battle_clearance_source": {
                    "status": "pending_camera_and_battle_template_review",
                    "source": "docs/design/SCENE3D-LUNA-EXECUTION-2026-09-21.md#D5",
                },
                "asset_ids": [],
                "junction_rules": {
                    "owner": "segment_id+junction_id",
                    "status": "flagged_runtime_geometry_audit_pass",
                    "source": "docs/design/SCENE3D-LUNA-EXECUTION-2026-09-21.md#D2",
                },
                "seed_version": {
                    "value": "legacy-route-seed-v1",
                    "status": "pending-stable-layer-seed-migration",
                    "source": "docs/design/SCENE3D-LUNA-EXECUTION-2026-09-21.md#D4",
                },
                "limits": {
                    "status": "pending_same-camera_baseline_measurement",
                    "values": {},
                    "source": "docs/design/SCENE3D-LUNA-EXECUTION-2026-09-21.md#E1",
                },
                "status": "draft_pending_asset_visual_and_battle_review",
            }
        )
    payload = {
        "schema_version": 1,
        "protocol": "docs/design/SCENE3D-LUNA-EXECUTION-2026-09-21.md#C2",
        "status": "draft_all_profiles_pending_visual_review",
        "rule": "Unknown numeric values stay absent; each unresolved field carries a source and pending status.",
        "profiles": profiles,
    }
    OUTPUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"SCENE3D_SCENE_PROFILES_BUILT count={len(profiles)} output={OUTPUT}")


if __name__ == "__main__":
    main()
