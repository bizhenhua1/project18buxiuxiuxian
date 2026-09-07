from pathlib import Path
from PIL import Image
import subprocess,sys,shutil,numpy as np,json
root=Path.cwd(); dest=root/'assets/generated/scene-battle';dest.mkdir(parents=True,exist_ok=True)
raw=dest/'rear-pack.png';shutil.copy2('C:/Users/admin/.codex/generated_images/01a07252-c2fb-7271-92fd-cbe98920f3a0/exec-6b9b6693-61ad-42a3-ac45-f1c6c737181e.png',raw)
im=Image.open(raw);w,h=im.size
boxes=[(0,0,w//2,680),(w//2,0,w,680),(0,680,w//2,h),(w//2,680,w,h)]
for name,box in zip(['agent-rear','medium-rear','watch-front','watch-reverse'],boxes):
 src=dest/(name+'-raw.png');im.crop(box).save(src)
 folder=dest/name
 subprocess.run([sys.executable,'C:/Users/admin/.codex/skills/generate2dsprite/scripts/generate2dsprite.py','process','--input',str(src),'--target','asset','--mode','single','--rows','1','--cols','1','--cell-size','768','--fit-scale','.94','--align','bottom','--component-mode','all','--min-component-area','16','--output-dir',str(folder),'--label-prefix',name],check=True,capture_output=True)
 out=Image.open(folder/(name+'-1.png')).convert('RGBA');a=np.array(out);rgb=a[:,:,:3].astype(np.int16);spill=np.minimum(rgb[:,:,0],rgb[:,:,2])-rgb[:,:,1]
 a[spill>30,3]=0
 for c in [0,2]:a[:,:,c]=np.clip(rgb[:,:,c]-np.maximum(spill,0),0,255)
 a[a[:,:,3]==0,:3]=0
 out=Image.fromarray(a);out=out.crop(out.getbbox());out.save(root/'godot/assets/style2'/(name+'.png'))
 print(name,out.size,'magenta opaque',int(((spill>30)&(a[:,:,3]>0)).sum()))
