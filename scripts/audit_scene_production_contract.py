"""Read-only asset inventory for the 3D production handoff; no visual pass claims."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig")) if path.exists() else {}


def inventory():
    scenes = read(ROOT / "godot/data/fairytale_scenes.json")
    result = []
    for scene in scenes:
        folder = ROOT / "godot/assets/fairytales" / scene["id"]
        corridor = read(folder / "corridor.json")
        dressing = read(folder / "dressing.json").get("assets", [])
        furniture = read(folder / "furnishings.json").get("assets", [])
        side = read(folder / "branch-side.json")
        refs = [corridor.get("file"), side.get("file")]
        refs += [e.get("texture") for e in dressing]
        refs += [e.get("file") for e in furniture]
        result.append({
            "id": scene["id"], "name": scene["name"], "space": scene["space"],
            "story_parent_not_geometry_baseline": scene["parent"],
            "corridor": corridor, "branch_side": side,
            "dressing_roles": {role: sum(e.get("role") == role for e in dressing)
                               for role in sorted({e.get("role", "unknown") for e in dressing})},
            "furniture_variants": len(furniture),
            "referenced_asset_missing": [ref for ref in refs if ref and not (folder / ref).exists()],
            "has_explicit_ceiling_manifest": (folder / "ceiling.json").exists(),
            "acceptance": "unreviewed; file presence is not visual acceptance",
        })
    files = ["godot/scripts/spaces/biome_catalog.gd",
             "godot/scripts/spaces/layouts/biome_layout.gd",
             "godot/scripts/spaces/layouts/fairytale_corridor.gd",
             "godot/scripts/world3d/scenery.gd", "godot/scripts/world3d/route_view.gd"]
    return {"schema_version": 1, "scope": "read-only repository inventory, not runtime capture",
            "source_sha256": {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in files},
            "scenes": result}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    data = inventory()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    missing = sum(len(s["referenced_asset_missing"]) for s in data["scenes"])
    print(f"INVENTORY scenes={len(data['scenes'])} missing_references={missing}; visual_acceptance=unreviewed")
    raise SystemExit(1 if missing else 0)
