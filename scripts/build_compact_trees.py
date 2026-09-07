"""Deterministic extraction of regenerated front-elevation tree art."""
from pathlib import Path
from PIL import Image
import subprocess,sys,shutil,json
root=Path(__file__).resolve().parents[1]
archive=root/'assets/generated/style2-production'
source_root=Path('C:/Users/admin/.codex/generated_images/01a07252-c2fb-7271-92fd-cbe98920f3a0')
sources={'tree-a':'exec-c0beb55e-d1ad-4ef2-8e6a-1ab7c7578100.png','tree-b':'exec-65b862a4-7a8d-4ae7-ab76-eb01846d03fc.png'}
for name,source in sources.items():
    raw=archive/(name+'-compact.png')
    if not raw.exists():shutil.copy2(source_root/source,raw)
    out=root/'godot/assets/style2'/(name+'.png')
    backup=archive/(name+'-previous-runtime.png')
    if not backup.exists():shutil.copy2(out,backup)
    folder=archive/'processed'/(name+'-compact')
    subprocess.run([sys.executable,'C:/Users/admin/.codex/skills/generate2dsprite/scripts/generate2dsprite.py','process','--input',str(raw),'--target','asset','--mode','single','--rows','1','--cols','1','--cell-size','1024','--fit-scale','.94','--align','bottom','--component-mode','all','--min-component-area','16','--output-dir',str(folder),'--prompt-file',str(archive/(name+'-compact.prompt.txt')),'--label-prefix',name],check=True,capture_output=True)
    image=Image.open(folder/(name+'-1.png')).convert('RGBA')
    image.crop(image.getbbox()).save(out)
subprocess.run([sys.executable,str(root/'scripts/style2_alpha_qc.py')],check=True)
(archive/'compact-trees.json').write_text(json.dumps({'sources':sources,'runtime_names':list(sources),'projection':'upright billboard, compact horizontal contact edge; no baked ground plane','prompts':[n+'-compact.prompt.txt' for n in sources]},indent=2))
