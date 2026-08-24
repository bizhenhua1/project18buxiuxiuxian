# -*- coding: utf-8 -*-
"""格子美术切片。

产出两层资产：
1. slot-{type}.png   完整边框版（切自 slot-pack-raw.png，当前隐藏，留给后续「边框系统」启用）
2. emblem-{type}.png 仅中央底纹版（当前使用）：
   徽记切自 emblem-pack-raw.png（纯徽记品红底总表，无边框无角饰），
   暗底纹理取自 slot-plain.png 的干净内部区域，
   徽记以水印透明度合成居中，四边 alpha 软渐隐。
   （此前用整框内缩裁切的方案会把四角角饰带进保留区，已废弃。）
"""
import os
from PIL import Image, ImageFilter
from keyout_parallax import key_magenta, crop_alpha

FRAME_RAW = "assets/slot-pack-raw.png"
EMBLEM_RAW = "assets/emblem-pack-raw.png"
OUT = "assets/slots"
MAX_H = 320

# 宫格顺序（行优先）→ 格位类型，两张总表一致
ORDER = ["char", "fabao", "weapon", "spell", "beast", "monster", "locked", "plain"]

TILE_W, TILE_H = 160, 320   # 底纹成品尺寸（1:2 竖版）
EMBLEM_W_RATIO = 0.70       # 徽记占底纹宽度比例
EMBLEM_CY = 0.46            # 徽记中心纵向位置（避开底部格名标签）
EMBLEM_ALPHA = 0.60         # 水印感透明度
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


# 暗金单色调渐变：暗部 → 亮部（消除生成图里的粉肤色/品红残留，统一水印色调）
GOLD_DARK = (46, 34, 20)
GOLD_LIGHT = (226, 190, 118)


def recolor_gold(img: Image.Image) -> Image.Image:
    """徽记整体按亮度重映射为暗金单色调，保证八种徽记色调一致。"""
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            t = (r * 299 + g * 587 + b * 114) / 255000
            px[x, y] = (
                round(GOLD_DARK[0] + (GOLD_LIGHT[0] - GOLD_DARK[0]) * t),
                round(GOLD_DARK[1] + (GOLD_LIGHT[1] - GOLD_DARK[1]) * t),
                round(GOLD_DARK[2] + (GOLD_LIGHT[2] - GOLD_DARK[2]) * t),
                a,
            )
    return img


def make_base_tile() -> Image.Image:
    """从 slot-plain.png 内部干净区域取暗底纹理，镜像平铺成底纹坯板。"""
    plain = Image.open(f"{OUT}/slot-plain.png").convert("RGBA")
    pw, ph = plain.size
    patch = plain.crop((round(pw * 0.14), round(ph * 0.12), round(pw * 0.86), round(ph * 0.80)))
    patch = patch.resize((TILE_W, round(patch.height * TILE_W / patch.width)), Image.LANCZOS)
    tile = Image.new("RGBA", (TILE_W, TILE_H))
    y, flip = 0, False
    while y < TILE_H:
        band = patch.transpose(Image.FLIP_TOP_BOTTOM) if flip else patch
        tile.paste(band, (0, y))
        y += patch.height
        flip = not flip
    return tile.filter(ImageFilter.GaussianBlur(0.6))


def compose_emblem(base: Image.Image, emblem: Image.Image) -> Image.Image:
    tile = base.copy()
    ew = round(TILE_W * EMBLEM_W_RATIO)
    eh = round(emblem.height * ew / emblem.width)
    max_eh = round(TILE_H * 0.42)
    if eh > max_eh:
        eh = max_eh
        ew = round(emblem.width * eh / emblem.height)
    emblem = emblem.resize((ew, eh), Image.LANCZOS)
    a = emblem.getchannel("A").point(lambda v: round(v * EMBLEM_ALPHA))
    emblem.putalpha(a)
    ox = (TILE_W - ew) // 2
    oy = round(TILE_H * EMBLEM_CY - eh / 2)
    tile.alpha_composite(emblem, (ox, oy))
    return edge_fade(tile)


def main():
    os.makedirs(OUT, exist_ok=True)

    # 1) 完整边框版（保留给后续边框系统）
    sheet = key_magenta(Image.open(FRAME_RAW))
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

    # 2) 仅中央底纹版（当前使用）
    base = make_base_tile()
    esheet = key_magenta(Image.open(EMBLEM_RAW))
    ew, eh = esheet.size
    ecw, ech = ew // 4, eh // 2
    for i, name in enumerate(ORDER):
        col, row = i % 4, i // 4
        cell = esheet.crop((col * ecw, row * ech, (col + 1) * ecw, (row + 1) * ech))
        cell = crop_alpha(cell, pad=1)
        cell = recolor_gold(cell)
        out = compose_emblem(base, cell)
        out.save(f"{OUT}/emblem-{name}.png")
        print(f"emblem-{name}.png", out.size)


if __name__ == "__main__":
    main()
