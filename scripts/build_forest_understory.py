"""Extract generated compact props; deterministic alpha cleanup only."""
from pathlib import Path
import subprocess,sys,json,shutil
from PIL import Image
root=Path(__file__).resolve().parents[1]
archive=root/'assets/generated/style2-production'
source=Path('C:/Users/admin/.codex/generated_images/01a07252-c2fb-7271-92fd-cbe98920f3a0/exec-a1aa6320-144a-4674-b72c-0712ada0b0e1.png')
raw=archive/'understory-v2.png'
if not raw.exists(): shutil.copy2(source,raw)
im=Image.open(raw);w,h=im.size
names=['short-grass','clover','stump','litter']
for i,name in enumerate(names):
    cell=archive/(name+'-raw.png');x=i%2*w//2;y=i//2*h//2
    im.crop((x+5,y+5,x+w//2-5,y+h//2-5)).save(cell)
    folder=archive/'processed'/name
    subprocess.run([sys.executable,'C:/Users/admin/.codex/skills/generate2dsprite/scripts/generate2dsprite.py','process','--input',str(cell),'--target','asset','--mode','single','--rows','1','--cols','1','--cell-size','512','--fit-scale','.94','--align','bottom','--component-mode','all','--min-component-area','16','--output-dir',str(folder),'--prompt-file',str(archive/'understory-v2.prompt.txt'),'--label-prefix',name],check=True,capture_output=True)
    out=Image.open(folder/(name+'-1.png')).convert('RGBA');out=out.crop(out.getbbox());out.save(root/'godot/assets/style2'/(name+'.png'))
subprocess.run([sys.executable,str(root/'scripts/style2_alpha_qc.py')],check=True)
(archive/'understory-v2.json').write_text(json.dumps({'source':str(raw.relative_to(root)),'prompt':'understory-v2.prompt.txt','assets':names,'roles':{'short-grass':'trampled billboard','clover':'low groundcover billboard','stump':'understory landmark billboard','litter':'three-quarter grounded billboard'}},indent=2))
