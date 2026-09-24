"""Check the three Scene3D benchmark contracts without claiming visual acceptance.

The check is deliberately scene-family aware: it validates the structural roles
needed by each roof mode, verifies referenced files, and reports whether the
contract is ready for runtime candidate use or still needs annotation/new art.
It does not silently substitute another scene's assets.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXPECTED = {
    "red_cottage": {"roof_mode": "closed_low_ceiling", "roles": {"structure", "roof", "furnishing", "litter"}},
    "snow_mirror": {"roof_mode": "closed_arch", "roles": {"structure", "roof", "furnishing"}},
    "piper_mountain": {"roof_mode": "cave_shell", "roles": {"structure", "roof", "furnishing", "litter"}},
}


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def check(scene_id: str, profile: dict, contract: dict) -> dict:
    errors: list[str] = []
    warnings: list[str] = []
    expected = EXPECTED[scene_id]
    if profile.get("roof_mode") != expected["roof_mode"]:
        errors.append(f"roof_mode={profile.get('roof_mode')!r}, expected {expected['roof_mode']!r}")
    envelope = float(profile.get("camera_envelope_half_width_m", 0.0))
    if envelope <= 0:
        errors.append("camera_envelope_half_width_m must be positive")
    if abs(float(profile.get("half_width_units", 0.0)) - envelope * 20.0) > 0.5:
        errors.append("half_width_units does not match camera envelope")
    assets = contract.get("assets", [])
    roles = {str(asset.get("role")) for asset in assets}
    missing_roles = sorted(expected["roles"] - roles)
    if missing_roles:
        errors.append("missing semantic roles: " + ", ".join(missing_roles))
    if contract.get("status") == "runtime_ready":
        warnings.append("runtime_ready is not allowed before visual acceptance")
    for asset in assets:
        path = str(asset.get("path", ""))
        if not path.startswith("res://"):
            errors.append(f"invalid asset path: {path}")
        elif not (ROOT / "godot" / path.removeprefix("res://")).is_file():
            errors.append(f"missing asset: {path}")
        if asset.get("status") not in {"annotated_candidate", "accepted", "runtime_ready"}:
            warnings.append(f"asset {asset.get('id')} has nonstandard status")
        if asset.get("representation") == "assembly" and not asset.get("sockets_m"):
            warnings.append(f"assembly {asset.get('id')} has no sockets_m; keep out of runtime_ready")
    if len(assets) < 5:
        warnings.append("fewer than five candidate assets; check whether the family is visually under-specified")
    return {"scene_id": scene_id, "status": "needs_art_or_annotation" if errors else "candidate_structurally_valid", "errors": errors, "warnings": warnings, "asset_count": len(assets), "roles": sorted(roles)}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    profiles = load(ROOT / "godot/data/scene3d_runtime_profiles.json")["profiles"]
    results = []
    for scene_id in EXPECTED:
        profile = profiles.get(scene_id)
        contract_path = ROOT / "godot/data" / f"scene3d_asset_contract_{scene_id}.json"
        if not profile or not contract_path.is_file():
            results.append({"scene_id": scene_id, "status": "needs_art_or_annotation", "errors": ["profile or contract missing"], "warnings": []})
            continue
        results.append(check(scene_id, profile, load(contract_path)))
    payload = {"schema_version": 1, "scope": "benchmark contracts only; structural check, not visual acceptance", "results": results}
    encoded = json.dumps(payload, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(encoded, encoding="utf-8")
    print(encoded, end="")
    return 1 if any(result["status"] == "needs_art_or_annotation" for result in results) else 0


if __name__ == "__main__":
    raise SystemExit(main())
