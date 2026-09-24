"""Compile reviewed C1 ground-contact silhouettes; never modify source pixels.

This is NOT an automatic semantic root detector. The lower-band roles below
were inspected as ground-bearing rock. Roof/shoulder connectors are excluded.
Runtime consumes bounded bins once per placement, not image pixels per frame.
"""
from pathlib import Path
import hashlib
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ["modular/side-fill-v1.png", "modular/shoulder-rising-v3.png",
          "c1-candidates/side-mass-v1.png", "c1-candidates/side-layers-v2.png"]

def main():
    entries = {}
    for name in ASSETS:
        path = ROOT / "godot/assets/biomes/crystal" / name
        im = Image.open(path).convert("RGBA")
        w, h = im.size
        alpha = im.getchannel("A")
        points = []
        for x in range(w):
            for y in range(h - 1, int(h * .78) - 1, -1):
                if alpha.getpixel((x, y)) >= 128:
                    points.append((x, (y + .5) / h))
                    break
        bins = []
        for first in range(0, w, 16):
            group = [(x, y) for x, y in points if first <= x < first + 16]
            if group:
                bins.append([group[0][0] / w, (group[-1][0] + 1) / w,
                             min(y for _, y in group), max(y for _, y in group)])
        entries["res://assets/biomes/crystal/" + name] = {
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "dimensions": [w, h], "role": "ground_bearing_rigid_rock",
            "alpha_threshold": .5, "reviewed_foot_band": [.78, 1],
            "max_burial_fraction": .10,
            "budget_status": "authored_candidate_not_visual_acceptance",
            "bins_u0_u1_vmin_vmax": bins,
        }
    out = ROOT / "godot/data/scene_production/c1_ground_support.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps({"schema_version": 1, "assets": entries}, indent=2) + "\n", encoding="utf-8")
    print(f"C1_SUPPORT_COMPILED {len(entries)} reviewed sources")

if __name__ == "__main__":
    main()
