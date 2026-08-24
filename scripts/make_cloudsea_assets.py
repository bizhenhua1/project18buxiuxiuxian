# -*- coding: utf-8 -*-
"""云海主题资产流水线：品红抠底 → 2x2 拼图切片 → 去粉 → alpha 裁剪 → 限尺寸。
输入 assets/corridor/cloudsea/raw/*-raw.png，输出 assets/corridor/cloudsea/*.png。
复用 make_cave_assets 的品红判定/裁剪/杂点清理；云朵蓬松底缘由画稿自带，
不做 fray 底部侵蚀。仙山远景条带两端为渐隐入品红的粉色云尾，靠 depink 清除。
"""
import os

from PIL import Image

from make_cave_assets import crop_alpha, depink, drop_edge_strays, key_magenta, limit

BASE = "assets/corridor/cloudsea"
RAW = os.path.join(BASE, "raw")

# 2x2 拼图 → 单件（行优先）
ROCK_NAMES = ["rock-1", "rock-2", "rock-3", "rock-4"]
PUFF_NAMES = ["puff-1", "puff-2", "puff-3", "puff-4"]


def depurple(img: Image.Image) -> Image.Image:
    """去紫粉残雾：仙山条带两端"渐隐入品红"的云尾会留下紫粉过渡色
    （红蓝都明显高于绿）。青绿山体 g 高、乳白云 rgb 接近、金边 b 低，均不受影响。"""
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a and r > g + 40 and b > g + 40:
                px[x, y] = (r, g, b, 0)
    return img


def process_single(name: str, max_side: int) -> None:
    """单件大图（云墙/仙山远景）：抠底 + 去粉 + 裁剪 + 限尺寸。"""
    img = Image.open(os.path.join(RAW, f"{name}-raw.png"))
    img = limit(crop_alpha(depurple(depink(key_magenta(img)))), max_side)
    img.save(os.path.join(BASE, f"{name}.png"))
    print(f"{name}.png", img.size)


def process_pack(raw_name: str, names, max_side: int) -> None:
    """2x2 拼图：整图抠底后四宫格切片，各自清杂点 + 去粉 + 裁剪。"""
    sheet = key_magenta(Image.open(os.path.join(RAW, f"{raw_name}-raw.png")))
    w, h = sheet.size
    cw, ch = w // 2, h // 2
    for i, name in enumerate(names):
        cx, cy = (i % 2) * cw, (i // 2) * ch
        cell = drop_edge_strays(sheet.crop((cx, cy, cx + cw, cy + ch)))
        cell = limit(crop_alpha(depink(cell)), max_side)
        cell.save(os.path.join(BASE, f"{name}.png"))
        print(f"{name}.png", cell.size)


if __name__ == "__main__":
    process_single("wall-a", 1024)
    process_single("wall-b", 1024)
    process_single("wall-c", 1024)
    process_single("island-far", 1400)
    process_pack("rocks-pack", ROCK_NAMES, 256)
    process_pack("puffs-pack", PUFF_NAMES, 300)
