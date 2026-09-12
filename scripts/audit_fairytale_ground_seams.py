"""Inspect raw repeat boundaries; previews only, never rewrites production art."""
from pathlib import Path
import json
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'art/fairytales/corridor/ground-audit'
OUT.mkdir(parents=True, exist_ok=True)
assets = [('baseline_forest', ROOT / 'godot/assets/style2/ground.png')]
assets += [('baseline_' + k, ROOT / f'godot/assets/biomes/{k}/ground.png') for k in ['crystal','swamp','sewer','whale','palace']]
assets += [(s['id'], ROOT / f"godot/assets/fairytales/{s['id']}/ground.png") for s in json.loads((ROOT/'godot/data/fairytale_scenes.json').read_text(encoding='utf-8'))]
report = []
overview = Image.new('RGB', (960, 6 * 265), '#202020')
draw = ImageDraw.Draw(overview)
for idx, (key, path) in enumerate(assets):
    im = Image.open(path).convert('RGB')
    a = np.asarray(im, dtype=np.float32)
    dx = np.abs(a[:, 1:] - a[:, :-1]).mean(axis=(0,2))
    dy = np.abs(a[1:] - a[:-1]).mean(axis=(1,2))
    sx = float(np.abs(a[:,0]-a[:,-1]).mean())
    sy = float(np.abs(a[0]-a[-1]).mean())
    report.append(dict(scene=key, file=str(path.relative_to(ROOT)), size=list(im.size), seam_x=sx, seam_y=sy,
        seam_x_vs_internal_p95=sx/max(float(np.percentile(dx,95)),.01),
        seam_y_vs_internal_p95=sy/max(float(np.percentile(dy,95)),.01)))
    tile = im.resize((384,384), Image.Resampling.LANCZOS)
    preview = Image.new('RGB',(768,768))
    for y in [0,384]:
        for x in [0,384]: preview.paste(tile,(x,y))
    preview.save(OUT/f'{key}-repeat.jpg',quality=94)
    ox, oy = (idx%4)*240, (idx//4)*265
    overview.paste(preview.resize((240,240),Image.Resampling.LANCZOS),(ox,oy))
    draw.text((ox+4,oy+244),key,fill='white')
overview.save(OUT/'overview.jpg',quality=94)
(OUT/'measurements.json').write_text(json.dumps({'method':'RGB edge jump relative to 95th percentile internal adjacent-row/column jump; flags discontinuity only, not visual quality or tile motif continuity','assets':report},indent=2),encoding='utf-8')
for r in sorted(report,key=lambda r:max(r['seam_x_vs_internal_p95'],r['seam_y_vs_internal_p95']),reverse=True):
    print(r['scene'], round(r['seam_x_vs_internal_p95'],2),round(r['seam_y_vs_internal_p95'],2))
