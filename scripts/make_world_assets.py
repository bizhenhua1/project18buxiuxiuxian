# -*- coding: utf-8 -*-
"""世界地图资产生成后处理：严格品红抠底。

策略（比走廊流水线更严）：
1. 从四边向内洪水填充品红连通域 —— 只抠与背景连通的品红，不误伤件内暗紫。
2. 硬阈值再扫一遍剩余高品红像素。
3. 仅对「已抠像素」2px 邻域做溢色去品红 + alpha 衰减，禁止全局半品红判定。
4. QC：统计残留品红像素、边缘触边、alpha bbox。

用法:
  python scripts/make_world_assets.py
  python scripts/make_world_assets.py --only grass_1
"""
from __future__ import annotations

import argparse
import json
import os
from collections import deque

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.path.join(ROOT, "assets", "world", "forest")
RAW = os.path.join(BASE, "raw")
OUT_BASE = os.path.join(BASE, "base")
OUT_FEAT = os.path.join(BASE, "feature")
PROCESS = os.path.join(BASE, "process")

# 硬品红：必须非常接近 #FF00FF
HARD = lambda r, g, b: r >= 200 and b >= 200 and g <= 70 and abs(r - b) <= 40
# 软品红：洪水填充扩展（吃压缩噪点），仍要求红蓝明显高于绿
SOFT = lambda r, g, b: r >= 165 and b >= 165 and g <= 115 and abs(r - b) <= 70 and min(r, b) - g >= 55

JOBS = [
    # kind, raw_name, out_rel, max_side, pad
    ("base", "grass_1-raw.png", "base/grass_1.png", 420, 2),
    ("base", "grass_2-raw.png", "base/grass_2.png", 420, 2),
    ("base", "leaf_1-raw.png", "base/leaf_1.png", 420, 2),
    ("base", "rock_1-raw.png", "base/rock_1.png", 420, 2),
    ("base", "water_1-raw.png", "base/water_1.png", 420, 2),
    ("base", "soil_core-raw.png", "base/soil_core.png", 420, 2),
    ("base", "rock_core-raw.png", "base/rock_core.png", 420, 2),
    ("base", "river_ew-raw.png", "base/river_ew.png", 420, 2),
    ("base", "river_ns-raw.png", "base/river_ns.png", 420, 2),
    ("feature", "giant_tree_1-raw.png", "feature/giant_tree_1.png", 520, 2),
    ("feature", "mountain_1-raw.png", "feature/mountain_1.png", 480, 2),
    ("feature", "cave_1-raw.png", "feature/cave_1.png", 480, 2),
    ("feature", "mountain_link_mid-raw.png", "link/mountain_mid.png", 480, 2),
    ("pack", "grove_pack-raw.png", None, 280, 2),
    ("pack", "river_corners-raw.png", None, 420, 2),
    ("pack", "river_ports_and_bases-raw.png", None, 420, 2),
    ("pack", "mountain_ends-raw.png", None, 420, 2),
]

PACKS = {
    "grove_pack-raw.png": {
        "rows": 2, "cols": 2, "max_side": 280,
        "cells": [
            ("feature/grove_1.png", 0, 0),
            ("feature/rockpile_1.png", 0, 1),
            ("feature/flower_1.png", 1, 0),
            ("feature/shrub_1.png", 1, 1),
        ],
    },
    "river_corners-raw.png": {
        "rows": 2, "cols": 2, "max_side": 420,
        "cells": [
            ("base/river_ne.png", 0, 0),
            ("base/river_nw.png", 0, 1),
            ("base/river_se.png", 1, 0),
            ("base/river_sw.png", 1, 1),
        ],
    },
    "river_ports_and_bases-raw.png": {
        "rows": 2, "cols": 2, "max_side": 420,
        "cells": [
            ("base/river_source.png", 0, 0),
            ("base/river_mouth.png", 0, 1),
            ("base/grass_3.png", 1, 0),
            ("base/leaf_2.png", 1, 1),
        ],
    },
    "mountain_ends-raw.png": {
        "rows": 1, "cols": 2, "max_side": 420,
        "cells": [
            ("link/mountain_end_l.png", 0, 0),
            ("link/mountain_end_r.png", 0, 1),
        ],
    },
}


def is_soft_magenta(r, g, b, a=255):
    if a < 8:
        return True
    return SOFT(r, g, b)


def flood_key(img: Image.Image) -> Image.Image:
    """从画布边缘洪水填充软品红，置透明。"""
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()
    seen = bytearray(w * h)
    q = deque()

    def try_push(x, y):
        i = y * w + x
        if seen[i]:
            return
        r, g, b, a = px[x, y]
        if is_soft_magenta(r, g, b, a):
            seen[i] = 1
            q.append((x, y))

    for x in range(w):
        try_push(x, 0)
        try_push(x, h - 1)
    for y in range(h):
        try_push(0, y)
        try_push(w - 1, y)

    while q:
        x, y = q.popleft()
        px[x, y] = (0, 0, 0, 0)
        if x > 0:
            try_push(x - 1, y)
        if x + 1 < w:
            try_push(x + 1, y)
        if y > 0:
            try_push(x, y - 1)
        if y + 1 < h:
            try_push(x, y + 1)
    return img


def hard_key_remaining(img: Image.Image) -> Image.Image:
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a > 0 and HARD(r, g, b):
                px[x, y] = (0, 0, 0, 0)
    return img


def despill_ring(img: Image.Image, radius: int = 2) -> Image.Image:
    """只对透明像素邻域做去品红溢色，避免误伤暗紫山体/树影。"""
    w, h = img.size
    px = img.load()
    keyed = bytearray(w * h)
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0:
                keyed[y * w + x] = 1
    near = bytearray(w * h)
    for y in range(h):
        row = y * w
        for x in range(w):
            if not keyed[row + x]:
                continue
            for dy in range(-radius, radius + 1):
                yy = y + dy
                if yy < 0 or yy >= h:
                    continue
                nrow = yy * w
                for dx in range(-radius, radius + 1):
                    xx = x + dx
                    if 0 <= xx < w:
                        near[nrow + xx] = 1
    for y in range(h):
        for x in range(w):
            i = y * w + x
            if keyed[i] or not near[i]:
                continue
            r, g, b, a = px[x, y]
            if r > 130 and b > 130 and g < r - 50 and g < b - 50:
                spill = min(r, b) - g
                fade = max(0, 255 - spill * 4)
                nr = min(r, g + 28)
                nb = min(b, g + 28)
                px[x, y] = (nr, g, nb, min(a, fade))
    return img


def heal_interior_magenta(img: Image.Image) -> Image.Image:
    """件内残留品红（生成溢进树冠的洋红高光）用邻域非品红色回填，不打洞。"""
    w, h = img.size
    px = img.load()
    bad = []
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a >= 40 and (HARD(r, g, b) or SOFT(r, g, b)):
                bad.append((x, y))
    for x, y in bad:
        sr = sg = sb = n = 0
        for dy in range(-2, 3):
            for dx in range(-2, 3):
                xx, yy = x + dx, y + dy
                if xx < 0 or yy < 0 or xx >= w or yy >= h:
                    continue
                r, g, b, a = px[xx, yy]
                if a < 40:
                    continue
                if HARD(r, g, b) or SOFT(r, g, b):
                    continue
                sr += r; sg += g; sb += b; n += 1
        a = px[x, y][3]
        if n:
            r, g, b = sr // n, sg // n, sb // n
        else:
            r, g, b, a = px[x, y]
        if HARD(r, g, b) or SOFT(r, g, b):
            g = max(g, 40)
            r = min(r, g + 32)
            b = min(b, g + 32)
        px[x, y] = (r, g, b, a)
    return img


def kill_magenta_fringe(img: Image.Image) -> Image.Image:
    """半透明品红毛边一律掐掉：a<40 直接清；品红倾向且 a<96 也清。"""
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            mag = r >= 140 and b >= 140 and g <= 90 and min(r, b) - g >= 40
            if a < 40 or (mag and a < 96):
                px[x, y] = (0, 0, 0, 0)
    return img


def crop_alpha(img: Image.Image, pad: int = 2) -> Image.Image:
    bbox = img.getchannel("A").getbbox()
    if not bbox:
        return img
    x0, y0, x1, y1 = bbox
    return img.crop((
        max(0, x0 - pad),
        max(0, y0 - pad),
        min(img.width, x1 + pad),
        min(img.height, y1 + pad),
    ))


def limit_side(img: Image.Image, max_side: int) -> Image.Image:
    m = max(img.width, img.height)
    if m <= max_side:
        return img
    s = max_side / m
    return img.resize((max(1, round(img.width * s)), max(1, round(img.height * s))), Image.LANCZOS)


def qc(img: Image.Image) -> dict:
    w, h = img.size
    px = img.load()
    magenta = 0
    opaque = 0
    edge = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 40:
                continue
            opaque += 1
            if HARD(r, g, b) or SOFT(r, g, b):
                magenta += 1
            if x == 0 or y == 0 or x == w - 1 or y == h - 1:
                if a > 48:
                    edge += 1
    return {
        "size": [w, h],
        "opaque": opaque,
        "residual_magenta": magenta,
        "edge_touch": edge,
        "ok": magenta == 0 and opaque > 80,
    }


def process_one(src: str, dest: str, max_side: int, pad: int) -> dict:
    raw = Image.open(src)
    img = flood_key(raw)
    img = hard_key_remaining(img)
    img = despill_ring(img, 2)
    img = kill_magenta_fringe(img)
    for _ in range(4):
        img = heal_interior_magenta(img)
    img = crop_alpha(img, pad)
    img = limit_side(img, max_side)
    img = kill_magenta_fringe(img)
    for _ in range(2):
        img = heal_interior_magenta(img)
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    img.save(dest)
    report = qc(img)
    report["src"] = os.path.relpath(src, ROOT)
    report["dest"] = os.path.relpath(dest, ROOT)
    return report


def split_pack(src: str, spec: dict) -> list[dict]:
    raw = Image.open(src).convert("RGBA")
    rows, cols = spec["rows"], spec["cols"]
    cw, ch = raw.width // cols, raw.height // rows
    reports = []
    for path, row, col in spec["cells"]:
        cell = raw.crop((col * cw, row * ch, (col + 1) * cw, (row + 1) * ch))
        dest = os.path.join(BASE, path)
        tmp = os.path.join(PROCESS, os.path.basename(path).replace(".png", "-cell.png"))
        os.makedirs(PROCESS, exist_ok=True)
        cell.save(tmp)
        reports.append(process_one(tmp, dest, spec["max_side"], 2))
    return reports


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    args = ap.parse_args()
    os.makedirs(OUT_BASE, exist_ok=True)
    os.makedirs(OUT_FEAT, exist_ok=True)
    os.makedirs(PROCESS, exist_ok=True)

    reports = []
    for kind, raw_name, out_rel, max_side, pad in JOBS:
        if args.only and args.only not in raw_name and args.only not in (out_rel or ""):
            continue
        src = os.path.join(RAW, raw_name)
        if not os.path.isfile(src):
            print("SKIP missing", raw_name)
            continue
        if kind == "pack":
            spec = PACKS.get(raw_name)
            if not spec:
                print("SKIP no pack spec", raw_name)
                continue
            reports.extend(split_pack(src, spec))
        else:
            dest = os.path.join(BASE, out_rel)
            reports.append(process_one(src, dest, max_side, pad))

    qc_path = os.path.join(PROCESS, "qc.json")
    with open(qc_path, "w", encoding="utf-8") as f:
        json.dump(reports, f, ensure_ascii=False, indent=2)
    for r in reports:
        flag = "OK" if r.get("ok") else "FAIL"
        print(f"{flag} {r.get('dest')} magenta={r.get('residual_magenta')} edge={r.get('edge_touch')} {r.get('size')}")


if __name__ == "__main__":
    main()
