# -*- coding: utf-8 -*-
"""远景区(z>THRESH)平滑度统计：相邻帧同精灵实测亮度跳变分布。用法: diag_farzone.py <dir> [thresh]"""
import glob
import json
import sys

import numpy as np
from PIL import Image

d = sys.argv[1]
TH = float(sys.argv[2]) if len(sys.argv) > 2 else 500
dbg = json.load(open(f"{d}/debug.json", encoding="utf-8"))
meta = json.load(open(f"{d}/capmeta.json"))
frames = dbg["frames"]
paths = sorted(glob.glob(f"{d}/c*.png"))
W, H = 1280, 800
imgs = [np.asarray(Image.open(p).convert("L"), dtype=np.float32) for p in paths]

def mean_rect(a, r):
    x0, y0 = max(0, r["x"]), max(0, r["y"])
    x1, y1 = min(W, r["x"] + r["w"]), min(H, r["y"] + r["h"])
    if x1 <= x0 or y1 <= y0:
        return None
    return float(a[y0:y1, x0:x1].mean())

jumps = []
for i in range(len(meta) - 1):
    f0 = {r["id"]: r for r in frames[meta[i]["debugIndex"]]["sprites"]}
    f1 = {r["id"]: r for r in frames[meta[i + 1]["debugIndex"]]["sprites"]}
    for sid, r1 in f1.items():
        r0 = f0.get(sid)
        if not r0 or r1["z"] < TH or r1["w"] * r1["h"] < 900:
            continue
        m0, m1 = mean_rect(imgs[i], r0), mean_rect(imgs[i + 1], r1)
        if m0 is None or m1 is None:
            continue
        jumps.append((abs(m1 - m0), i, sid, r0, r1, m0, m1))

jumps.sort(key=lambda e: -e[0])
arr = np.array([j[0] for j in jumps])
print(f"z>{TH:.0f} 样本对: {len(arr)}, 亮度|Δ| 均值={arr.mean():.2f} p95={np.percentile(arr,95):.2f} "
      f"p99={np.percentile(arr,99):.2f} 最大={arr.max():.2f} (0..255)")
print("TOP8:")
for aj, i, sid, r0, r1, m0, m1 in jumps[:8]:
    print(f"  cap{i:02d}->{i+1:02d} id={sid} {r1['kind']} z {r0['z']}->{r1['z']} {r1['w']}x{r1['h']} "
          f"lum {m0:.1f}->{m1:.1f} dark {r0.get('dark','-')}->{r1.get('dark','-')} "
          f"bucket {r0.get('bucket','-')}->{r1.get('bucket','-')} fade {r0['fade']}->{r1['fade']}")
