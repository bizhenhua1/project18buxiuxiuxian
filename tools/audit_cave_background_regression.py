"""Reject newly exposed diagnostic background at unchanged real camera poses.

Reference holes (including unfinished terminal openings) are NOT approved.
This gate only proves that an edit adds no exposed background outside a
one-native-pixel tolerance around the reference's existing background.
"""
import argparse
import json
from pathlib import Path
import numpy as np
from PIL import Image
from scipy.ndimage import binary_dilation


def background(path):
    p=np.asarray(Image.open(path).convert('RGB'))
    return (p[:,:,0]>248)&(p[:,:,1]<8)&(p[:,:,2]>248)


def audit(folder,reference):
    current=json.loads((folder/'manifest.json').read_text(encoding='utf-8'))
    previous=json.loads((reference/'manifest.json').read_text(encoding='utf-8'))
    old={v['index']:v for v in previous['views']};rows=[]
    for view in current['views']:
        peer=old.get(view['index'])
        if not peer or view['phase']!=peer['phase']:raise ValueError('No matching reference phase')
        for key in ['camera_world_m','viewport','lens','horizon','heading']:
            if not np.allclose(view[key],peer[key],atol=1e-4,rtol=0):
                raise ValueError('Changed camera cannot be compared as a scenery-only regression: '+key)
        name=f'{view["index"]:02d}-viewport-diagnostic.png'
        now=background(folder/name);before=background(reference/name)
        fresh=now&~binary_dilation(before,iterations=1)
        rows.append(dict(image=name,new_background_pixels=int(fresh.sum()),
                         total_background_pixels=int(now.sum())))
    report=dict(status='rejected_new_background' if any(r['new_background_pixels'] for r in rows) else 'no_new_sampled_background_not_enclosure_approval',
                reference=str(reference),scope='identical camera/phase; existing reference holes remain unapproved',
                native_pixel_tolerance=1,max_new_background_pixels=max(r['new_background_pixels'] for r in rows),frames=rows)
    (folder/'background-regression.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k!='frames'}))
    return 2 if report['max_new_background_pixels'] else 0


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--run',required=True);p.add_argument('--against',required=True)
    a=p.parse_args();raise SystemExit(audit(Path(a.run),Path(a.against)))
