"""Create review contact sheets from real runtime captures; measure file budgets."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'art/fairytales/corridor/review-20260916'
OUT.mkdir(exist_ok=True)
scenes=json.loads((ROOT/'godot/data/fairytale_scenes.json').read_text(encoding='utf-8-sig'))
font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',18)
for mode in ['travel','battle','world']:
    for page in range(3):
        board=Image.new('RGB',(1440,656),'#111818')
        draw=ImageDraw.Draw(board)
        for i,scene in enumerate(scenes[page*6:page*6+6]):
            capture=ROOT/f'tempassets/work/fairytales/{scene["id"]}-{mode}.png'
            im=Image.open(capture).convert('RGB');im.thumbnail((480,300))
            x=i%3*480;y=i//3*328
            board.paste(im,(x,y));draw.text((x+8,y+301),scene['name'],font=font,fill='#e8dbc0')
        board.save(OUT/f'{mode}-{page+1}.jpg',quality=94)
rows=[]
for scene in scenes:
    folder=ROOT/f'godot/assets/fairytales/{scene["id"]}'
    files=list((folder/'dressing').glob('*/prop.png'))
    rows.append({'scene':scene['id'],'props':len(files),'compressed_bytes':sum(p.stat().st_size for p in files),
                 'rgba_bytes':sum(Image.open(p).width*Image.open(p).height*4 for p in files)})
(OUT/'asset-budget.json').write_text(json.dumps(rows,indent=2)+'\n')
print('Review sheets created; PNG MB',round(sum(r['compressed_bytes'] for r in rows)/1024**2,2),
      'RGBA MB if all 18 sets loaded',round(sum(r['rgba_bytes'] for r in rows)/1024**2,2))
