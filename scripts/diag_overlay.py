# -*- coding: utf-8 -*-
"""把 debug 帧记录叠加到对应捕获帧上：矩形+z/bucket/fade/afterFog。
用法: python scripts/diag_overlay.py <dir> <capIndex> [capIndex2 ...]
"""
import glob
import json
import sys

from PIL import Image, ImageDraw

d = sys.argv[1]
caps = [int(a) for a in sys.argv[2:]]
dbg = json.load(open(f"{d}/debug.json", encoding="utf-8"))
meta = json.load(open(f"{d}/capmeta.json", encoding="utf-8"))
frames = dbg["frames"]
paths = sorted(glob.glob(f"{d}/c*.png"))

for ci in caps:
    fi = meta[ci]["debugIndex"]
    f = frames[fi]
    img = Image.open(paths[ci]).convert("RGB")
    dr = ImageDraw.Draw(img)
    for r in f["sprites"]:
        if r["kind"] != "tree":
            continue
        col = (255, 90, 90) if not r["afterFog"] else (90, 200, 255)
        dr.rectangle([r["x"], r["y"], r["x"] + r["w"], r["y"] + r["h"]], outline=col, width=1)
        dr.text((r["x"] + 2, r["y"] + 2),
                f"#{r['id']} z{r['z']:.0f} b{r['bucket']} f{r['fade']}",
                fill=(255, 255, 100))
    dr.text((8, 780), f"cap{ci} debugFrame{fi} camZ={f['camZ']:.1f} 红=雾带前绘制 蓝=雾带后绘制",
            fill=(255, 200, 200))
    out = f"{d}/overlay_{ci:04d}.png"
    img.save(out)
    print("->", out)
