"""Deterministic extraction of generated art, with retained alpha and pixel QC."""
from pathlib import Path
import json, shutil, subprocess
from PIL import Image
import numpy as np
from scipy import ndimage
root=Path(__file__).resolve().parent
source=Path('C:/Users/admin/.codex/generated_images/01a07252-c2fb-7271-92fd-cbe98920f3a0')
files={'crystal':'1aaf481a-21ae-41c9-9d51-7e95a8ebd689','swamp':'24f6d18e-aa34-48a6-87c1-2dc947ab9bd9','sewer':'80ef9524-3731-4bed-a1f4-230e863b185a','whale':'d7cb2842-38a3-4b00-844a-0dc91a823266','shell':'9b236dd6-6547-4aeb-b11a-8e6422d94428','ground':'171b0b3d-ad23-48a9-83bd-e0dc19f76f16'}
qc=[]
for key,uid in files.items():
 raw=root/(key+'.png');shutil.copy2(source/('exec-'+uid+'.png'),raw)
 if key=='ground':continue
 clean=root/(key+'-alpha.png')
 subprocess.run(['F:/python/python.exe','C:/Users/admin/.codex/skills/.system/imagegen/scripts/remove_chroma_key.py','--input',str(raw),'--out',str(clean),'--key-color','#ff00ff','--soft-matte','--transparent-threshold','45','--opaque-threshold','170','--despill','--edge-contract','1','--force'],check=True,capture_output=True)
 im=Image.open(clean).convert('RGBA');cols,rows=(1,4) if key=='shell' else (3,3)
 for i in range(cols*rows):
  ypad=10 if key=='whale' and i>=6 else 0
  cell=im.crop((i%cols*im.width//cols,i//cols*im.height//rows-ypad,(i%cols+1)*im.width//cols,(i//cols+1)*im.height//rows))
  a=np.array(cell)
  if key=='crystal':a[:7,:,3]=0;a[-7:,:,3]=0;a[:,:7,3]=0;a[:,-7:,3]=0
  labels,n=ndimage.label(a[:,:,3]>32);counts=np.bincount(labels.ravel());keep=counts>30;keep[0]=False
  border=np.unique(np.concatenate([labels[0],labels[-1],labels[:,0],labels[:,-1]]));keep[border]=False
  a[:,:,3][~keep[labels]]=0
  # Suppress remaining key contamination only along transparency borders.
  edge=(a[:,:,3]>0)&(~ndimage.binary_erosion(a[:,:,3]>240,iterations=2))
  spill=edge&(a[:,:,0].astype(int)>a[:,:,1]+30)&(a[:,:,2].astype(int)>a[:,:,1]+30)
  a[spill,0]=np.minimum(a[spill,0],a[spill,1]+12);a[spill,2]=np.minimum(a[spill,2],a[spill,1]+18)
  cell=Image.fromarray(a);box=cell.getbbox();assert box
  # The generated shell sheet contains thin horizontal separators; omit only 3px cell gutters.
  touches=box[0]==0 or box[1]==0 or box[2]==cell.width or box[3]==cell.height
  target=root.parent/(list(files)[i] if key=='shell' else key);target.mkdir(exist_ok=True)
  out=cell.crop(box);out.thumbnail((1000,440) if key=='shell' else (384,384),Image.Resampling.LANCZOS)
  out.save(target/('shell.png' if key=='shell' else f'prop-{i}.png'))
  qc.append({'biome':target.name,'asset':'shell' if key=='shell' else f'prop-{i}','source_cell':i,'alpha_bounds':box,'edge_touch':touches,'size':out.size,'anchor':[.5,1]})
ground=Image.open(root/'ground.png')
for i,key in enumerate(['crystal','swamp','sewer','whale']):
 tile=ground.crop((i%2*ground.width//2,i//2*ground.height//2,(i%2+1)*ground.width//2,(i//2+1)*ground.height//2));tile.resize((512,512)).save(root.parent/key/'ground.png')
(root.parent/'asset-marks.json').write_text(json.dumps(qc,indent=2),encoding='utf8')
print('Extracted',len(qc),'assets; edge-touch:',[q for q in qc if q['edge_touch']])
