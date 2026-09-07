"""Copy final demo assets without changing their pixels; record provenance/hashes.

Run from any directory: python scripts/sync_godot_assets.py
The source PNGs remain authoritative. raw/process art is never imported.
"""
from pathlib import Path
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[1]
FOREST = (
    "tree-side", "tree-b", "tree-c", "grass-1", "grass-2", "grass-3",
    "grass-4", "foliage", "mtn-far", "mtn-near", "sun", "moon",
    "cloud-strip", "ground-tile",
)


def sync():
    pairs = [(f"assets/corridor/forest/{name}.png", f"godot/assets/forest/{name}.png") for name in FOREST]
    pairs.append(("assets/corridor/cloudsea/island-far.png", "godot/assets/landmarks/island-far.png"))
    for theme in ("cave", "cloudsea"):
        pairs.extend((str(src.relative_to(ROOT)).replace("\\", "/"), f"godot/assets/{theme}/{src.name}")
                     for src in sorted((ROOT / "assets/corridor" / theme).glob("*.png")))
    for family in ("style-e", "world"):
        folder = ROOT / "assets" / family
        for src in sorted(folder.rglob("*.png")):
            relative = src.relative_to(folder)
            if any(part in ("raw", "process", "legacy") for part in relative.parts):
                continue
            pairs.append((src.relative_to(ROOT).as_posix(), f"godot/assets/{family}/{relative.as_posix()}"))
    manifest = {"schema": 1, "source": "existing browser demo final PNGs", "pixel_changes": False, "files": []}
    for source, destination in pairs:
        src, dst = ROOT / source, ROOT / destination
        dst.parent.mkdir(parents=True, exist_ok=True)
        if not dst.exists() or src.read_bytes() != dst.read_bytes():
            shutil.copy2(src, dst)
        manifest["files"].append({"source": source, "destination": destination,
                                  "sha256": hashlib.sha256(src.read_bytes()).hexdigest(),
                                  "bytes": src.stat().st_size})
    (ROOT / "godot/assets/manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Verified {len(pairs)} byte-identical assets; wrote godot/assets/manifest.json")


if __name__ == "__main__":
    sync()
