# -*- coding: utf-8 -*-
"""洞穴主题资产流水线：品红抠底 → 3x3 道具切片 → alpha 裁剪 → 根部侵蚀 → 限尺寸。
输入 assets/corridor/cave/raw/*-raw.png，输出 assets/corridor/cave/*.png。
与 keyout_parallax.py 同一套品红判定，另加两点：
  1) 半溢色 alpha 衰减只作用于"品红邻接边缘带"（2px 膨胀），
     防止画面内的暗紫水晶被当成品红误伤；
  2) 地被类道具跑 fray_grass_roots 同款底部扇贝侵蚀，消除平直底线。
"""
import math
import os
import shutil

from PIL import Image

BASE = "assets/corridor/cave"
RAW = os.path.join(BASE, "raw")
BACKUP = os.path.join(BASE, "process", "pre-fray")

# 3x3 道具拼图 → 单件（行优先）
PROP_NAMES = [
    "deco-stalag-1", "deco-stalag-2", "deco-mushroom",
    "deco-crystal-a", "deco-crystal-b", "deco-bones",
    "deco-lantern", "deco-rubble-1", "deco-rubble-2",
]


def key_magenta(img: Image.Image) -> Image.Image:
    """品红置透明；半溢色衰减仅限品红邻接的 2px 边缘带。"""
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    keyed = bytearray(w * h)
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if r > 150 and b > 150 and g < 110 and abs(r - b) < 90:
                px[x, y] = (0, 0, 0, 0)
                keyed[y * w + x] = 1
    # 品红邻域膨胀 2px：只有贴着被抠区域的像素才做溢色衰减
    near = bytearray(w * h)
    for y in range(h):
        for x in range(w):
            if not keyed[y * w + x]:
                continue
            for dy in range(-2, 3):
                yy = y + dy
                if yy < 0 or yy >= h:
                    continue
                row = yy * w
                for dx in range(-2, 3):
                    xx = x + dx
                    if 0 <= xx < w:
                        near[row + xx] = 1
    for y in range(h):
        for x in range(w):
            if keyed[y * w + x] or not near[y * w + x]:
                continue
            r, g, b, a = px[x, y]
            if r > 120 and b > 120 and g < r - 60 and g < b - 60:
                spill = min(r, b) - g
                fade = max(0, 255 - spill * 3)
                nr = min(r, g + 40)
                nb = min(b, g + 40)
                px[x, y] = (nr, g, nb, min(a, fade))
    return img


def crop_alpha(img: Image.Image, pad: int = 2) -> Image.Image:
    bbox = img.getchannel("A").getbbox()
    if not bbox:
        return img
    x0, y0, x1, y1 = bbox
    return img.crop((max(0, x0 - pad), max(0, y0 - pad),
                     min(img.width, x1 + pad), min(img.height, y1 + pad)))


def limit(img: Image.Image, max_side: int) -> Image.Image:
    m = max(img.width, img.height)
    if m <= max_side:
        return img
    ratio = max_side / m
    return img.resize((max(1, round(img.width * ratio)),
                       max(1, round(img.height * ratio))), Image.LANCZOS)


def hash01(i, salt):
    return math.sin(i * 127.1 + salt * 311.7) * 43758.5453 % 1.0


def fray_bottom(img: Image.Image, seed: int, band_frac: float = 0.10) -> Image.Image:
    """底部扇贝状 alpha 侵蚀（同 fray_grass_roots.py），消除抠底平直底线。"""
    px = img.load()
    alpha = img.split()[3]
    bbox = alpha.getbbox()
    if not bbox:
        return img
    x0, y0, x1, y1 = bbox
    ybot = y1 - 1
    band = max(4, int((y1 - y0) * band_frac))
    p1, p2, p3 = seed * 2.3, seed * 5.7, seed * 9.1
    lam1 = max(24.0, (x1 - x0) / 5.0)
    lam2 = max(9.0, (x1 - x0) / 22.0)
    lam3 = 4.3
    for x in range(x0, x1):
        a = 0.5 + 0.5 * math.sin(2 * math.pi * x / lam1 + p1)
        b = 0.5 + 0.5 * math.sin(2 * math.pi * x / lam2 + p2 + a * 2.1)
        c = 0.5 + 0.5 * math.sin(2 * math.pi * x / lam3 + p3)
        d = ((0.55 * a + 0.30 * b + 0.15 * c) ** 1.35) * band
        if d < 0.75:
            continue
        for y in range(max(y0, ybot - int(d)), ybot + 1):
            r, g, b_, a_ = px[x, y]
            if a_ == 0:
                continue
            t = max(0.0, min(1.0, (ybot - y) / d))
            f = (t * t * (3 - 2 * t)) * (0.9 + 0.2 * hash01(x * 7 + y * 13, seed))
            px[x, y] = (r, g, b_, int(a_ * max(0.0, min(1.0, f))))
    return img


def process_big(name: str, max_side: int) -> None:
    """侧景大件（岩拱/岩柱）：抠底 + 裁剪 + 限尺寸，不做根部侵蚀。"""
    img = Image.open(os.path.join(RAW, f"{name}-raw.png"))
    img = limit(crop_alpha(key_magenta(img)), max_side)
    out = os.path.join(BASE, f"{name}.png")
    img.save(out)
    print(f"{name}.png", img.size)


def drop_edge_strays(cell: Image.Image, margin_frac: float = 0.15) -> Image.Image:
    """删除完全落在格子外缘带的连通域——那是邻格越界画进来的碎片。
    与中央区域（内缩 margin_frac）有交集的连通域全部保留，
    所以像散落尸骨这类多连通域道具不受影响。"""
    w, h = cell.size
    alpha = cell.getchannel("A")
    data = list(alpha.getdata())
    seen = bytearray(w * h)
    cx0, cy0 = w * margin_frac, h * margin_frac
    cx1, cy1 = w * (1 - margin_frac), h * (1 - margin_frac)
    px = cell.load()
    for start in range(w * h):
        if seen[start] or data[start] <= 12:
            continue
        stack = [start]
        seen[start] = 1
        comp = []
        touches_center = False
        while stack:
            p = stack.pop()
            comp.append(p)
            y, x = divmod(p, w)
            if cx0 <= x <= cx1 and cy0 <= y <= cy1:
                touches_center = True
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if 0 <= nx < w and 0 <= ny < h:
                    q = ny * w + nx
                    if not seen[q] and data[q] > 12:
                        seen[q] = 1
                        stack.append(q)
        if not touches_center:
            for p in comp:
                y, x = divmod(p, w)
                r, g, b, _ = px[x, y]
                px[x, y] = (r, g, b, 0)
    return cell


def depink(cell: Image.Image) -> Image.Image:
    """去暖粉残留（灯笼光晕/零星噪点被生成为偏粉色调，逃过品红判定）：
    暖粉 = 红高且红>蓝、蓝明显高于绿；紫水晶蓝>红、橙色火焰蓝远低于绿，都不受影响。"""
    px = cell.load()
    w, h = cell.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a and r > 140 and r > b and b > g + 10 and r > g + 50:
                px[x, y] = (r, g, b, 0)
    return cell


def process_props() -> None:
    """3x3 道具拼图：整图抠底后按九宫格切片，各自裁剪 + 底部侵蚀。"""
    os.makedirs(BACKUP, exist_ok=True)
    sheet = key_magenta(Image.open(os.path.join(RAW, "props-pack-raw.png")))
    w, h = sheet.size
    cw, ch = w // 3, h // 3
    for i, name in enumerate(PROP_NAMES):
        cx, cy = (i % 3) * cw, (i // 3) * ch
        cell = drop_edge_strays(sheet.crop((cx, cy, cx + cw, cy + ch)))
        cell = depink(cell)
        cell = crop_alpha(cell)
        cell = limit(cell, 256)
        pre = os.path.join(BACKUP, f"{name}.png")
        cell.save(pre)  # 侵蚀前备份
        cell = fray_bottom(cell, seed=i + 5)
        out = os.path.join(BASE, f"{name}.png")
        cell.save(out)
        print(f"{name}.png", cell.size)


def process_tile() -> None:
    img = Image.open(os.path.join(RAW, "ground-tile-raw.png")).convert("RGB")
    img = img.resize((512, 512), Image.LANCZOS)
    img.save(os.path.join(BASE, "ground-tile.png"))
    print("ground-tile.png", img.size)


if __name__ == "__main__":
    process_big("arch-a", 1024)
    process_big("arch-b", 1024)
    process_big("pillar-a", 1024)
    process_big("pillar-b", 1024)
    process_big("pillar-c", 1024)
    process_props()
    process_tile()
