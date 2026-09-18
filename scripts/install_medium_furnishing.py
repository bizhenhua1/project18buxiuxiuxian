"""Export a generated cutout; update only its entry in the scene manifest."""
import argparse,json
from pathlib import Path
import numpy as np
from PIL import Image
p=argparse.ArgumentParser();p.add_argument('scene');p.add_argument('key');p.add_argument('height',type=float);a=p.parse_args()
root=Path(__file__).resolve().parents[1]
source=root/f'art/fairytales/corridor/raw/{a.scene}-{a.key}.png'
pixels=np.array(Image.open(source).convert('RGBA'))
rgb=pixels[:,:,:3].astype(float)
magenta=(np.minimum(rgb[:,:,0],rgb[:,:,2])-rgb[:,:,1]>55)&(rgb[:,:,0]>100)&(rgb[:,:,2]>100)
pixels[magenta]=0
im=Image.fromarray(pixels);assert im.getchannel('A').getextrema()[0]==0
box=im.getchannel('A').point(lambda x:255 if x>8 else 0).getbbox();im=im.crop(box)
im.thumbnail((752,752),Image.Resampling.LANCZOS)
out=Image.new('RGBA',(im.width+16,im.height+16));out.paste(im,(8,8))
folder=root/f'godot/assets/fairytales/{a.scene}';(folder/'furnishings').mkdir(exist_ok=True)
out.save(folder/f'furnishings/{a.key}.png')
manifest=folder/'furnishings.json'
data=json.loads(manifest.read_text(encoding='utf-8')) if manifest.exists() else {'version':1,'repeat_distance':[300,410],'assets':[]}
data['assets']=[x for x in data['assets'] if x['id']!=a.key]
data['assets'].append({'id':a.key,'file':f'furnishings/{a.key}.png','height':a.height,
 'ground_anchor':[.5,(out.height-8)/out.height],'source':source.relative_to(root).as_posix(),
 'prompt':f'art/fairytales/corridor/raw/{a.scene}-{a.key}.prompt.txt'})
manifest.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
print('MEDIUM_FURNISHING',a.scene,a.key,out.size)
