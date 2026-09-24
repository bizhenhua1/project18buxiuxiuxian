"""Validate v2 screenshot provenance, NOT visual quality or scene completion.

Each manifest represents exactly one fresh run directory. Files are relative
to that directory; timestamps alone never establish current code provenance.
"""
import argparse
import hashlib
import json
import math
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE_KEYS = {
    "godot/scripts/world3d/route_view.gd",
    "godot/scripts/world3d/scenery.gd",
    "godot/scripts/world3d/projection.gd",
    "godot/scripts/spaces/layouts/fairytale_corridor.gd",
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate(data, directory, root=ROOT):
    errors = []

    def require(ok, message):
        if not ok:
            errors.append(message)

    def local(base, name):
        if not isinstance(name, str) or not name:
            return None
        target = (base / name).resolve()
        return target if target.is_relative_to(base.resolve()) and target.is_file() else None

    require(data.get("schema_version") == 2, "schema_version must be 2")
    for key in ("run_id", "created_utc", "engine_version", "command", "entry"):
        require(bool(data.get(key)), f"missing {key}")
    requested = data.get("requested_scene")
    require(bool(requested), "requested_scene missing")
    sources = data.get("source_sha256", {})
    require(isinstance(sources, dict) and SOURCE_KEYS <= sources.keys(), "core source hashes missing")
    for section in ("source_sha256", "asset_sha256", "settings_sha256"):
        hashes = data.get(section, {})
        require(isinstance(hashes, dict) and bool(hashes), f"{section} empty")
        if not isinstance(hashes, dict):
            continue
        base = directory if section == "settings_sha256" else root
        for name, expected in hashes.items():
            path = local(base, name)
            require(path is not None and digest(path) == expected, f"{section} mismatch: {name}")
    captures = data.get("captures", [])
    require(isinstance(captures, list) and bool(captures), "no captures")
    seen = set()
    for shot in captures if isinstance(captures, list) else []:
        require(shot.get("scene") == requested, "actual scene differs from requested scene")
        require(shot.get("native_node_confirmed") is True, "native node not confirmed")
        require(shot.get("phase") == shot.get("expected_phase") and bool(shot.get("phase")), "phase mismatch")
        for key in ("seed", "branch", "route_s_m", "viewport", "camera_transform", "projection_matrix"):
            require(key in shot, f"capture missing {key}")
        for key, length in (("camera_transform", 12), ("projection_matrix", 16)):
            values = shot.get(key, [])
            require(isinstance(values, list) and len(values) == length and
                    all(isinstance(v, (int, float)) and math.isfinite(v) for v in values), f"invalid {key}")
            require(isinstance(values, list) and any(isinstance(v, (int, float)) and v != 0 for v in values), f"placeholder {key}")
        name = shot.get("image")
        require(isinstance(name, str) and name not in seen, "missing or duplicate image")
        if isinstance(name, str):
            seen.add(name)
        image = local(directory, name)
        require(image is not None, f"missing or escaped image: {name}")
        if image:
            content = image.read_bytes()
            require(digest(image) == shot.get("sha256"), f"image hash mismatch: {name}")
            valid_png = len(content) >= 24 and content[:8] == b"\x89PNG\r\n\x1a\n" and content[12:16] == b"IHDR"
            require(valid_png, f"not a PNG: {name}")
            if valid_png:
                require(list(struct.unpack(">II", content[16:24])) == shot.get("viewport"), f"viewport mismatch: {name}")
    log = local(directory, data.get("log"))
    require(log is not None, "log missing")
    if log:
        contents = log.read_text(encoding="utf-8-sig", errors="replace")
        require("SCRIPT ERROR" not in contents and "ERROR:" not in contents, "runtime errors in log")
        marker = data.get("completion_marker")
        require(isinstance(marker, str) and bool(marker) and marker in contents, "completion marker missing")
    require(data.get("visual_status") in ("unreviewed", "needs_revision", "user_approved"), "visual_status must be explicit")
    if data.get("visual_status") == "user_approved":
        require(bool(data.get("user_decision_reference")), "user approval reference missing")
    return errors


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args()
    try:
        result = validate(json.loads(args.manifest.read_text(encoding="utf-8-sig")), args.manifest.resolve().parent)
    except (ValueError, TypeError, KeyError, AttributeError, OSError) as exc:
        result = [f"invalid manifest: {exc}"]
    print(json.dumps({"provenance_valid": not result, "errors": result,
                      "visual_acceptance": "not evaluated by this tool"}, ensure_ascii=False, indent=2))
    raise SystemExit(1 if result else 0)
