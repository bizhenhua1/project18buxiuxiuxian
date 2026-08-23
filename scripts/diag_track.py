# -*- coding: utf-8 -*-
"""追踪单个精灵跨捕获帧的实测亮度轨迹。用法: diag_track.py <dir> <spriteId> [start] [end]"""
import glob
import json
import sys

import numpy as np
from PIL import Image

d, sid = sys.argv[1], int(sys.argv[2])
c0 = int(sys.argv[3]) if len(sys.argv) > 3 else 0
c1 = int(sys.argv[4]) if len(sys.argv) > 4 else 999
dbg = json.load(open(f"{d}/debug.json", encoding="utf-8"))
meta = json.load(open(f"{d}/capmeta.json"))
frames = dbg["frames"]
paths = sorted(glob.glob(f"{d}/c*.png"))
W, H = 1280, 800
prev = None
for ci in range(c0, min(c1, len(paths))):
    fi = meta[ci]["debugIndex"]
    f = {r["id"]: r for r in frames[fi]["sprites"]}
    r = f.get(sid)
    if not r:
        print(f"cap{ci} (not drawn)")
        prev = None
        continue
    a = np.asarray(Image.open(paths[ci]).convert("L"), dtype=np.float32)
    x0, y0 = max(0, r["x"]), max(0, r["y"])
    x1, y1 = min(W, r["x"] + r["w"]), min(H, r["y"] + r["h"])
    lum = a[y0:y1, x0:x1].mean()
    dstr = f" Δ{lum - prev:+6.1f}" if prev is not None else "        "
    if r.get("bucket") is not None:
        extra = f"bucket={r['bucket']} " + ("afterFog " if r.get("afterFog") else "beforeFog")
    else:
        extra = f"dark={r.get('dark'):5.3f}"
    print(f"cap{ci:03d} z={r['z']:7.1f} {extra} fade={r['fade']:5.3f} lum={lum:6.1f}{dstr}")
    prev = lum
