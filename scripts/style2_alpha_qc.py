"""Despill existing generated sprites; render light/dark background QC, no art synthesis."""
from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np
from scipy.ndimage import distance_transform_edt, label
import json
root=Path(__file__).resolve().parents[1]
folder=root/'godot/assets/style2'
rows=[]
report=[]
for path in sorted(folder.glob('*.png')):
    if path.stem in ['cliff','ground']: continue
    im=Image.open(path).convert('RGBA'); a=np.array(im); c=a[:,:,:3].astype(float)
    # Palette deliberately contains no violet/magenta. Restrict soft despill to the matte edge.
    edge=distance_transform_edt(a[:,:,3]>0)<=3
    spill=np.minimum(c[:,:,0],c[:,:,2])-c[:,:,1]
    strong=(spill>30)
    a[strong,3]=0
    soft=(spill>5)&edge&(a[:,:,3]>0)
    if path.stem in ['short-grass','clover','stump','litter']:
        soft=(spill>3)&(a[:,:,3]>0) # These botanical palettes contain no violet, including interior gaps.
    if path.stem in ['tree-a','tree-b']:
        soft=(spill>0)&(a[:,:,3]>0)
    c[:,:,0][soft]-=spill[soft]; c[:,:,2][soft]-=spill[soft]
    a[:,:,:3]=np.clip(c,0,255).astype('uint8')
    a[a[:,:,3]==0,:3]=0
    # Remove isolated chroma debris, retain all real disconnected sprite parts.
    components,n=label(a[:,:,3]>0)
    counts=np.bincount(components.ravel()); small=counts<(max(5,int(counts[1:].max()*.005)) if path.stem=="fern" else 5); small[0]=False
    a[small[components],3]=0
    im=Image.fromarray(a); im.save(path)
    test=np.array(im).astype('int16')
    count=int(((np.minimum(test[:,:,0],test[:,:,2])-test[:,:,1]>30)&(test[:,:,3]>0)).sum())
    report.append({'file':path.name,'opaque_magenta_pixels':count,'transparent_pixels':int((a[:,:,3]==0).sum())})
    tile=Image.new('RGB',(600,340),'#202630'); d=ImageDraw.Draw(tile)
    d.rectangle((300,0,600,340),fill='#c7c9c9');d.text((8,8),path.stem,fill='white')
    thumb=im.copy();thumb.thumbnail((270,290))
    for x in [0,300]:tile.paste(thumb,(x+(300-thumb.width)//2,38),thumb)
    rows.append(tile)
sheet=Image.new('RGB',(1800,340*((len(rows)+2)//3)), '#202630')
for i,tile in enumerate(rows):sheet.paste(tile,((i%3)*600,(i//3)*340))
out=root/'assets/generated/style2-production'
sheet.save(out/'alpha-contact.png')
(out/'alpha-qc.json').write_text(json.dumps(report,indent=2))
assert all(x['opaque_magenta_pixels']==0 for x in report)
print('ALPHA_QC',len(report),'sprites: no opaque magenta; dual-background contact sheet saved')
