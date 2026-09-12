"""Measure generated sprite geometry; never draw or invent production art."""
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'godot/assets/fairytales'
OUT = ROOT / 'art/fairytales/corridor'


def inspect(path):
    im = Image.open(path).convert('RGBA')
    rgba = np.array(im)
    alpha = rgba[:, :, 3]
    mask = alpha > 32
    ys, xs = np.where(mask)
    x0, y0, x1, y1 = int(xs.min()), int(ys.min()), int(xs.max())+1, int(ys.max())+1
    width, height = im.size
    kind = 'shell' if 'shell' in path.stem else 'side'
    edge_touch = bool(mask[0].any() or mask[-1].any() or mask[:, 0].any() or mask[:, -1].any())
    rgb = rgba[:, :, :3].astype(int)
    pink = (rgb[:, :, 0] > 210) & (rgb[:, :, 2] > 210) & (rgb[:, :, 1] < 60) & (alpha > 32)
    feet = np.where(mask[max(y0, y1-int((y1-y0)*.08)):y1].any(axis=0))[0]
    anchor_x = .5 if kind == 'shell' else float(np.median(feet))/width
    data = {'file': path.name, 'role': kind, 'image_size': [width, height],
            'alpha_bounds': [x0, y0, x1, y1], 'ground_anchor': [anchor_x, y1/height],
            'edge_touch': edge_touch, 'residual_key_pixels': int(pink.sum()),
            'status': 'geometry_checked_runtime_pending'}
    if kind == 'shell':
        center = width//2
        gaps = []
        for y in range(y0+int((y1-y0)*.45), y0+int((y1-y0)*.95)):
            if mask[y, center]:
                gaps.append(0)
                continue
            left = np.where(mask[y, :center])[0]
            right = np.where(mask[y, center:])[0]
            gaps.append((center+int(right[0]) if right.size else width)-(int(left[-1])+1 if left.size else 0))
        clear = min(gaps)/width
        # 150-unit travel belt + 45-unit clearance per side. Keep aspect ratio.
        canvas_height = max(320, 240/(clear*width/height)) if clear > 0 else None
        data.update({'lower_passage_min_width_fraction': round(clear, 5),
                     'suggested_canvas_height': round(canvas_height, 2) if canvas_height else None,
                     'suggested_canvas_width': round(canvas_height*width/height, 2) if canvas_height else None,
                     'minimum_travel_clearance': 240, 'repeat_distance_range': [130, 210]})
    else:
        data.update({'suggested_canvas_height': 230, 'repeat_distance_range': [150, 240],
                     'placement': 'outside_each_road_using_footprint',
                     'lower_footprint_x': [int(feet.min())/width, int(feet.max()+1)/width]})
    if edge_touch or pink.any():
        data['status'] = 'needs_cleanup'
    return data


def main():
    scenes = json.loads((ROOT/'godot/data/fairytale_scenes.json').read_text(encoding='utf-8-sig'))
    records = []
    sheet = Image.new('RGB', (1440, 6*255), '#202930')
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 19)
    for i, scene in enumerate(scenes):
        paths = list((ASSETS/scene['id']).glob('corridor-*.png'))
        assert len(paths) == 1, scene['id']
        path = paths[0]
        data = inspect(path)
        assert data['status'] != 'needs_cleanup', (scene['id'], data)
        (path.parent/'corridor.json').write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
        records.append({'scene': scene['id'], **data})
        im = Image.open(path).convert('RGBA')
        im.thumbnail((456, 208), Image.Resampling.LANCZOS)
        x, y = (i%3)*480, (i//3)*255
        sheet.paste(im, (x+(480-im.width)//2, y+30+(210-im.height)//2), im)
        draw.text((x+12,y+4), scene['name'], font=font, fill='#e0dbca')
    report = {'asset_count': len(records), 'source': 'built-in image_gen',
              'runtime_integrated': False, 'small_prop_gap_remaining': 90, 'assets': records}
    (OUT/'geometry-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    sheet.save(OUT/'corridor-overview.jpg', quality=93)
    print(json.dumps({'count': len(records), 'geometry_checked': True, 'runtime_integrated': False}))


if __name__ == '__main__':
    main()
