"""Build a review-only contact sheet from existing runtime captures."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--columns", type=int, default=6)
    parser.add_argument("--kind", choices=("beauty", "diagnostic"), default="beauty")
    args = parser.parse_args()
    scenes = []
    for manifest in sorted(args.root.glob("*/manifest.json")):
        data = json.loads(manifest.read_text(encoding="utf-8"))
        capture = next((item for item in data["captures"] if item.get("kind", "") == args.kind), None)
        if capture is None:
            # P01 manifests use one unlabelled capture; keep the tool useful
            # for those records while never silently substituting beauty for a
            # requested diagnostic frame.
            if args.kind != "beauty":
                continue
            capture = data["captures"][0]
        image = Image.open(manifest.parent / capture["image"]).convert("RGB")
        scenes.append((str(data["requested_scene"]), image))
    if not scenes:
        raise SystemExit("no manifests found")
    thumb_w, thumb_h = 320, 200
    label_h = 30
    columns = max(1, args.columns)
    rows = (len(scenes) + columns - 1) // columns
    sheet = Image.new("RGB", (columns * thumb_w, rows * (thumb_h + label_h)), "#101719")
    draw = ImageDraw.Draw(sheet)
    for index, (scene, image) in enumerate(scenes):
        x = (index % columns) * thumb_w
        y = (index // columns) * (thumb_h + label_h)
        image.thumbnail((thumb_w, thumb_h), Image.Resampling.LANCZOS)
        cell = Image.new("RGB", (thumb_w, thumb_h), "#1b2526")
        cell.paste(image, ((thumb_w - image.width) // 2, (thumb_h - image.height) // 2))
        sheet.paste(cell, (x, y))
        draw.text((x + 8, y + thumb_h + 6), scene, fill="#e4d5b4")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(args.output)
    print(f"SCENE3D_CONTACT_SHEET_PASS scenes={len(scenes)} output={args.output}")


if __name__ == "__main__":
    main()
