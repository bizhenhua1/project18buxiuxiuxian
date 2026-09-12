"""Validate extracted art and write measured anchors plus authored sizes."""
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'art/fairytales/corridor'


def main():
    specs = json.loads((OUT/'dressing-specs.json').read_text(encoding='utf-8'))
    names = {s['id']: s['name'] for s in json.loads((ROOT/'godot/data/fairytale_scenes.json').read_text(encoding='utf-8-sig'))}
    report = []
    sheet = Image.new('RGB', (1530, len(specs)*218), '#202930')
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 18)
    for row, (scene, entries) in enumerate(specs.items()):
        extraction = json.loads((OUT/f'{scene}-props.json').read_text())
        assert len(extraction['accepted']) == 9 and not extraction.get('rejected'), scene
        assets = []
        draw.text((12, row*218+2), names[scene], font=font, fill='#efe3cb')
        for col, (key, label, role, low, high) in enumerate(entries):
            path = ROOT/f'godot/assets/fairytales/{scene}/dressing/{key}/prop.png'
            im = Image.open(path).convert('RGBA')
            rgba = np.array(im)
            a = rgba[:, :, 3]
            assert a.max() > 220 and (a == 0).any(), str(path)
            assert not np.any(a[0]) and not np.any(a[-1]) and not np.any(a[:, 0]) and not np.any(a[:, -1]), str(path)
            ys, xs = np.where(a > 32)
            bottom = int(ys.max())+1
            anchor = [.5, bottom/im.height]
            assets.append({'id': key, 'name': label, 'texture': f'dressing/{key}/prop.png',
                           'role': role, 'height_min': low, 'height_max': high,
                           'ground_anchor': anchor, 'alpha_height_fraction': (bottom-int(ys.min()))/im.height,
                           'allow_on_road': role == 'litter'})
            preview = im.copy()
            preview.thumbnail((150, 148), Image.Resampling.LANCZOS)
            sheet.paste(preview, (col*170+(170-preview.width)//2, row*218+30+148-preview.height), preview)
            draw.text((col*170+10,row*218+184), f'{label} {low}–{high}',font=font,fill='#c8c1b2')
        payload = {'version': 1, 'size_units': 'layout_world_visible_height', 'assets': assets}
        target = ROOT/f'godot/assets/fairytales/{scene}/dressing.json'
        target.write_text(json.dumps(payload,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        report.append({'scene': scene, 'count':len(assets), 'edge_checks':'passed', 'runtime_verified':False})
    sheet.save(OUT/'dressing-overview.jpg',quality=93)
    (OUT/'dressing-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'{len(report)} scenes, {sum(r["count"] for r in report)} extracted sprites checked; runtime verification pending')


if __name__ == '__main__':
    main()
