# -*- coding: utf-8 -*-
"""格子框切片：slot-pack-raw.png（品红底 2x4 宫格，1:2 竖框）→ 抠底、裁剪、缩放输出。"""
import os
from PIL import Image
from keyout_parallax import key_magenta, crop_alpha

RAW = "assets/slot-pack-raw.png"
OUT = "assets/slots"
MAX_H = 320

# 宫格顺序（行优先）→ 格位类型
ORDER = ["char", "fabao", "weapon", "spell", "beast", "monster", "locked", "plain"]

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
        print(f"slot-{name}.png", cell.size)

if __name__ == "__main__":
    main()
