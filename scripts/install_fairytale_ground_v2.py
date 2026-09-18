"""Install generated floor revisions at the existing texture budget, keeping originals."""
from pathlib import Path
from PIL import Image
import shutil
ROOT=Path(__file__).resolve().parents[1]
for key in ['red_cottage','cinder_clock']:
    folder=ROOT/'art/fairytales/corridor/raw'
    target=ROOT/f'godot/assets/fairytales/{key}/ground.png'
    backup=folder/f'{key}-ground-before-v2.png'
    if not backup.exists():shutil.copy2(target,backup)
    image=Image.open(folder/f'{key}-ground-v2.png').convert('RGB')
    image.resize((512,512),Image.Resampling.LANCZOS).save(target)
    print(key,'installed 512x512; original retained')
