"""Validate a fully annotated Scene3D asset bundle.

The validator is intentionally conservative: null geometry is a reported
gap, never silently replaced with an image rectangle or zero-area footprint.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ROLES = {"structure", "wall", "roof", "canopy", "furnishing", "prop", "cover", "litter", "landmark"}
CONTACTS = {"rigid_feet", "conform_base", "ground_surface", "suspended"}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def finite_positive_pair(value):
    return isinstance(value, list) and len(value) == 2 and all(isinstance(x, (int, float)) and math.isfinite(x) and x > 0 for x in value)


def validate(bundle: dict) -> list[str]:
    errors: list[str] = []
    if not isinstance(bundle, dict):
        return ["bundle must be an object"]
    request = bundle.get("asset_request")
    spec = bundle.get("asset_spec")
    required_request = ["request_id", "scene_id", "physical_family", "role", "why_existing_assets_fail", "required_sockets", "size_source", "alpha_requirements", "opening_requirements", "footprint_requirements", "view_angles", "palette_reference", "source_prompt_path", "blocking_tasks", "status"]
    required_spec = ["id", "texture", "sha256", "role", "size_m", "anchor_uv", "footprints_m", "opening_uv", "contact", "sockets_m", "variant_family", "mirror_allowed", "height_band_m", "status"]
    for key in required_request:
        if not isinstance(request, dict) or key not in request:
            errors.append(f"asset_request missing {key}")
    for key in required_spec:
        if not isinstance(spec, dict) or key not in spec:
            errors.append(f"asset_spec missing {key}")
    if not isinstance(spec, dict):
        return errors
    if spec.get("role") not in ROLES:
        errors.append("asset_spec role is invalid")
    if spec.get("contact") not in CONTACTS:
        errors.append("asset_spec contact is invalid")
    if not finite_positive_pair(spec.get("size_m")):
        errors.append("asset_spec size_m must be positive")
    anchor = spec.get("anchor_uv")
    if not isinstance(anchor, list) or len(anchor) != 2 or not all(isinstance(x, (int, float)) and math.isfinite(x) and 0 <= x <= 1 for x in anchor):
        errors.append("asset_spec anchor_uv must be in 0..1")
    footprints = spec.get("footprints_m")
    if not isinstance(footprints, list) or not footprints:
        errors.append("asset_spec footprints_m is missing; zero-area bypass is forbidden")
    else:
        for index, polygon in enumerate(footprints):
            if not isinstance(polygon, list) or len(polygon) < 3:
                errors.append(f"footprints_m[{index}] must contain at least 3 points")
    texture = spec.get("texture")
    if not isinstance(texture, str) or not texture.startswith("res://"):
        errors.append("asset_spec texture must use res://")
    else:
        path = ROOT / "godot" / texture.removeprefix("res://")
        if not path.is_file():
            errors.append(f"asset texture missing: {texture}")
        elif spec.get("sha256") != sha256(path):
            errors.append(f"asset texture hash mismatch: {texture}")
    height_band = spec.get("height_band_m")
    if not isinstance(height_band, list) or len(height_band) != 2 or not all(isinstance(x, (int, float)) and math.isfinite(x) and x >= 0 for x in height_band) or height_band[0] > height_band[1]:
        errors.append("height_band_m is invalid")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundle", type=Path)
    args = parser.parse_args()
    try:
        bundle = json.loads(args.bundle.read_text(encoding="utf-8-sig"))
        errors = validate(bundle)
    except (OSError, json.JSONDecodeError, TypeError) as exc:
        errors = [f"invalid bundle: {exc}"]
    print(json.dumps({"valid": not errors, "errors": errors}, ensure_ascii=False, indent=2))
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
