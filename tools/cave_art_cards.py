"""Inspect real bitmap cards before production. Does not edit source images.

UV crops are ordinary renderable subrectangles; overlapping authored rock is
required at crop joins. They are not independent new artwork or new variants.
This fixture tests a straight segment, not an entire fork or accepted scene.
"""
import argparse,json,hashlib
from pathlib import Path
import numpy as np
from PIL import Image
from cave_algorithm_lab import ROOT,Recipe,reference_cast,rays,geology_noise

ART='godot/assets/biomes/crystal/arch-study/surround-a.png'
PARTS={'whole':[0,0,1,1],'left':[0,0,.46,1],'right':[.54,0,1,1],'crown':[.25,0,.80,.43]}

def crown_gap_budget(height,aspect,coherent_profile,source='crown-a'):
    """Conservative central crown cadence screen, NOT a whole-frame proof.
    A camera ray can climb dy*gap between two cards. The shortest opaque
    vertical run must exceed this plus placement/shape variation. Margins are
    declared candidate tolerances; source width and side joins need the full
    alpha-ray test as well. This is not a patch at a single failing pose.
    """
    image=np.asarray(Image.open(ROOT/f'godot/assets/biomes/crystal/cards-study/{source}.png'))
    mask=image[:,:,3]>=128;spans=[]
    for x in range(int(mask.shape[1]*.3),int(mask.shape[1]*.7),8):
        column=mask[:,x];edges=np.diff(np.r_[False,column,False].astype(int))
        starts=np.flatnonzero(edges==1);ends=np.flatnonzero(edges==-1)
        spans.append(max(ends-starts)/mask.shape[0])
    band=min(spans)*height*.97
    vertical_ray=.48/min(.86,aspect*.72)
    height_gradient=.34*2*1.875/7.3 if coherent_profile else 0.
    # +/- 8cm authored jitter, +/-3% image scale, 4cm overlap reserve.
    uncertainty=2*(.08+.03*height+.04)
    if band<=uncertainty:
        raise ValueError('Crown opaque band cannot absorb the declared variation; replace art or reduce variation, do not place infinitely dense cards.')
    gap=(band-uncertainty)/(vertical_ray+height_gradient)
    return dict(source=source,opaque_core_band_m=band,max_vertical_ray_slope=vertical_ray,
                max_macro_height_gradient=height_gradient,endpoint_uncertainty_m=uncertainty,
                max_gap_m=gap,scope='central source band only; still requires full-frame holdout')

def compile_cards(mode,step,seed=91):
    rng=np.random.default_rng(seed);im=Image.open(ROOT/ART)
    cards=[]
    roles=['whole'] if mode=='whole' else ['left','right','crown']
    for index,role in enumerate(roles):
        z=-2+index*step/len(roles)
        while z<82:
            # One unmodified source, one common scale; no horizontal stretch.
            height=4.2+rng.uniform(-.12,.12);width=height*im.width/im.height
            cards.append(dict(role=role,z=float(z),x=float(rng.uniform(-.08,.08)),y=-.03,
                              width=float(width),height=float(height),uv=PARTS[role],asset=ART))
            z+=step*rng.uniform(.84,1.16)
    return sorted(cards,key=lambda c:c['z'])

def authored_cards(step,seed=91,backing=False,outer_crown=False,coherent_profile=False,gap_budget=None,quiet_crown=False,formation_groups=False,end=82.):
    """Three separately authored silhouettes; no clipped joining edges.
    Dimensions are prototype choices, not approved production constants.
    Source alpha supplies measurable grounding, not a guessed image centre.
    """
    rng=np.random.default_rng(seed);cards=[]
    roles=[('left','shoulder-left-a',-2.3,3.6,1.0),('right','shoulder-right-a',2.3,3.6,1.07),('crown','crown-a',0,1.6875,.91)]
    if backing:
        roles.extend([('outer-left','backing-a',-3.7,4.7,1.0),('outer-right','backing-a',3.7,4.7,1.0)])
    if outer_crown:roles.append(('outer-crown','crown-a',0,2.25,1.0))
    for i,(role,name,x,h,pace) in enumerate(roles):
        if quiet_crown and 'crown' in role:
            name='crown-b'
        path=f'godot/assets/biomes/crystal/cards-study/{name}.png'
        image=Image.open(ROOT/path);mask=np.asarray(image)[:,:,3]>=128
        lowest=np.nonzero(mask)[0].max()+1
        z=-2+i*.37
        while z<end:
            # Distinctive inward projections belong to rock formations, not
            # every coverage slice. The quiet outer layer remains continuous.
            # This is stable world geology: nothing follows the camera.
            if formation_groups and role in ('left','right','crown'):
                phase={'left':0.,'right':3.7,'crown':1.9}[role]
                if float(geology_noise(z+phase,seed+31)) < -.08:
                    z+=step*rng.uniform(.84,1.16)
                    continue
            if len(cards)>=1200:
                raise ValueError('Research fixture exceeds its declared 1200-card guard; reject the recipe rather than allocate without bound.')
            height=h*rng.uniform(.97,1.03);width=height*image.width/image.height
            position_x=x
            y=(3.05 if role=='outer-crown' else 2.30)+rng.uniform(-.08,.08) if 'crown' in role else -(1-lowest/image.height)*height-.015
            if coherent_profile:
                # Macro shape changes over metres, separately from instance
                # clocks. They are fixed world geology, not per-frame noise.
                variation=float(geology_noise(z,seed+4));shift=.22*float(geology_noise(z+19,seed+9))
                widen=.36*variation
                if 'crown' in role:
                    y+=.34*float(geology_noise(z+5,seed+4))
                else:
                    position_x+=np.sign(x)*widen
                    factor=1+.11*float(geology_noise(z+5,seed+4))
                    height*=factor;width*=factor
                    y=-(1-lowest/image.height)*height-.015
                position_x+=shift
            if formation_groups and role in ('left','right','crown'):
                factor=rng.uniform(.88,1.10)
                height*=factor;width*=factor
                if role=='crown':
                    position_x+=rng.uniform(-.65,.65)
                    y+=rng.uniform(-.10,.28)
                else:
                    position_x+=np.sign(x)*rng.uniform(0,.32)
                    y=-(1-lowest/image.height)*height-.015
            cards.append(dict(role=role,z=float(z),x=float(position_x+rng.uniform(-.06,.06)),y=float(y),
                              width=float(width),height=float(height),uv=[0,0,1,1],asset=path))
            interval=step*pace*rng.uniform(.84,1.16)
            if formation_groups and role in ('left','right','crown'):
                interval=step*rng.uniform(1.3,2.3)
            if role=='outer-crown' and gap_budget is not None:
                interval=min(interval,gap_budget['max_gap_m']*rng.uniform(.84,1.0))
            z+=interval
    return sorted(cards,key=lambda c:c['z'])

def raycast(cards,pose,size,alphas,aspect=None,lens=1.,horizon=.48,portal=None,selected_branch=None,ray_slopes=None):
    dx,dy=rays(size,aspect=aspect,lens=lens,horizon=horizon) if ray_slopes is None else ray_slopes
    cx,eye,cz=pose
    distance=np.full(dx.shape,np.inf);owner=np.full(dx.shape,-1)
    down=dy<0;distance[down]=-eye/dy[down]
    for index,c in enumerate(cards):
        alpha=alphas[c['asset']]
        angle=float(c.get('yaw',0.));cos=np.cos(angle);sin=np.sin(angle)
        denominator=cos+dx*sin
        numerator=(c['z']-cz)*cos+(c['x']-cx)*sin
        d=np.divide(numerator,denominator,out=np.full_like(dx,np.inf),where=np.abs(denominator)>1e-8)
        u=((cx+dx*d-c['x'])*cos-(cz+d-c['z'])*sin)/c['width']+.5
        v=1-(eye+dy*d-c['y'])/c['height']
        crop=c['uv'];ok=(d>.05)&(d<distance)&(u>=crop[0])&(u<=crop[2])&(v>=crop[1])&(v<=crop[3])
        owner_branch=c.get('owner_branch')
        if portal is not None and owner_branch is not None:
            if cz>=portal['z']:
                if owner_branch!=selected_branch:continue
            else:
                gate_x=cx+dx*(portal['z']-cz)
                branches=portal.get('branches')
                if branches:
                    branch_index=branches.index(owner_branch)
                    lo=-np.inf if branch_index==0 else (branches[branch_index-1]+owner_branch)*portal['offset']*.5
                    hi=np.inf if branch_index==len(branches)-1 else (branches[branch_index+1]+owner_branch)*portal['offset']*.5
                    ok&=(gate_x>=lo)&(gate_x<hi)
                else:ok&=np.abs(gate_x-owner_branch*portal['offset'])<=portal['half_width']
        if not ok.any():continue
        px=np.clip((u*alpha.shape[1]).astype(int),0,alpha.shape[1]-1)
        py=np.clip((v*alpha.shape[0]).astype(int),0,alpha.shape[0]-1)
        hit=ok&(alpha[py,px]>=128)
        distance[hit]=d[hit];owner[hit]=index
    return distance,owner

def add_ground_transitions(cards,seed=117):
    """Decorative child of a grounded formation, never a new support wall.
    Cover placement is stable and derived from its parent's footprint. Keep
    source aspect; native terrain grounding uses measured alpha contacts.
    """
    path='godot/assets/biomes/crystal/cards-study/scree-a.png'
    image=Image.open(ROOT/path);mask=np.asarray(image)[:,:,3]>=128
    bottom=(np.nonzero(mask)[0].max()+1)/image.height
    rng=np.random.default_rng(seed);children=[];seen=set();occupied={}
    for card in cards:
        if card['role'] not in ('left','right','outer-left','outer-right','medial-rock'):continue
        footprint=(card['role'],round(card['x'],6),round(card['z'],6),round(card['width'],6))
        if footprint in seen:continue
        seen.add(footprint)
        if card['asset'] not in occupied:
            parent=np.asarray(Image.open(ROOT/card['asset']).convert('RGBA'))[:,:,3]>=128
            ys=np.nonzero(parent)[0]
            # Ground dressing belongs under the actual bearing band, not
            # under an upper overhang or the centre of a transparent canvas.
            band=int(ys.min()+.9*(ys.max()-ys.min()+1))
            xs=np.nonzero(parent[band:])[1]
            lo=xs.min()/parent.shape[1];hi=(xs.max()+1)/parent.shape[1]
            occupied[card['asset']]=(hi-lo,(lo+hi)*.5)
        span,center=occupied[card['asset']]
        width=card['width']*span*rng.uniform(.82,1.02)
        height=width*image.height/image.width
        along=(center-.5)*card['width'];yaw=card.get('yaw',0.)
        children.append(dict(role='ground-transition',asset=path,owner_branch=card.get('owner_branch'),
                             parent_role=card['role'],x=card['x']+along*np.cos(yaw),z=card['z']-along*np.sin(yaw)-.12,yaw=yaw,
                             y=-(1-bottom)*height-.015,width=width,height=height,uv=[0,0,1,1]))
    return sorted(cards+children,key=lambda c:c['z'])

def main():
    p=argparse.ArgumentParser();p.add_argument('--out',required=True)
    p.add_argument('--authored',action='store_true')
    p.add_argument('--backing',action='store_true')
    p.add_argument('--outer-crown',action='store_true')
    p.add_argument('--profile',action='store_true')
    p.add_argument('--aspect',type=float,default=1552/830)
    p.add_argument('--holdout',action='store_true')
    p.add_argument('--coverage-cadence',action='store_true')
    p.add_argument('--quiet-crown',action='store_true',help='Use independently authored low-contrast crown B; never modifies source pixels.')
    p.add_argument('--formation-groups',action='store_true',help='Sparse inward projections grouped by world geology, separate from dense quiet coverage.')
    p.add_argument('--ground-transitions',action='store_true')
    a=p.parse_args();out=ROOT/a.out;out.mkdir(parents=True,exist_ok=False)
    alpha=np.asarray(Image.open(ROOT/ART).convert('RGBA'))[:,:,3]
    source=dict(path=ART,sha256=hashlib.sha256((ROOT/ART).read_bytes()).hexdigest(),
                source_variants=1,role='candidate_surround_source',art_accepted=False)
    # A straight free-volume reference only supplies diagnostic regions.
    r=Recipe(radius=1.85,throat=1.85,height=3.7,relief=0,offset=0,forward_end=82.)
    cameras=[[0.,1.3,float(z)] for z in np.linspace(4,12,65)]
    if a.holdout:
        cameras=[[x,eye,float(z)] for x,eye in [(-.12,1.15),(.12,1.45),(0.,1.25)] for z in np.linspace(4.037,11.973,47)]
    refs=[reference_cast(r,pose,(128,80),aspect=a.aspect)[0] for pose in cameras]
    results=[]
    for mode in (['authored'] if a.authored else ['whole','segmented']):
        for step in ([1.2] if a.holdout else [.8,1.2,1.6] if a.authored else [1.2,1.8,2.4]):
            budget=crown_gap_budget(2.25,a.aspect,a.profile,'crown-b' if a.quiet_crown else 'crown-a') if a.coverage_cadence else None
            cards=authored_cards(step,backing=a.backing,outer_crown=a.outer_crown,coherent_profile=a.profile,gap_budget=budget,quiet_crown=a.quiet_crown,formation_groups=a.formation_groups) if a.authored else compile_cards(mode,step)
            if a.ground_transitions:cards=add_ground_transitions(cards)
            if len(cards)>1200:
                raise ValueError('Full assembly including ground transitions exceeds the 1200-card research guard.')
            alphas={path:np.asarray(Image.open(ROOT/path).convert('RGBA'))[:,:,3] for path in set(c['asset'] for c in cards)}
            rows=[]
            visibility={}
            for pose,ref in zip(cameras,refs):
                depth,owner=raycast(cards,pose,(128,80),alphas,a.aspect)
                structural=np.isfinite(ref)&(ref<55)
                missing=structural&~np.isfinite(depth)
                ids,pixels=np.unique(owner[owner>=0],return_counts=True)
                # Sensitivity report, not fabricated universal art thresholds.
                # Measures how many same-role pictures are simultaneously
                # readable at three possible area cutoffs. A later selected
                # threshold needs visual evidence at the real viewport.
                for fraction in [.001,.003,.01]:
                    by_role={}
                    for index,count in zip(ids,pixels):
                        if count/depth.size>=fraction:
                            role=cards[int(index)]['role'];by_role[role]=by_role.get(role,0)+1
                    peak=visibility.setdefault(str(fraction),{})
                    for role,count in by_role.items():peak[role]=max(peak.get(role,0),count)
                rows.append(dict(pose=pose,missing=int(missing.sum()),missing_grid_yx=np.argwhere(missing).tolist(),
                                 visible_cards=len(np.unique(owner[owner>=0]))))
            key=f'{mode}-{step}'
            spec=dict(status='real_2d_asset_fixture_not_accepted',scope='straight_8m_only',
                      source=source if not a.authored else dict(paths=list(alphas),unique_roles=len(set(c['role'] for c in cards)),source_variants_per_role=1,art_accepted=False),
                      fixture_parameters=dict(step=step,backing=a.backing,outer_crown=a.outer_crown,coherent_profile=a.profile,quiet_crown=a.quiet_crown,formation_groups=a.formation_groups,ground_transitions=a.ground_transitions,max_card_count=1200,source='authored_candidate_not_production_standard'),cards=cards,lens=1.,horizon=.48,
                      camera_aspect=a.aspect,reference_scope='straight cavity; no fork taper; coarse grid preserves actual viewport aspect',
                      coverage_cadence=budget,
                      shots=[dict(name=f'cards-{i}',pose=pose) for i,pose in enumerate(cameras[::8])])
            (out/(key+'.json')).write_text(json.dumps(spec,indent=2),encoding='utf-8')
            results.append(dict(mode=mode,step=step,instances=len(cards),triangles=2*len(cards),
                                worst_missing_pixels=max(row['missing'] for row in rows),
                                simultaneous_same_role_by_visible_frame_fraction=visibility,
                                diversity_note='Sensitivity only; not an approved asset count. Crops, mirrors, outer/inner placements of same source remain one similarity family.',rows=rows))
            print(key,results[-1]['worst_missing_pixels'],flush=True)
    (out/'results.json').write_text(json.dumps(dict(source=source if not a.authored else spec['source'],camera_aspect=a.aspect,results=results),indent=2),encoding='utf-8')

if __name__=='__main__':main()
