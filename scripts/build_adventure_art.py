"""Deterministic cleanup, packing and cutout QA; never generates artwork."""
from pathlib import Path
import hashlib, json
from collections import deque
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def largest_component(image):
    alpha=np.array(image)[:,:,3]>0; seen=np.zeros(alpha.shape,dtype=bool); best=[]
    for y,x in zip(*np.nonzero(alpha)):
        if seen[y,x]: continue
        queue=deque([(x,y)]); seen[y,x]=True; points=[]
        while queue:
            cx,cy=queue.popleft(); points.append((cx,cy))
            for nx,ny in [(cx-1,cy),(cx+1,cy),(cx,cy-1),(cx,cy+1)]:
                if 0<=nx<image.width and 0<=ny<image.height and alpha[ny,nx] and not seen[ny,nx]:
                    seen[ny,nx]=True;queue.append((nx,ny))
        if len(points)>len(best): best=points
    xs,ys=zip(*best)
    crop=image.crop((min(xs),min(ys),max(xs)+1,max(ys)+1))
    result=Image.new('RGBA',(crop.width+8,crop.height+8));result.alpha_composite(crop,(4,4))
    return result
def clean(image, edge_only=False):
    a = np.array(image.convert('RGBA')).astype(np.int16)
    r,g,b,alpha = [a[:,:,i] for i in range(4)]
    spill = np.minimum(r,b)-g
    mask = (alpha>0)&(spill>12)
    if edge_only:
        outside = Image.fromarray(np.uint8(alpha==0)*255).filter(ImageFilter.MaxFilter(7))
        mask &= np.array(outside)>0
    count = int(mask.sum())
    # Remove chroma contribution from antialiased ink edges; preserve alpha and warm difference.
    a[:,:,0][mask] -= spill[mask]
    a[:,:,2][mask] -= spill[mask]
    a[a[:,:,3]==0] = 0
    return Image.fromarray(np.uint8(np.clip(a,0,255))), count

def main():
    results=[]; thumbs=[]
    generated_path=ROOT/'godot/assets/generated-manifest.json'
    manifest=json.loads(generated_path.read_text('utf-8'))
    names=['corner','ring','seal','crest','endcap','pouch']
    for group, prefixes in [('adventure-ui',[(f'ui_parts-{i+1}',n) for i,n in enumerate(names)]),('impact-gold',[(f'impact-{i+1}',f'impact-{i}') for i in range(4)])]:
        source=ROOT/'assets/generated'/group
        out=ROOT/'godot/assets/ui/adventure' if group=='adventure-ui' else source/'reference-only'
        out.mkdir(parents=True,exist_ok=True)
        for prefix,name in prefixes:
            im, corrected=clean(Image.open(source/(prefix+'.png')))
            if group=='adventure-ui':
                bbox=im.getbbox(); im=im.crop((max(0,bbox[0]-4),max(0,bbox[1]-4),min(im.width,bbox[2]+4),min(im.height,bbox[3]+4)))
            processed=source/(name+'-final.png'); im.save(processed)
            destination=out/(name+'.png'); im.save(destination)
            arr=np.array(im).astype(int)
            pink=int(((arr[:,:,0]>arr[:,:,1]+20)&(arr[:,:,2]>arr[:,:,1]+20)&(arr[:,:,3]>0)).sum())
            border=int(np.count_nonzero(np.concatenate([arr[0,:,3],arr[-1,:,3],arr[:,0,3],arr[:,-1,3]])))
            assert pink==0 and border==0,(destination,pink,border)
            entry={'source':str(processed.relative_to(ROOT)).replace('\\','/'),'destination':str(destination.relative_to(ROOT)).replace('\\','/'),'sha256':digest(destination),'prompt':f'assets/generated/{group}/prompt-used.txt'}
            if group=='adventure-ui': manifest['files']=[e for e in manifest['files'] if e['destination']!=entry['destination']]+[entry]
            if group=='adventure-ui':
                results.append({'asset':name,'size':im.size,'pink_pixels':pink,'border_pixels':border,'despilled_pixels':corrected,'alpha_bbox':im.getbbox()})
                thumbs.append((name,im))
    stamp=largest_component(Image.open(ROOT/'assets/generated/impact-gold/impact-0-final.png').convert('RGBA'))
    source=ROOT/'assets/generated/impact-gold/spark-stamp.png';stamp.save(source)
    destination=ROOT/'godot/assets/fx/particles/spark.png';destination.parent.mkdir(parents=True,exist_ok=True);stamp.save(destination)
    arr=np.array(stamp).astype(int)
    pink=int(((arr[:,:,0]>arr[:,:,1]+20)&(arr[:,:,2]>arr[:,:,1]+20)&(arr[:,:,3]>0)).sum())
    border=int(np.count_nonzero(np.concatenate([arr[0,:,3],arr[-1,:,3],arr[:,0,3],arr[:,-1,3]])))
    assert pink==0 and border==0
    results.append({'asset':'spark-static','size':stamp.size,'pink_pixels':pink,'border_pixels':border,'alpha_bbox':stamp.getbbox()})
    thumbs.append(('spark-static',stamp))
    manifest['files']=[e for e in manifest['files'] if not e['destination'].startswith('godot/assets/fx/impact-gold/') and e['destination']!=destination.relative_to(ROOT).as_posix()]
    manifest['files'].append({'source':source.relative_to(ROOT).as_posix(),'destination':destination.relative_to(ROOT).as_posix(),'sha256':digest(destination),'prompt':'assets/generated/impact-gold/prompt-used.txt','runtime':'Single static particle stamp; no frame animation'})
    generated_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2),'utf-8')
    # Preserve all original reference bytes; only derivative cutouts are used in-game.
    cleaned=ROOT/'godot/assets/cleaned'; cleaned.mkdir(exist_ok=True)
    derivatives=[]
    for p in sorted((ROOT/'godot/assets/style-e').glob('*.png')):
        im,count=clean(Image.open(p),True)
        if count:
            dest=cleaned/p.name; im.save(dest)
            derivatives.append({'source':str(p.relative_to(ROOT)).replace('\\','/'),'destination':str(dest.relative_to(ROOT)).replace('\\','/'),'source_sha256':digest(p),'sha256':digest(dest),'despilled_pixels':count})
    (cleaned/'manifest.json').write_text(json.dumps(derivatives,indent=2),'utf-8')
    # Contact sheet on contrasting backgrounds for human review.
    sheet=Image.new('RGB',(1000,len(thumbs)*144),(24,29,25)); draw=ImageDraw.Draw(sheet)
    for row,(name,im) in enumerate(thumbs):
        draw.text((8,row*144+10),name,fill='#ead6a0')
        im.thumbnail((116,116),Image.Resampling.LANCZOS)
        for col,bg in enumerate(['#101915','#e9e6d8','#748592']):
            at=(180+col*250,row*144+8)
            tile=Image.new('RGBA',(230,128),bg); tile.alpha_composite(im,((230-im.width)//2,(128-im.height)//2))
            sheet.paste(tile.convert('RGB'),at)
    output=ROOT/'assets/generated/adventure-ui'
    sheet.save(output/'cutout-review.png')
    (output/'cutout-validation.json').write_text(json.dumps({'passed':True,'assets':results,'legacy_derivatives':len(derivatives)},indent=2),'utf-8')
    print(json.dumps({'passed':True,'parts':len(results),'legacy_derivatives':len(derivatives)}))
if __name__=='__main__': main()

