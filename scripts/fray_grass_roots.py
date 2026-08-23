# -*- coding: utf-8 -*-
"""草丛底部去硬切：对底部内容带做噪声调制的扇贝状 alpha 侵蚀，
让叶片各自收成参差根须，消除 chroma-key 裁切留下的平直底线。
原图备份到 process/pre-fray/。"""
import math
import os
import shutil

from PIL import Image

BASE = r"F:\GitHub\project18buxiuxiuxian\assets\corridor\forest"
BACKUP = os.path.join(BASE, "process", "pre-fray")
NAMES = ["grass-1.png", "grass-2.png", "grass-3.png", "grass-4.png", "foliage.png"]
BAND_FRAC = 0.12  # 底部 12% 内容高度参与侵蚀


def hash01(i, salt):
    return math.sin(i * 127.1 + salt * 311.7) * 43758.5453 % 1.0


def fray(path, seed):
    im = Image.open(path).convert("RGBA")
    px = im.load()
    w, h = im.size
    alpha = im.split()[3]
    bbox = alpha.getbbox()
    if not bbox:
        return
    x0, y0, x1, y1 = bbox
    ybot = y1 - 1  # 最后一行不透明内容
    band = max(6, int((y1 - y0) * BAND_FRAC))

    # 每列侵蚀深度：大扇贝 + 中簇 + 细叶三层正弦噪声，部分列近零保留触地根
    p1, p2, p3 = seed * 2.3, seed * 5.7, seed * 9.1
    lam1 = max(24.0, (x1 - x0) / 5.0)
    lam2 = max(9.0, (x1 - x0) / 22.0)
    lam3 = 4.3
    depths = {}
    for x in range(x0, x1):
        a = 0.5 + 0.5 * math.sin(2 * math.pi * x / lam1 + p1)
        b = 0.5 + 0.5 * math.sin(2 * math.pi * x / lam2 + p2 + a * 2.1)
        c = 0.5 + 0.5 * math.sin(2 * math.pi * x / lam3 + p3)
        n = (0.55 * a + 0.30 * b + 0.15 * c) ** 1.35
        depths[x] = n * band

    for x in range(x0, x1):
        d = depths[x]
        if d < 0.75:
            continue
        for y in range(max(y0, ybot - int(d)), ybot + 1):
            r, g, b_, a_ = px[x, y]
            if a_ == 0:
                continue
            dist = ybot - y
            t = dist / d  # 0 = 图像底边, 1 = 该列切口顶
            t = max(0.0, min(1.0, t))
            f = t * t * (3 - 2 * t)  # smoothstep 羽化
            # 细微逐像素抖动，打散平滑边
            f *= 0.9 + 0.2 * hash01(x * 7 + y * 13, seed)
            na = int(a_ * max(0.0, min(1.0, f)))
            px[x, y] = (r, g, b_, na)
    im.save(path)
    print("frayed:", os.path.basename(path), f"band={band}px bottom_row={ybot}")


def main():
    os.makedirs(BACKUP, exist_ok=True)
    for i, name in enumerate(NAMES):
        src = os.path.join(BASE, name)
        bak = os.path.join(BACKUP, name)
        if not os.path.exists(bak):
            shutil.copy2(src, bak)
        fray(src, seed=i + 3)


if __name__ == "__main__":
    main()
