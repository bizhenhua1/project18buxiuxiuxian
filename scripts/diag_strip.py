# -*- coding: utf-8 -*-
"""生成单精灵渐显条带图：同一精灵在多个捕获帧的裁剪并排。
用法: diag_strip.py <dir> <spriteId> <cap1,cap2,...> <out.png>
"""
import glob
import json
import sys

import numpy as np
from PIL import Image, ImageDraw

d, sid = sys.argv[1], int(sys.argv[2])
caps = [int(c) for c in sys.argv[3].split(",")]
out = sys.argv[4]
dbg = json.load(open(f"{d}/debug.json", encoding="utf-8"))
meta = json.load(open(f"{d}/capmeta.json"))
frames = dbg["frames"]
paths = sorted(glob.glob(f"{d}/c*.png"))
W, H = 1280, 800
panels = []
for ci in caps:
    f = {r["id"]: r for r in frames[meta[ci]["debugIndex"]]["sprites"]}
    r = f[sid]
    img = Image.open(paths[ci]).convert("RGB")
    pad = 14
    x, y, w, h = r["x"], r["y"], r["w"], r["h"]
    box = (max(0, x - pad), max(0, y - pad), min(W, x + w + pad), min(H, y + h + pad))
    a = np.asarray(img.convert("L"), dtype=np.float32)
    lum = a[max(0, y):min(H, y + h), max(0, x):min(W, x + w)].mean()
    c = img.crop(box).resize((int((box[2]-box[0]) * 1.6), int((box[3]-box[1]) * 1.6)), Image.LANCZOS)
    dr = ImageDraw.Draw(c)
    sx0, sy0 = int((x - box[0]) * 1.6), int((y - box[1]) * 1.6)
    dr.rectangle([sx0, sy0, sx0 + int(w * 1.6), sy0 + int(h * 1.6)], outline=(255, 80, 80), width=1)
    dr.text((3, 2), f"cap{ci}", fill=(255, 220, 120))
    dr.text((3, 14), f"z={r['z']:.0f}", fill=(255, 220, 120))
    dr.text((3, 26), f"dark={r.get('dark', 0):.2f}", fill=(255, 220, 120))
    dr.text((3, 38), f"fade={r['fade']:.2f}", fill=(255, 220, 120))
    panels.append(c)
hmax = max(c.height for c in panels) + 20
combo = Image.new("RGB", (sum(c.width for c in panels) + 6 * (len(panels) - 1), hmax), (16, 16, 16))
x = 0
for c in panels:
    combo.paste(c, (x, 20))
    x += c.width + 6
dr = ImageDraw.Draw(combo)
dr.text((4, 3), f"sprite id={sid}: continuous emergence (fixed)", fill=(140, 255, 140))
combo.save(out)
print("->", out)
