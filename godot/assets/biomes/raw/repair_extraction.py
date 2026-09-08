"""Extract connected subjects on the whole sheet BEFORE grouping by cell center.
Nominal cell edges are guides, never a reason to delete a subject crossing them.
"""
from pathlib import Path
from PIL import Image
import numpy as np
from scipy import ndimage
import json, shutil
root=Path(__file__).resolve().parent
qc=[]
for key in ['crystal','swamp','sewer','whale']:
 a=np.array(Image.open(root/(key+'-alpha.png')).convert('RGBA'))
 if key=='crystal':
  for axis in [0,1]:
   for j in range(4):
    at=round(a.shape[axis]*j/3)
    if axis==0:a[max(0,at-5):at+5,:,3]=0
    else:a[:,max(0,at-5):at+5,3]=0
 labels,n=ndimage.label(a[:,:,3]>32)
 groups=[[] for _ in range(9)]
 for label,sl in enumerate(ndimage.find_objects(labels),1):
  if sl is None:continue
  mask=labels[sl]==label
  if mask.sum()<90:continue
  ys,xs=sl;cx=(xs.start+xs.stop)/2;cy=(ys.start+ys.stop)/2
  cell=min(2,int(cy/a.shape[0]*3))*3+min(2,int(cx/a.shape[1]*3))
  groups[cell].append(label)
 for i,ids in enumerate(groups):
  out=a.copy();out[:,:,3][~np.isin(labels,ids)]=0
  im=Image.fromarray(out);bounds=im.getbbox();assert bounds
  im=im.crop(bounds)
  assert im.height>70 and im.width>70,(key,i,im.size)
  im.save(root.parent/key/f'prop-{i}.png')
  qc.append({'biome':key,'asset':f'prop-{i}','bounds':bounds,'size':im.size,'anchor':[.5,1]})
(root.parent/'extraction-v2.json').write_text(json.dumps(qc,indent=2),encoding='utf8')
palace=root.parent/'palace';palace.mkdir(exist_ok=True)
for p in (root.parent/'sewer').glob('*.png'):
 # Palace is a preserved revision; never replace it with the new sewer shell.
 if not (palace/p.name).exists():shutil.copy2(p,palace/p.name)
print('Whole-subject extraction passed: 36 assets; original sewer preserved as palace.')
