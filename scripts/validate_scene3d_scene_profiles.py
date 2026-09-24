"""Validate the draft SceneProfile contract without judging visual quality."""
from __future__ import annotations

import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCENES = json.loads((ROOT / "godot/data/fairytale_scenes.json").read_text(encoding="utf-8"))
EXPECTED = {str(item["id"]) for item in SCENES}
ROOF_MODES = {"open", "closed", "local", "entrance_to_closed"}
FAMILY_CONTRACTS = {
    "interior": ("closed", "interior", {"structure", "roof", "furnishing", "prop", "litter"}),
    "cave": ("entrance_to_closed", "cave", {"structure", "roof", "wall", "prop", "litter"}),
    "street": ("local", "street", {"structure", "canopy", "furnishing", "prop", "litter"}),
    "garden": ("open", "garden", {"structure", "canopy", "cover", "prop", "litter"}),
    "bridge": ("open", "bridge", {"structure", "wall", "cover", "prop", "litter"}),
    "stage": ("closed", "stage", {"structure", "roof", "furnishing", "prop", "litter"}),
    "clock": ("closed", "clock", {"structure", "roof", "suspended", "prop", "litter"}),
}


def fail(message: str) -> None:
    print(f"SCENE3D_SCENE_PROFILE_FAIL {message}")
    raise SystemExit(1)


def main() -> None:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "docs/design/SCENE3D-SCENE-PROFILES-2026-09-21.json"
    payload = json.loads(path.read_text(encoding="utf-8"))
    profiles = payload.get("profiles", [])
    if len(profiles) != len(EXPECTED):
        fail(f"expected {len(EXPECTED)} profiles, got {len(profiles)}")
    seen = set()
    for profile in profiles:
        scene = str(profile.get("scene_id", ""))
        if scene in seen or scene not in EXPECTED:
            fail(f"scene id is missing, unknown, or duplicated: {scene}")
        seen.add(scene)
        if profile.get("roof_mode") not in ROOF_MODES:
            fail(f"invalid roof mode for {scene}")
        family = str(profile.get("physical_family", ""))
        if family not in FAMILY_CONTRACTS:
            fail(f"unknown physical family for {scene}: {family}")
        expected_topology, expected_namespace, expected_roles = FAMILY_CONTRACTS[family]
        if profile.get("roof_mode") != expected_topology:
            fail(f"roof mode does not match physical family for {scene}: {family}")
        contract = profile.get("family_contract", {})
        if contract.get("topology") != expected_topology:
            fail(f"family topology mismatch for {scene}: {family}")
        if contract.get("scatter_namespace") != expected_namespace:
            fail(f"family scatter namespace mismatch for {scene}: {family}")
        roles = set(contract.get("required_roles", []))
        if roles != expected_roles:
            fail(f"family required roles mismatch for {scene}: {family}")
        if contract.get("status") != "contract_ready_values_pending" or not contract.get("source"):
            fail(f"family contract lacks pending status/source for {scene}")
        if not isinstance(profile.get("asset_ids"), list):
            fail(f"asset_ids must be an array for {scene}")
        for name, rule in profile.get("layer_rules", {}).items():
            if not rule.get("source") or not rule.get("status"):
                fail(f"layer rule {scene}/{name} lacks source or status")
        for name in ["battle_clearance_source", "junction_rules", "seed_version", "limits"]:
            item = profile.get(name, {})
            if not item.get("source") or not item.get("status"):
                fail(f"{scene}/{name} lacks source or status")
    if seen != EXPECTED:
        fail("profile set does not match fairytale catalog")
    print(f"SCENE3D_SCENE_PROFILE_PASS count={len(profiles)} pending_numeric_values_preserved")


if __name__ == "__main__":
    main()
