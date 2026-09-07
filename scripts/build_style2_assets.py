"""Deterministic extraction only; all artwork comes from manifest image_gen outputs."""
from pathlib import Path
import json, shutil, subprocess, sys
from concurrent.futures import ThreadPoolExecutor
from PIL import Image
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
ARCHIVE = ROOT/'assets/generated/style2-production'
OUT = ROOT/'godot/assets/style2'
PROCESSOR = Path('C:/Users/admin/.codex/skills/generate2dsprite/scripts/generate2dsprite.py')

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    tasks=[]
    for job in json.loads((ARCHIVE/'manifest.json').read_text(encoding='utf-8'))['jobs']:
        name=job['id']; raw=ARCHIVE/(name+'.png')
        shutil.copy2(job['source'],raw)
        (ARCHIVE/(name+'.prompt.txt')).write_text(job['prompt'],encoding='utf-8')
        if name in ['medium','forest-reference']: continue
        if name in ['ground','cliff']:
            im=Image.open(raw).convert('RGBA'); im.resize((512,512),Image.Resampling.LANCZOS).save(OUT/(name+'.png')); continue
        if name in ['relics','undergrowth']:
            names=['watch','book','lantern','mask'] if name=='relics' else ['fern','rocks','reeds','shrub']
            im=Image.open(raw); w,h=im.size
            for i,n in enumerate(names):
                x=i%2*w//2; y=i//2*h//2
                cell=ARCHIVE/(n+'-cell.png'); im.crop((x+7,y+7,x+w//2-7,y+h//2-7)).save(cell)
                tasks.append((n,cell,ARCHIVE/(name+'.prompt.txt')))
        else: tasks.append(('medium' if name=='medium-clean' else name,raw,ARCHIVE/(name+'.prompt.txt')))
    def process(task):
        name,raw,prompt=task; folder=ARCHIVE/'processed'/name
        cmd=[sys.executable,str(PROCESSOR),'process','--input',str(raw),'--target','asset','--mode','single','--rows','1','--cols','1','--cell-size','768','--fit-scale','0.94','--align','bottom','--component-mode','all','--min-component-area','16','--output-dir',str(folder),'--prompt-file',str(prompt),'--label-prefix',name]
        subprocess.run(cmd,check=True,capture_output=True)
        image=Image.open(folder/(name+'-1.png')).convert('RGBA')
        pixels=np.array(image)
        rgb=pixels[:,:,:3].astype('int16')
        spill=(rgb[:,:,0]>rgb[:,:,1]+30)&(rgb[:,:,2]>rgb[:,:,1]+30)
        pixels[spill,3]=0
        pixels[pixels[:,:,3]==0,:3]=0
        image=Image.fromarray(pixels)
        bbox=image.getbbox()
        if not bbox: raise ValueError(name+' empty')
        image=image.crop(bbox)
        image.save(OUT/(name+'.png'))
        return {'id':name,'size':image.size,'alpha':image.getextrema()[3],'source':str(raw.relative_to(ROOT))}
    with ThreadPoolExecutor(max_workers=4) as pool: report=list(pool.map(process,tasks))
    (OUT/'qc.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    subprocess.run([sys.executable, str(ROOT/'scripts/style2_alpha_qc.py')], check=True)
    if (ARCHIVE/'compact-trees.json').exists():
        subprocess.run([sys.executable, str(ROOT/'scripts/build_compact_trees.py')], check=True)
    print('STYLE2_ASSETS',len(report),'transparent sprites + 2 materials')
if __name__=='__main__': main()
