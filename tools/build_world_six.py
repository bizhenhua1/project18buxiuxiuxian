from PIL import Image
from pathlib import Path
import json
BASE=Path(__file__).resolve().parents[1]
raw=BASE/'art/world-six/raw';out=BASE/'godot/assets/world-six'
themes=['forest','crystal','swamp','sewer','whale','palace']
manifest={}
for i,theme in enumerate(themes):
 folder=out/theme;folder.mkdir(parents=True,exist_ok=True)
 for atlas,name in [('terrain','ground'),('cliff','cliff')]:
  image=Image.open(raw/(atlas+'.png')).convert('RGBA');w=image.width//3;h=image.height//2
  tile=image.crop(((i%3)*w,(i//3)*h,(i%3+1)*w,(i//3+1)*h))
  tile.save(folder/(name+'.png'))
 sheet=Image.open(raw/(theme+'_props.png')).convert('RGBA');w=sheet.width//2;h=sheet.height//2
 props=[]
 for p in range(4):
  tile=sheet.crop(((p%2)*w,(p//2)*h,(p%2+1)*w,(p//2+1)*h))
  box=tile.getchannel('A').getbbox()
  assert box,theme
  # Preserve a small transparent safety border; don't key away dark ink.
  tile=tile.crop(box);tile.thumbnail((512,640))
  padded=Image.new('RGBA',(tile.width+16,tile.height+16));padded.paste(tile,(8,8))
  padded.save(folder/('prop-%d.png'%p));props.append({'file':'prop-%d.png'%p,'width':padded.width,'height':padded.height})
 manifest[theme]={'ground':'ground.png','cliff':'cliff.png','props':props,'source':'image_gen; prompts in art/world-six/raw'}
(out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print('WORLD_SIX 12 surfaces and 24 transparent props')

tree=Image.open(raw/"forest_tree.png").convert("RGBA")
tree=tree.crop(tree.getchannel("A").getbbox());tree.thumbnail((640,1024));tree.save(out/"forest/tree.png")
