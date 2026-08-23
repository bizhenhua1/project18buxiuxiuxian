# -*- coding: utf-8 -*-
"""装备图标切片：equip-pack-raw.png（品红底 2x4 宫格）→ 抠底、裁剪、缩放到七部位图标。"""
import os
from PIL import Image
from keyout_parallax import key_magenta, crop_alpha

RAW = "assets/equip-pack-raw.png"
OUT = "assets/equipment"
MAX_SIZE = 128

# 宫格顺序（行优先）→ 部位 id
ORDER = ["hat", "robe", "boots", "bracer", "ring", "amulet", "jade", "pouch"]


def keep_largest_component(img: Image.Image) -> Image.Image:
    """仅保留最大 alpha 连通块，清掉相邻宫格串进来的碎片。"""
    px = img.load()
    w, h = img.size
    seen = [[False] * w for _ in range(h)]
    best = None
    for sy in range(h):
        for sx in range(w):
            if seen[sy][sx] or px[sx, sy][3] < 8:
                continue
            stack = [(sx, sy)]
            seen[sy][sx] = True
            comp = []
            while stack:
                x, y = stack.pop()
                comp.append((x, y))
                for nx, ny in ((x-1, y), (x+1, y), (x, y-1), (x, y+1)):
                    if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and px[nx, ny][3] >= 8:
                        seen[ny][nx] = True
                        stack.append((nx, ny))
            if best is None or len(comp) > len(best):
                best = comp
    if best is None:
        return img
    keep = set(best)
    for y in range(h):
        for x in range(w):
            if px[x, y][3] >= 8 and (x, y) not in keep:
                px[x, y] = (0, 0, 0, 0)
    return img

def main():
    os.makedirs(OUT, exist_ok=True)
    sheet = key_magenta(Image.open(RAW))
    w, h = sheet.size
    cw, ch = w // 4, h // 2
    for i, name in enumerate(ORDER):
        col, row = i % 4, i // 4
        cell = sheet.crop((col * cw, row * ch, (col + 1) * cw, (row + 1) * ch))
        cell = keep_largest_component(cell)
        cell = crop_alpha(cell, pad=2)
        scale = MAX_SIZE / max(cell.size)
        if scale < 1:
            cell = cell.resize((max(1, round(cell.width * scale)), max(1, round(cell.height * scale))), Image.LANCZOS)
        cell.save(f"{OUT}/equip-{name}.png")
        print(f"equip-{name}.png", cell.size)

if __name__ == "__main__":
    main()
