"""Measure conspicuous native diagnostic background; never art-approve.
Reads the actual 3D viewport rather than a resized UI screenshot. The terminal
opening and an enclosure hole are listed separately for human interpretation.
"""
import argparse,json
from pathlib import Path
import numpy as np
from PIL import Image
from scipy.ndimage import label,find_objects

def main():
    p=argparse.ArgumentParser();p.add_argument('--run',required=True);a=p.parse_args()
    folder=Path(a.run);rows=[]
    for path in sorted(folder.glob('*-viewport-diagnostic.png')):
        image=np.asarray(Image.open(path).convert('RGB'))
        mask=(image[:,:,0]>248)&(image[:,:,1]<8)&(image[:,:,2]>248)
        labels,count=label(mask);components=[]
        for index,bounds in enumerate(find_objects(labels),1):
            ys,xs=bounds;pixels=int((labels[bounds]==index).sum())
            components.append(dict(pixels=pixels,bbox=[xs.start,ys.start,xs.stop,ys.stop],
                touches_boundary=xs.start==0 or ys.start==0 or xs.stop==mask.shape[1] or ys.stop==mask.shape[0]))
        rows.append(dict(image=path.name,size=[image.shape[1],image.shape[0]],background_pixels=int(mask.sum()),
                         components=sorted(components,key=lambda x:-x['pixels'])))
    assert rows,'No unscaled diagnostic viewport images found'
    report=dict(status='native_background_measurement_not_art_acceptance',frames=len(rows),
        max_background_pixels=max(r['background_pixels'] for r in rows),
        boundary_components=sum(sum(c['touches_boundary'] for c in r['components']) for r in rows),rows=rows)
    (folder/'background-audit.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k!='rows'}))

if __name__=='__main__':main()
