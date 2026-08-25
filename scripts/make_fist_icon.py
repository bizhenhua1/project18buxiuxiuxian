# -*- coding: utf-8 -*-
"""手持卡血槽底纹：style-e-ui-fist-raw.png（品红底握拳图标）→ 抠底、裁剪、缩放到 96px。"""
from PIL import Image
from keyout_parallax import key_magenta, crop_alpha

RAW = "assets/style-e/raw/style-e-ui-fist-raw.png"
OUT = "assets/style-e/style-e-ui-fist.png"
MAX_SIZE = 96


def main():
    img = key_magenta(Image.open(RAW))
    img = crop_alpha(img, pad=2)
    scale = MAX_SIZE / max(img.size)
    if scale < 1:
        img = img.resize((max(1, round(img.width * scale)), max(1, round(img.height * scale))), Image.LANCZOS)
    img.save(OUT)
    print(OUT, img.size)


if __name__ == "__main__":
    main()
