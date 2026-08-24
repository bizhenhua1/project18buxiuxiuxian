# -*- coding: utf-8 -*-
"""格子美术切片：slot-pack-raw.png（品红底 2x4 宫格，1:2 竖框）。

产出两层资产：
1. slot-{type}.png   完整边框版（当前隐藏，留给后续「边框系统」启用）
2. emblem-{type}.png 仅中央底纹版（内缩裁掉边框 + 四边软渐隐，当前使用）
"""
import os
from PIL import Image
from keyout_parallax import key_magenta, crop_alpha

RAW = "assets/slot-pack-raw.png"
OUT = "assets/slots"
MAX_H = 320

# 宫格顺序（行优先）→ 格位类型
ORDER = ["char", "fabao", "weapon", "spell", "beast", "monster", "locked", "plain"]

# 各类型边框厚度不同：内缩比例 (x, y)，裁掉外框只留暗底+徽记
EMBLEM_INSET = {
    "char": (0.14, 0.10),
    "fabao": (0.14, 0.10),
    "weapon": (0.15, 0.11),   # 四角刀刃较宽
    "spell": (0.15, 0.11),    # 云纹外扩
    "beast": (0.14, 0.10),
    "monster": (0.17, 0.13),  # 獠牙锯齿边最厚
    "locked": (0.11, 0.08),   # 链条横贯中央，属于要保留的符纹意象
    "plain": (0.10, 0.08),
}

FADE_PX = 12


def edge_fade(img: Image.Image, fade: int = FADE_PX) -> Image.Image:
    """四边 alpha 软渐隐，避免无边框时出现生硬矩形切边。"""
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            d = min(x + 1, y + 1, w - x, h - y)
            if d < fade:
                r, g, b, a = px[x, y]
                px[x, y] = (r, g, b, round(a * d / fade))
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    sheet = key_magenta(Image.open(RAW))
    w, h = sheet.size
    cw, ch = w // 4, h // 2
    for i, name in enumerate(ORDER):
        col, row = i % 4, i // 4
        cell = sheet.crop((col * cw, row * ch, (col + 1) * cw, (row + 1) * ch))
        cell = crop_alpha(cell, pad=1)
        if cell.height > MAX_H:
            scale = MAX_H / cell.height
            cell = cell.resize((max(1, round(cell.width * scale)), MAX_H), Image.LANCZOS)
        cell.save(f"{OUT}/slot-{name}.png")

        ix, iy = EMBLEM_INSET[name]
        ex0 = round(cell.width * ix)
        ey0 = round(cell.height * iy)
        emblem = cell.crop((ex0, ey0, cell.width - ex0, cell.height - ey0))
        emblem = edge_fade(emblem)
        emblem.save(f"{OUT}/emblem-{name}.png")
        print(f"slot-{name}.png {cell.size} -> emblem {emblem.size}")


if __name__ == "__main__":
    main()
