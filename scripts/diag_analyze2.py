# -*- coding: utf-8 -*-
"""逐帧对齐分析：每个精灵在相邻捕获帧间的实测亮度变化，关联 bucket/fade/雾带翻转。
用法: python scripts/diag_analyze2.py <dir> [--crops <prefix>]
"""
import glob
import json
import sys

import numpy as np
from PIL import Image, ImageDraw

d = sys.argv[1]
crop_prefix = None
if "--crops" in sys.argv:
    crop_prefix = sys.argv[sys.argv.index("--crops") + 1]

dbg = json.load(open(f"{d}/debug.json", encoding="utf-8"))
meta = json.load(open(f"{d}/capmeta.json", encoding="utf-8"))
frames = dbg["frames"]
recycles = dbg["recycles"]
paths = sorted(glob.glob(f"{d}/c*.png"))
W, H = 1280, 800

print(f"captures: {len(paths)}, debug frames: {len(frames)}, recycles: {len(recycles)}")
bad_recycle = [r for r in recycles if r["zRel"] < 1450]
print(f"[b] recycle 进入可见区: {len(bad_recycle)} / {len(recycles)}"
      + (f"  最近重入 zRel={min(r['zRel'] for r in recycles):.0f}" if recycles else ""))

imgs = [np.asarray(Image.open(p).convert("L"), dtype=np.float32) for p in paths]

def mean_rect(a, r):
    x0, y0 = max(0, r["x"]), max(0, r["y"])
    x1, y1 = min(W, r["x"] + r["w"]), min(H, r["y"] + r["h"])
    if x1 <= x0 or y1 <= y0:
        return None
    return float(a[y0:y1, x0:x1].mean())

events = []   # (jump, i, sid, r0, r1, m0, m1, why)
appear = []   # 新出现精灵的首帧实测亮度
for i in range(len(meta) - 1):
    m0i, m1i = meta[i]["debugIndex"], meta[i + 1]["debugIndex"]
    if m0i < 0 or m1i >= len(frames) or m0i >= len(frames):
        continue
    f0 = {r["id"]: r for r in frames[m0i]["sprites"]}
    f1 = {r["id"]: r for r in frames[m1i]["sprites"]}
    for sid, r1 in f1.items():
        r0 = f0.get(sid)
        if r0 is None:
            lum = mean_rect(imgs[i + 1], r1)
            appear.append((i + 1, sid, r1, lum))
            continue
        if r1["w"] * r1["h"] < 900:
            continue
        m0 = mean_rect(imgs[i], r0)
        m1 = mean_rect(imgs[i + 1], r1)
        if m0 is None or m1 is None:
            continue
        why = []
        if r0.get("bucket") is not None and r1.get("bucket") != r0.get("bucket"):
            why.append(f"bucket {r0['bucket']}->{r1['bucket']}")
        if r0.get("afterFog") is not None and r1.get("afterFog") != r0.get("afterFog"):
            why.append("fogOrderFlip")
        events.append((m1 - m0, i, sid, r0, r1, m0, m1, ",".join(why) or "-"))

events.sort(key=lambda e: -abs(e[0]))
print("\n[实测] 相邻帧同一精灵区域亮度跳变 TOP15 (0..255):")
for jump, i, sid, r0, r1, m0, m1, why in events[:15]:
    print(f"  cap{i:02d}->{i+1:02d} id={sid} {r1['kind']} z {r0['z']}->{r1['z']} "
          f"{r1['w']}x{r1['h']} lum {m0:.1f}->{m1:.1f} (Δ{jump:+.1f}) fade {r0['fade']}->{r1['fade']} [{why}]")

n_bucket = sum(1 for e in events if "bucket" in e[7])
big = [e for e in events if abs(e[0]) > 6]
big_bucket = [e for e in big if "bucket" in e[7] or "fog" in e[7]]
print(f"\n跳变>6灰阶的事件: {len(big)}, 其中带 bucket跳档/雾带翻转标记: {len(big_bucket)}")

appear_vis = [(i, sid, r, lum) for i, sid, r, lum in appear if r["fade"] > 0.05]
print(f"[b'] 新出现精灵: {len(appear)}, 首帧 fade>0.05: {len(appear_vis)}")
for i, sid, r, lum in appear_vis[:8]:
    print(f"    cap{i} id={sid} {r['kind']} z={r['z']} fade={r['fade']} lum={lum}")

if crop_prefix:
    shown = 0
    used = set()
    for jump, i, sid, r0, r1, m0, m1, why in events:
        if shown >= 3 or sid in used or r1["w"] * r1["h"] < 8000:
            continue
        used.add(sid)
        pad = 26
        panels = []
        st0 = f"bucket {r0['bucket']}" if r0.get("bucket") is not None else f"dark {r0.get('dark')}"
        st1 = f"bucket {r1['bucket']}" if r1.get("bucket") is not None else f"dark {r1.get('dark')}"
        for idx, (r, m, lab) in enumerate(((r0, m0, f"frame N ({st0})"),
                                           (r1, m1, f"frame N+1 ({st1})"))):
            img = Image.open(paths[i + idx]).convert("RGB")
            x, y, w, h = r["x"], r["y"], r["w"], r["h"]
            box = (max(0, x - pad), max(0, y - pad), min(W, x + w + pad), min(H, y + h + pad))
            c = img.crop(box)
            dr = ImageDraw.Draw(c)
            dr.rectangle([x - box[0], y - box[1], x + w - box[0], y + h - box[1]],
                         outline=(255, 80, 80), width=2)
            dr.text((4, 2), f"{lab} mean={m:.1f}", fill=(255, 220, 120))
            panels.append(c)
        hmax = max(c.height for c in panels)
        combo = Image.new("RGB", (panels[0].width + panels[1].width + 8, hmax + 18), (18, 18, 18))
        combo.paste(panels[0], (0, 18))
        combo.paste(panels[1], (panels[0].width + 8, 18))
        dr = ImageDraw.Draw(combo)
        dr.text((4, 2), f"{r1['kind']} id={sid} z {r0['z']}->{r1['z']} lum {m0:.1f}->{m1:.1f} "
                        f"(one frame, {why})", fill=(255, 120, 120))
        out = f"{crop_prefix}_jump{shown}_id{sid}.png"
        combo.save(out)
        print("crop ->", out)
        shown += 1
