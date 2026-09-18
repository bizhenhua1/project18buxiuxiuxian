"""Export generated cutout with transparent gutters and measured ground anchor."""
import json
from pathlib import Path
from PIL import Image
root = Path(__file__).resolve().parents[1]
spec = {'version':1,'repeat_distance':[220,310], 'assets':[]}
for key,height in [('bed-alcove-v2',105),('work-cabinet-v2',82)]:
 source = root/f'art/fairytales/corridor/raw/snow_house-{key}.png'
 im = Image.open(source).convert('RGBA')
 alpha = im.getchannel('A')
 assert alpha.getextrema()[0] == 0, 'Generated asset must have real transparency'
 box = alpha.point(lambda x: 255 if x > 8 else 0).getbbox()
 im = im.crop(box)
 im.thumbnail((752,752),Image.Resampling.LANCZOS)
 out = Image.new('RGBA',(im.width+16,im.height+16))
 out.paste(im,(8,8))
 target = root/f'godot/assets/fairytales/snow_house/furnishings/{key}.png'
 target.parent.mkdir(parents=True,exist_ok=True)
 out.save(target)
 spec['assets'].append({'id':key,'file':f'furnishings/{key}.png',
  'height':height,'ground_anchor':[.5,(out.height-8)/out.height],
  'source':source.relative_to(root).as_posix(),
  'prompt':f'art/fairytales/corridor/raw/snow_house-{key}.prompt.txt'})
 print('FURNISHING_EXPORT',key,out.size,box)
(target.parent.parent/'furnishings.json').write_text(json.dumps(spec,ensure_ascii=False,indent=2),encoding='utf-8')
