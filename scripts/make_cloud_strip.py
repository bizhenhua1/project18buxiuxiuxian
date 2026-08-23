# -*- coding: utf-8 -*-
"""云簇包 → 高分辨率云条带：品红抠底、按 2×2 象限切簇、alpha 裁剪，
横向拼接（簇间留全透明间隔，渲染器按透明列自动切簇）。"""
import sys

from PIL import Image

sys.path.insert(0, "scripts")
from keyout_parallax import key_magenta, crop_alpha

RAW = "assets/corridor/forest/raw/cloud-pack-raw.png"
OUT = "assets/corridor/forest/cloud-strip.png"
GAP = 24  # 簇间透明间隔（>6px 即可被切簇识别）
# 云尾方向统一（渲染器不再随机镜像）：原包 TL/BL 尾朝左、TR/BR 尾朝右，
# 镜像 TR/BR 使全部云尾朝左——云头在前，与向右的横向风匹配。
FLIP = [False, True, False, True]


def main():
    img = key_magenta(Image.open(RAW))
    w, h = img.size
    cells = [
        img.crop((0, 0, w // 2, h // 2)),
        img.crop((w // 2, 0, w, h // 2)),
        img.crop((0, h // 2, w // 2, h)),
        img.crop((w // 2, h // 2, w, h)),
    ]
    clusters = [
        crop_alpha(c.transpose(Image.FLIP_LEFT_RIGHT) if f else c)
        for c, f in zip(cells, FLIP)
    ]
    total_w = sum(c.width for c in clusters) + GAP * (len(clusters) + 1)
    max_h = max(c.height for c in clusters)
    strip = Image.new("RGBA", (total_w, max_h), (0, 0, 0, 0))
    x = GAP
    for c in clusters:
        strip.paste(c, (x, max_h - c.height))
        print("cluster:", c.size)
        x += c.width + GAP
    strip.save(OUT)
    print("strip:", strip.size)


if __name__ == "__main__":
    main()
