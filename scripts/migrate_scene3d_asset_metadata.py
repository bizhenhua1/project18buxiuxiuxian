"""Migrate legacy fairytale metadata without inventing geometry.

The result is an audit ledger, not runtime-ready AssetSpec data. Unknown
footprints, sockets and physical sizes remain null and are listed explicitly.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

try:
    from PIL import Image
except ImportError:  # pragma: no cover - migration remains lossless without probing
    Image = None

ROOT = Path(__file__).resolve().parents[1]


def read(path: Path, fallback):
    try:
        return json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return fallback


def digest(path: Path) -> str | None:
    if not path.is_file():
        return None
    return hashlib.sha256(path.read_bytes()).hexdigest()


def texture_record(scene_id: str, relative: str, legacy: dict, role: str | None) -> dict:
    path = ROOT / "godot/assets/fairytales" / scene_id / relative
    anchor = legacy.get("anchor", legacy.get("ground_anchor")) if isinstance(legacy, dict) else None
    image_size = legacy.get("image_size") if isinstance(legacy, dict) else None
    width = legacy.get("width") if isinstance(legacy, dict) else None
    height = legacy.get("height") if isinstance(legacy, dict) else None
    if (width is None or height is None) and isinstance(image_size, list) and len(image_size) >= 2:
        width = image_size[0] if width is None else width
        height = image_size[1] if height is None else height
    size_px = [width, height] if width is not None and height is not None else None
    size_px_source = "legacy_metadata" if size_px is not None else None
    alpha_bounds_px = None
    alpha_edge_touch = None
    if size_px is None and Image is not None and path.is_file():
        try:
            with Image.open(path) as image:
                size_px = [int(image.width), int(image.height)]
                size_px_source = "file_header"
        except (OSError, ValueError):
            size_px = None
    if Image is not None and path.is_file():
        try:
            with Image.open(path) as image:
                rgba = image.convert("RGBA")
                alpha = rgba.getchannel("A")
                bounds = alpha.getbbox()
                alpha_bounds_px = list(bounds) if bounds else None
                if bounds:
                    left, top, right, bottom = bounds
                    alpha_edge_touch = left == 0 or top == 0 or right == rgba.width or bottom == rgba.height
                else:
                    alpha_edge_touch = False
        except (OSError, ValueError):
            alpha_bounds_px = None
            alpha_edge_touch = None
    return {
        "id": f"{scene_id}:{relative}",
        "texture": f"res://assets/fairytales/{scene_id}/{relative}",
        "sha256": digest(path),
        "legacy_role": legacy.get("role") if isinstance(legacy, dict) else None,
        "role_guess": role,
        "legacy_metadata": legacy,
        "size_px": size_px,
        "size_px_source": size_px_source,
        "alpha_bounds_px": alpha_bounds_px,
        "alpha_edge_touch": alpha_edge_touch,
        "anchor_uv": anchor,
        "size_m": None,
        "footprints_m": None,
        "opening_uv": None,
        "contact": None,
        "sockets_m": None,
        "status": "unannotated",
        "missing_fields": ["size_m", "footprints_m", "contact", "sockets_m"],
    }


def migrate_scene(scene: dict) -> dict:
    scene_id = str(scene["id"])
    folder = ROOT / "godot/assets/fairytales" / scene_id
    corridor = read(folder / "corridor.json", {})
    anchors = read(folder / "anchors.json", {})
    dressing = read(folder / "dressing.json", {}).get("assets", [])
    furnishings = read(folder / "furnishings.json", {}).get("assets", [])
    assets = []
    corridor_file = corridor.get("file")
    if corridor_file:
        assets.append(texture_record(scene_id, str(corridor_file), corridor, "structure"))
    for entry in dressing:
        texture = entry.get("texture")
        if texture:
            assets.append(texture_record(scene_id, str(texture), entry, entry.get("role")))
    for entry in furnishings:
        texture = entry.get("file")
        if texture:
            assets.append(texture_record(scene_id, str(texture), entry, "furnishing"))
    # Preserve anchor metadata even when no corresponding asset was referenced
    # by a layout file. This prevents silent loss during normalization.
    referenced = {item["texture"].split(f"/{scene_id}/", 1)[-1] for item in assets}
    for filename, metadata in anchors.items():
        if filename not in referenced:
            assets.append(texture_record(scene_id, filename, metadata, None))
    missing = [item["texture"] for item in assets if item["sha256"] is None]
    return {
        "scene_id": scene_id,
        "physical_family": scene.get("space"),
        "legacy_sources": {
            "corridor": f"godot/assets/fairytales/{scene_id}/corridor.json",
            "anchors": f"godot/assets/fairytales/{scene_id}/anchors.json",
            "dressing": f"godot/assets/fairytales/{scene_id}/dressing.json",
            "furnishings": f"godot/assets/fairytales/{scene_id}/furnishings.json",
        },
        "assets": assets,
        "missing_texture_paths": missing,
        "runtime_ready": False,
        "status": "needs_annotation",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path,
                        default=ROOT / "docs/design/SCENE3D-ASSET-MIGRATION.json")
    args = parser.parse_args()
    catalog = read(ROOT / "godot/data/fairytale_scenes.json", [])
    scenes = [migrate_scene(scene) for scene in catalog]
    data = {
        "schema_version": 1,
        "scope": "lossless legacy metadata migration ledger; not runtime acceptance",
        "units": {"legacy": "layout world units", "target": "metres", "conversion": "not applied until source semantics are reviewed"},
        "scenes": scenes,
        "summary": {
            "scene_count": len(scenes),
            "asset_count": sum(len(scene["assets"]) for scene in scenes),
            "runtime_ready_count": sum(scene["runtime_ready"] for scene in scenes),
            "missing_texture_count": sum(len(scene["missing_texture_paths"]) for scene in scenes),
        },
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("P03_METADATA_MIGRATION scenes=%d assets=%d runtime_ready=0 missing_textures=%d" % (
        data["summary"]["scene_count"], data["summary"]["asset_count"], data["summary"]["missing_texture_count"]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
