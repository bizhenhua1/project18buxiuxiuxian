"""Give 2D shoulders explicit cavity responsibility ahead of quiet fill.

Experimental left-branch continuation only. The body-height opaque contour,
not the rectangular image centre, determines the inward placement. Coverage
cards move outwards together with their attached foot dressing. New shoulders
use a separate, staggered depth sequence and remain rigid/source-proportional.
"""
import argparse
import copy
import hashlib
import json
from functools import lru_cache
from pathlib import Path

import numpy as np
from PIL import Image

from cave_algorithm_lab import geology_noise, smooth
from cave_art_cards import add_ground_transitions
from cave_card_junction import Junction
from compile_cave_formation_groups import parent_links

ROOT=Path(__file__).resolve().parents[1]


def qualified_source(path, role):
    """Do not let a same-sized PNG silently inherit another asset's contract."""
    file=Path(path).resolve()
    records=json.loads((ROOT/'godot/assets/biomes/crystal/cards-study/assets.json').read_text(encoding='utf-8'))
    matching=[r for r in records['assets'] if (ROOT/r['source']).resolve()==file]
    if len(matching)!=1 or matching[0]['role']!=role:
        raise ValueError('Source needs measured role '+role+': '+str(path))
    record=matching[0]
    if hashlib.sha256(file.read_bytes()).hexdigest()!=record['sha256']:
        raise ValueError('Source changed since contact/alpha inspection: '+str(path))
    if not record['ground_bearing_candidates_uv']:
        raise ValueError('Grounded source has no measured support: '+str(path))


@lru_cache(None)
def alpha(path):
    return np.asarray(Image.open(path).convert('RGBA'))[:,:,3]>=128


def anchored_shoulder(path, height, centre, z, side, clearance):
    mask=alpha(path)
    height=float(height);width=height*mask.shape[1]/mask.shape[0]
    occupied_rows=np.nonzero(mask)[0]
    bottom=(occupied_rows.max()+1)/mask.shape[0]
    y=-(1-bottom)*height-.015
    # Reserve all occupied pixels up to head height, not merely the lowest
    # root pixel. Otherwise a bulge halfway up can enter the walking corridor.
    row_y=y+(1-(np.arange(mask.shape[0])+.5)/mask.shape[0])*height
    body_band=mask[(row_y>=-.05)&(row_y<=2.0)]
    xs=np.nonzero(body_band)[1]
    inward=(xs.max()+1)/mask.shape[1] if side<0 else xs.min()/mask.shape[1]
    x=centre+side*clearance-(inward-.5)*width
    return dict(role='left' if side<0 else 'right',asset=path,
                branch=-1,owner_branch=-1,x=float(x),y=y,z=float(z),
                width=width,height=height,uv=[0,0,1,1],
                study_profile=dict(clear_body_height_m=2.,
                                   inward_opaque_body_limit_m=side*clearance))


def compile_layout(source, fill_setback=.8, cadence=3.1, left_asset=None,
                   covered_height=4.4, align_covered_roof=False, right_asset=None,
                   coverage_shoulders=False, paired_backfill=False, coverage_stride=1,
                   cover_roof_edges=False,
                   backfill_asset='godot/assets/biomes/crystal/cards-study/backing-quiet-c.png'):
    if not 0<=fill_setback<=1.2 or not 2.5<=cadence<=4.5:
        raise ValueError('Outside this bounded profile experiment')
    if not 4<=covered_height<=5.6:
        raise ValueError('Outside the tested continuation picture-height range')
    result=copy.deepcopy(source);cards=source['cards'];links=parent_links(cards)
    if coverage_shoulders and not (left_asset and right_asset and align_covered_roof):
        raise ValueError('Coverage shoulders need two authored corner sources and roof alignment')
    if paired_backfill and not coverage_shoulders:
        raise ValueError('Paired backfill belongs to the coverage-shoulder assembly')
    if cover_roof_edges and not paired_backfill:
        raise ValueError('Roof edge coverage requires the paired outer fill')
    if coverage_stride not in (1,2,3) or (coverage_stride!=1 and not coverage_shoulders):
        raise ValueError('Bounded whole-group cadence trial requires coverage shoulders')
    if left_asset:qualified_source(left_asset,'left_shoulder_continuation')
    if right_asset:qualified_source(right_asset,'right_shoulder_continuation')
    if paired_backfill:qualified_source(backfill_asset,'outer_side_backing')
    route=Junction(source['route']['exits']);vars(route).update(source['route'])
    remove={i for i,c in enumerate(cards) if c.get('branch')==-1 and c['z']>=51
            and (c['role'] in ('left','right','crown') or c.get('study_bridge_id'))}
    if coverage_shoulders:
        # Alternative assembly grammar, not an extra decoration layer. The
        # curved shoulders replace the vertical slabs that otherwise occupy
        # most of the image. Never keep both and count hidden art as diversity.
        remove.update(i for i,c in enumerate(cards) if c.get('branch')==-1
                      and c['z']>=51 and c['role'] in ('outer-left','outer-right'))
        roofs=sorted((i for i,c in enumerate(cards) if c.get('branch')==-1
                      and c['z']>=51 and c['role']=='outer-crown'),key=lambda i:cards[i]['z'])
        remove.update(i for n,i in enumerate(roofs) if n%coverage_stride)
    remove.update(i for i,parent in links.items() if parent in remove)
    changes={}
    for i,c in enumerate(cards):
        if i in remove or c.get('branch')!=-1 or c['z']<51:
            continue
        if c['role'] in ('outer-left','outer-right'):
            side=-1 if c['role']=='outer-left' else 1
            # Ease the transition over six world metres; do not create a
            # new step in the corridor at the experiment's first plane.
            changes[i]=side*fill_setback*float(smooth((c['z']-51)/6.))
    result['cards']=[]
    for i,c in enumerate(cards):
        if i in remove:continue
        q=copy.deepcopy(c)
        q['x']+=changes.get(i,changes.get(links.get(i),0))
        result['cards'].append(q)
    roof_z=sorted(c['z'] for c in result['cards'] if c['role']=='outer-crown' and c.get('branch')==-1)
    roofs_by_z={c['z']:c for c in result['cards'] if c['role']=='outer-crown' and c.get('branch')==-1}
    new=[];end=max(c['z'] for c in cards)
    for side in (-1,1):
        rng=np.random.default_rng(401 if side<0 else 821)
        z=51.2+(0 if side<0 else cadence*.43);index=0
        coverage_depths=[depth+.08 for depth in roof_z if depth>=51]
        if coverage_shoulders:z=coverage_depths[0]
        while z<end and (not coverage_shoulders or index<len(coverage_depths)):
            placed_z=z
            variant='a' if index%2==0 else 'b'
            role='left' if side<0 else 'right'
            path=f'godot/assets/biomes/crystal/cards-study/shoulder-{role}-{variant}.png'
            height=3.8+.24*float(geology_noise(z+side*7,311))
            continuation_asset=left_asset if side<0 else right_asset
            if continuation_asset:
                path=continuation_asset
                if align_covered_roof and not coverage_shoulders:
                    preceding=[depth for depth in roof_z if depth<z-.08]
                    if not preceding:raise ValueError('Missing foreground roof for covered shoulder')
                    placed_z=preceding[-1]+.08
                # A crop-through top continues behind the overhead layer;
                # its hidden picture height is NOT the visible cave height.
                height=covered_height+.24*float(geology_noise(placed_z+side*7,311))
            # Existing route half-width is 1.85m; a 15cm research reserve
            # separates scenery from it. This is not a universal map width.
            clearance=float(route.width(placed_z))+.15
            q=anchored_shoulder(path,height,float(route.center(placed_z,-1)),placed_z,side,clearance)
            q['study_profile']['sequence']=index
            if continuation_asset:q['source_continuation_edges']=['top']
            if coverage_shoulders:
                q['study_profile']['responsibility']='side enclosure and curved cavity, replaces slab backing'
            new.append(q)
            if paired_backfill:
                # Occlusion order is part of the group, not two unrelated
                # depth sequences. Put the quiet fill behind the shoulder,
                # overlapping its OUTER edge; it cannot erase the cavity edge.
                mask=alpha(path); xs=np.nonzero(mask)[1]
                outer_u=xs.min()/mask.shape[1] if side<0 else (xs.max()+1)/mask.shape[1]
                outer_x=q['x']+(outer_u-.5)*q['width']
                backing=backfill_asset
                centre=float(route.center(placed_z,-1))
                fill_height=height;fill_z=placed_z+.04
                fill_clearance=abs(outer_x-centre)-.4
                if cover_roof_edges:
                    roof=roofs_by_z[min(roof_z,key=lambda v:abs(v-(placed_z-.08)))]
                    fill_z=roof['z']-.04
                    # A source-independent structural constraint: the entire
                    # clipped vertical roof edge must sit behind opaque art.
                    # The 0.4m reserve is a bounded terrain trial, not a biome
                    # default; native support/ray audits still decide validity.
                    fill_height=max(height,roof['y']+roof['height']+.4)
                    fill_clearance=min(fill_clearance,side*(roof['x']+side*roof['width']/2-centre)-.35)
                fill=anchored_shoulder(backing,fill_height,centre,
                                       fill_z,side,fill_clearance)
                fill['role']='outer-left' if side<0 else 'outer-right'
                fill['study_profile']['responsibility']='cover cropped roof edge outside cavity' if cover_roof_edges else 'behind shoulder outer edge only, 0.4m joint overlap'
                new.append(fill)
            index+=1
            if coverage_shoulders:
                z=coverage_depths[index] if index<len(coverage_depths) else end
            else:z+=cadence*float(rng.uniform(.86,1.14))
    children=add_ground_transitions(new,seed=433)
    result['cards'].extend(children)
    result['cards'].sort(key=lambda c:c['z'])
    result['source_images']=sorted({c['asset'] for c in result['cards']})
    group_depths=sorted(set(c['z'] for c in new if c['role']=='left'))
    gaps=np.diff(group_depths)
    result['side_profile_trial']=dict(start_m=51,branch=-1,
        fill_setback_m=None if coverage_shoulders else fill_setback,
        side_cadence_m=None if coverage_shoulders else cadence,
        effective_left_depth_gaps_m=[float(gaps.min()),float(gaps.max())] if len(gaps) else [],
        left_asset=left_asset,
        right_asset=right_asset,
        covered_picture_height_m=covered_height,align_covered_roof=align_covered_roof,
        coverage_shoulders=coverage_shoulders,
        paired_backfill=paired_backfill,
        coverage_stride=coverage_stride,
        cover_roof_edges=cover_roof_edges,
        backfill_asset=backfill_asset if paired_backfill else None,
        reserve_body_height_m=2.,route_half_width_extra_m=.15,
        removed_with_children=len(remove),new_shoulders=sum(c['role'] in ('left','right') for c in new),
        new_backfill=sum(c['role'] in ('outer-left','outer-right') for c in new),
        new_members_and_foot_dressing=len(children),moved_fill_cards=len(changes),
        preserved=['formal route','camera','all source pixels','source proportions','retained roof transforms'],
        scope='only left continuation; art, coverage and native root check required')
    result.pop('bridge_trial',None)
    result['status']='side_profile_experiment_not_art_accepted'
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--spec',required=True)
    parser.add_argument('--out',required=True)
    parser.add_argument('--fill-setback',type=float,default=.8)
    parser.add_argument('--cadence',type=float,default=3.1)
    parser.add_argument('--left-asset')
    parser.add_argument('--right-asset')
    parser.add_argument('--covered-height',type=float,default=4.4)
    parser.add_argument('--align-covered-roof',action='store_true')
    parser.add_argument('--coverage-shoulders',action='store_true')
    parser.add_argument('--paired-backfill',action='store_true')
    parser.add_argument('--coverage-stride',type=int,default=1)
    parser.add_argument('--cover-roof-edges',action='store_true')
    parser.add_argument('--backfill-asset',default='godot/assets/biomes/crystal/cards-study/backing-quiet-c.png')
    args=parser.parse_args()
    result=compile_layout(json.loads(Path(args.spec).read_text(encoding='utf-8')),args.fill_setback,args.cadence,args.left_asset,args.covered_height,args.align_covered_roof,args.right_asset,args.coverage_shoulders,args.paired_backfill,args.coverage_stride,args.cover_roof_edges,args.backfill_asset)
    out=Path(args.out);out.mkdir(parents=True,exist_ok=False)
    (out/'fork.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps(result['side_profile_trial']))
