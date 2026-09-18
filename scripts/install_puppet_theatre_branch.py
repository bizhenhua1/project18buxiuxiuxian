import json
from pathlib import Path
import numpy as np
from PIL import Image
root=Path(__file__).resolve().parents[1]
source=root/'art/fairytales/corridor/raw/puppet_theatre-curtain-pier-v3-key.png'
rgba=np.array(Image.open(source).convert('RGBA'))
rgb=rgba[:,:,:3].astype(float)
excess=np.minimum(rgb[:,:,0],rgb[:,:,2])-rgb[:,:,1]
key=(excess>55)&(rgb[:,:,0]>100)&(rgb[:,:,2]>100)
rgba[key]=0
# Despill the thin antialiased transition, not the brown object texture.
edge=(excess>12)&~key
rgba[:,:,2][edge]=np.minimum(rgba[:,:,2][edge],rgba[:,:,1][edge]+8)
im=Image.fromarray(rgba);box=im.getchannel('A').getbbox();im=im.crop(box)
im.thumbnail((720,1000),Image.Resampling.LANCZOS)
out=Image.new('RGBA',(im.width+16,im.height+16));out.paste(im,(8,8))
dest=root/'godot/assets/fairytales/puppet_theatre/branch-side.png';out.save(dest)
data={'file':'branch-side.png','role':'side','ground_anchor':[.5,(out.height-8)/out.height],
 'suggested_canvas_height':220,'junction_side_radius':700,'image_size':list(out.size),
 'source':source.relative_to(root).as_posix(),'edge_touch':False}
(dest.parent/'branch-side.json').write_text(json.dumps(data,indent=2),encoding='utf-8')
print('BRANCH_SIDE_EXPORTED',out.size)

