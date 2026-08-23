# -*- coding: utf-8 -*-
"""品红抠底 + 裁剪：处理走廊视差层素材（远山/近山/祥云），地面纹理仅缩放。"""
import sys
from PIL import Image

ASSETS = "assets"
OUT = "assets/corridor/forest"


def key_magenta(img: Image.Image) -> Image.Image:
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            # 品红判定：红蓝高、绿低。留一定容差吃掉压缩噪点/边缘溢色。
            if r > 150 and b > 150 and g < 110 and abs(r - b) < 90:
                px[x, y] = (0, 0, 0, 0)
            elif r > 120 and b > 120 and g < r - 60 and g < b - 60:
                # 半溢色边缘：按品红度衰减 alpha 并去掉品红染色
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
    x0 = max(0, x0 - pad)
    y0 = max(0, y0 - pad)
    x1 = min(img.width, x1 + pad)
    y1 = min(img.height, y1 + pad)
    return img.crop((x0, y0, x1, y1))


def process_keyed(name: str, out_name: str, max_w: int) -> None:
    img = Image.open(f"{ASSETS}/{name}")
    img = key_magenta(img)
    img = crop_alpha(img)
    if img.width > max_w:
        ratio = max_w / img.width
        img = img.resize((max_w, max(1, round(img.height * ratio))), Image.LANCZOS)
    img.save(f"{OUT}/{out_name}")
    print(out_name, img.size)


def process_tile(name: str, out_name: str, size: int) -> None:
    img = Image.open(f"{ASSETS}/{name}").convert("RGB")
    img = img.resize((size, size), Image.LANCZOS)
    img.save(f"{OUT}/{out_name}")
    print(out_name, img.size)


if __name__ == "__main__":
    process_keyed("mtn-far-raw.png", "mtn-far.png", 1024)
    process_keyed("mtn-near-raw.png", "mtn-near.png", 1024)
    process_keyed("cloud-strip-raw.png", "cloud-strip.png", 1024)
    process_tile("ground-tile-raw.png", "ground-tile.png", 512)
