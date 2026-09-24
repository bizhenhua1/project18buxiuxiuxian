"""Ablate only continuous roof cadence; never claim thinning is a recipe.

Fixed views, source art and all other transforms make the native comparison
falsifiable. A source-image replacement must be a separate trial. The local
bridge and children of surviving parents remain intact.
"""
import argparse
import copy
import json
from pathlib import Path

import numpy as np
from PIL import Image

from compile_cave_formation_groups import parent_links


def compile_layout(source, stride, coverage_asset=None, coverage_scale=1.):
    if stride not in (2, 3):
        raise ValueError('Bounded experiment: only double/triple cadence')
    if not 1 <= coverage_scale <= 1.5 or (not coverage_asset and coverage_scale != 1):
        raise ValueError('Coverage scale is bounded to this local measured trial')
    cards = source['cards']
    links = parent_links(cards)
    candidates = sorted((i for i,c in enumerate(cards)
                         if c['role']=='outer-crown' and c.get('branch') == -1
                         and c['z'] >= 51 and not c.get('study_bridge_id')),
                        key=lambda i:cards[i]['z'])
    remove = {i for n,i in enumerate(candidates) if n % stride}
    remove.update(i for i,parent in links.items() if parent in remove)
    result = copy.deepcopy(source)
    result['cards'] = [c for i,c in enumerate(result['cards']) if i not in remove]
    if coverage_asset:
        image = Image.open(coverage_asset)
        mask = np.asarray(image.convert('RGBA'))[:,:,3] >= 128
        # Coverage art may intentionally reach the three continuation edges.
        # It must not be registered as a complete freestanding silhouette.
        if not mask[0].all() or mask[:, image.width//2].sum()/image.height < .60:
            raise ValueError('Coverage source lacks a solid upper band')
        v_new=(np.flatnonzero(mask[:,image.width//2])[-1]+1)/image.height
        for c in result['cards']:
            if c['role']!='outer-crown' or c.get('branch')!=-1 or c['z']<51 or c.get('study_bridge_id'):
                continue
            old=np.asarray(Image.open(c['asset']).convert('RGBA'))[:,:,3] >= 128
            v_old=(np.flatnonzero(old[:,old.shape[1]//2])[-1]+1)/old.shape[0]
            central_clearance=c['y']+(1-v_old)*c['height']
            c['width']*=coverage_scale
            c['height']=c['width']*image.height/image.width
            c['y']=central_clearance-(1-v_new)*c['height']
            c['asset']=str(coverage_asset).replace('\\','/')
            c['source_continuation_edges']=['top','left','right']
            c['study_coverage_role']='overhead_fill_not_freestanding_arch'
        result['source_images']=sorted({c['asset'] for c in result['cards']})
    result['roof_cadence_trial'] = dict(stride=stride, start_m=51, branch=-1,
        eligible=len(candidates), removed_including_children=len(remove),
        fixed=['camera','route','local bridge','roof centre clearance','source aspect'],
        coverage_asset=coverage_asset,
        coverage_scale=coverage_scale,
        status='requires_native_coverage_and_visual_comparison')
    return result


if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--spec',required=True)
    parser.add_argument('--out',required=True)
    parser.add_argument('--stride',required=True,type=int)
    parser.add_argument('--coverage-asset')
    parser.add_argument('--coverage-scale',type=float,default=1.)
    args=parser.parse_args()
    result=compile_layout(json.loads(Path(args.spec).read_text(encoding='utf-8')),args.stride,args.coverage_asset,args.coverage_scale)
    out=Path(args.out)
    out.mkdir(exist_ok=False,parents=True)
    (out/'fork.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps(result['roof_cadence_trial']))
