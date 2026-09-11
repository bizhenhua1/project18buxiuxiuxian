"""Process generated artwork only; publish complete scene bundles atomically in catalog.
Raw prompts/images stay in art/fairytales/raw. No procedural visual substitutes.
"""
from pathlib import Path
import json, shutil
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT=Path(__file__).resolve().parents[1]
RAW=ROOT/'art/fairytales/raw'
OUT=ROOT/'godot/assets/fairytales'
MANIFEST=ROOT/'art/fairytales/manifest.json'

def cutout(image,cell=None):
    a=np.asarray(image.convert('RGBA')).copy()
    rgb=a[:,:,:3].astype(float)
    chroma=np.minimum(rgb[:,:,0],rgb[:,:,2])-rgb[:,:,1]
    key=(chroma>45)&(rgb[:,:,0]>95)&(rgb[:,:,2]>95)
    a[:,:,3]=np.where(key,0,a[:,:,3])
    # Suppress magenta fringe without removing dark ink or desaturated violet material.
    fringe=(chroma>15)&(chroma<=45)&(rgb[:,:,0]>95)&(rgb[:,:,2]>95)
    a[:,:,3]=np.where(fringe,a[:,:,3]*(45-chroma)/30,a[:,:,3]).clip(0,255)
    spill=(a[:,:,3]>0)&(chroma>15)
    a[:,:,0]=np.where(spill,np.minimum(rgb[:,:,0],rgb[:,:,1]+20),rgb[:,:,0])
    a[:,:,2]=np.where(spill,np.minimum(rgb[:,:,2],rgb[:,:,1]+20),rgb[:,:,2])
    labels,n=ndimage.label(a[:,:,3]>20)
    counts=np.bincount(labels.ravel());counts[0]=0
    keep=counts>=max(24,counts.max()*.0008)
    a[:,:,3]=np.where(keep[labels],a[:,:,3],0)
    if cell is not None:
        # Assign complete disconnected silhouettes to quadrants; do not slice a toe
        # merely because the generator placed it several pixels beyond a nominal grid.
        selected=np.zeros(n+1,dtype=bool)
        for label in np.flatnonzero(keep):
            yy,xx=np.where(labels==label)
            if len(xx) and int(xx.mean()>=image.width/2)+2*int(yy.mean()>=image.height/2)==cell:selected[label]=True
        a[:,:,3]=np.where(selected[labels],a[:,:,3],0)
    im=Image.fromarray(a);box=im.getchannel('A').getbbox()
    if not box:raise ValueError('Empty generated cutout')
    # Cell edges must be background, not a sliced limb or building.
    if box[0]<2 or box[1]<2 or box[2]>im.width-2 or box[3]>im.height-2:
        raise ValueError(f'Artwork touches cell edge: {box} / {im.size}')
    im=im.crop(box)
    return im

def save_sprite(im,path,limit=(900,1000)):
    im.thumbnail(limit,Image.Resampling.LANCZOS)
    result=Image.new('RGBA',(im.width+16,im.height+16));result.paste(im,(8,8));result.save(path)
    return {'file':path.name,'width':result.width,'height':result.height,'anchor':[.5,1-8/result.height]}

def build():
    manifest=json.loads(MANIFEST.read_text(encoding='utf-8'));published=[];report=[]
    for s in manifest['scenes']:
        key=s['id'];out=OUT/key;out.mkdir(parents=True,exist_ok=True)
        ready=True;marks={}
        for kind,count in [('structure',1),('props',4),('enemies',3)]:
            raw=RAW/f'{key}-{kind}.png'
            if not raw.exists():ready=False;continue
            image=Image.open(raw)
            try:
                for i in range(count):
                    crop=image
                    filename='structure.png' if count==1 else f'{"prop" if kind=="props" else "enemy"}-{i}.png'
                    marks[filename]=save_sprite(cutout(crop,None if count==1 else i),out/filename)
            except ValueError as e:
                report.append({'scene':key,'kind':kind,'error':str(e)});ready=False
        ready=ready and (out/'ground.png').exists() and (RAW/f'{key}-cliff.png').exists()
        if ready:
            cliff=RAW/f'{key}-cliff.png'
            shutil.copyfile(cliff,out/'cliff.png')
            (out/'anchors.json').write_text(json.dumps(marks,ensure_ascii=False,indent=2),encoding='utf-8')
            s['status']='assets_ready';published.append(s)
        else:s['status']='in_production'
    MANIFEST.write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    (ROOT/'godot/data/fairytale_scenes.json').write_text(json.dumps(published,ensure_ascii=False,indent=2),encoding='utf-8')
    (ROOT/'art/fairytales/asset-check.json').write_text(json.dumps({'ready':len(published),'total':18,'errors':report},ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({'ready':len(published),'total':18,'errors':report},ensure_ascii=False))

if __name__=='__main__':build()
