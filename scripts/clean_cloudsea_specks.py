# -*- coding: utf-8 -*-
"""清理云海资产边缘的品红残点（wall-a/b/c 抠底后留下数百个低 alpha 杂点）。
判定：明显品红（r>200 且 b>150 且 g<120），或近品红低透明
（alpha<80 且红蓝均明显高于绿）→ 置全透明。覆盖写回并打印清理统计。"""
import glob

from PIL import Image

for path in sorted(glob.glob("assets/corridor/cloudsea/*.png")):
    img = Image.open(path).convert("RGBA")
    px = img.load()
    w, h = img.size
    n = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            if (r > 200 and b > 150 and g < 120) or (a < 80 and r > g + 60 and b > g + 60):
                px[x, y] = (0, 0, 0, 0)
                n += 1
    if n:
        img.save(path)
    print(f"{path}: {img.size} cleaned={n}")
