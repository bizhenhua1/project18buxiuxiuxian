"""Compact fork study with real, unwarped 2D artwork.

Branches have a shared narrow approach, individual throats, and finite lateral
transitions back to parallel corridors. The outer silhouette follows the UNION
of openings; duplicating entire side-fill groups per branch would put a sibling
wall through the chosen route. No mesh shell or pixel editing is used here.
This compiler is a research fixture, not a production or art acceptance gate.
"""
import argparse, json
from pathlib import Path
import numpy as np
from PIL import Image
from cave_algorithm_lab import ROOT, smooth
from cave_art_cards import authored_cards, crown_gap_budget, add_ground_transitions, raycast

class Junction:
    def __init__(self, exits=2):
        self.exits=exits
        self.branches=[-1,1] if exits==2 else [-1,0,1]
        self.start=8.; self.mouth=14.; self.end=25.
        self.mouth_offset=1.25 if exits==2 else 1.85
        self.final_offset=3.8 if exits==2 else 4.4
        self.throat=.88 if exits==2 else .70
        self.continuation=None

    def center(self,z,b):
        value=b*self.offset(z)
        if self.continuation:
            c=self.continuation
            bump=c['offset']*(smooth((z-c['start'])/(c['peak']-c['start']))-smooth((z-c['peak'])/(c['end']-c['peak'])))
            value+=(b if b else 1)*bump
        return value

    def offset(self,z):
        return self.mouth_offset*smooth((z-self.start)/(self.mouth-self.start))+(
            self.final_offset-self.mouth_offset)*smooth((z-self.mouth)/(self.end-self.mouth))

    def width(self,z):
        return 1.85+(self.throat-1.85)*smooth((z-self.start)/(self.mouth-self.start))+(
            1.85-self.throat)*smooth((z-self.mouth)/(self.end-self.mouth))

    def centers(self,z):
        return [float(self.center(z,b)) for b in self.branches] if z>self.start else [0.]

    def pose(self,z,b):
        return [float(self.center(z,b)),1.3,float(z)]

    def intervals(self,z):
        """Merge overlapping passage intervals; keep only true rock gaps."""
        w=float(self.width(z));merged=[]
        for c in self.centers(z):
            if merged and c-w<=merged[-1][1]:merged[-1][1]=c+w
            else:merged.append([c-w,c+w])
        return merged

def compile_fork(route, seed=91, crossed_medial=False,portal_preview=False,source_variants=False,variant_report=None,hanging=False):
    aspect=1552/830
    budgets=[crown_gap_budget(2.25,aspect,True,s) for s in (['crown-b','crown-c'] if source_variants else ['crown-b'])]
    crown_budget=min(budgets,key=lambda b:b['max_gap_m'])
    source=authored_cards(1.2,seed=seed,backing=True,outer_crown=True,
        coherent_profile=True,gap_budget=crown_budget,
        quiet_crown=True,formation_groups=True)
    cards=[]
    # Keep the incoming world exactly as compiled. At the fork, move only
    # the two EXTERNAL banks. Never give every overlapping exit a full wall.
    for card in source:
        z=card['z']; role=card['role']
        if z<=route.start:
            cards.append(dict(card,branch=0));continue
        centers=route.centers(z);width=float(route.width(z))
        if portal_preview and z>route.mouth+.5:
            # Far continuation groups are logically independent. Their
            # overlapping outer fill is shown only through its own opening,
            # never across a sibling mouth. The selected continuation becomes
            # an ordinary corridor once the camera crosses that opening.
            for b,c in zip(route.branches,centers):
                value=dict(card,branch=b,owner_branch=b);value['x']+=c
                # Overhead pictures are shared enclosure, not competing
                # continuation contents. Clipping them into vertical strips
                # exposes a roof seam above the intervening rock nose.
                if 'crown' in role:value['owner_branch']=None
                if role in ('left','outer-left','right','outer-right'):
                    side=-1 if 'left' in role else 1
                    value['x']+=side*(width-1.85)
                cards.append(value)
            continue
        if role in ('left','outer-left','right','outer-right'):
            side=-1 if 'left' in role else 1
            center=centers[0] if side<0 else centers[-1]
            value=dict(card,branch=0)
            value['x']+=center+side*(width-1.85)
            cards.append(value)
            # Once passages are separated, their interior banks must use the
            # SAME ordinary corridor grammar. Never keep repeating a medial
            # pillar all the way to the vanishing point.
            if z>=route.end and route.exits==2:
                for b,c in zip(route.branches,centers):
                    if (side<0 and c==centers[0]) or (side>0 and c==centers[-1]):continue
                    inner=dict(card,branch=b)
                    inner['x']+=c+side*(width-1.85)
                    cards.append(inner)
        elif 'crown' in role:
            # Main crowns compress only by UNIFORM scale when approaching a
            # narrow throat; the higher quiet coverage remains full size.
            for b,c in zip(route.branches,centers):
                value=dict(card,branch=b);value['x']+=c
                if role=='crown':
                    factor=.72+.28*(width-route.throat)/(1.85-route.throat)
                    value['width']*=factor;value['height']*=factor
                cards.append(value)

    # The medial rocks are anchored to true gaps rather than to branch count.
    # Fit whole silhouettes inside the gap using one common scale. Small gaps
    # get small ground rock, not a squeezed, three-metre-high bitmap pillar.
    path='godot/assets/biomes/crystal/cards-study/medial-seam-a.png'
    im=Image.open(ROOT/path);mask=np.asarray(im)[:,:,3]>=128
    bottom=(np.nonzero(mask)[0].max()+1)/im.height
    occupied_width=(np.nonzero(mask)[1].max()-np.nonzero(mask)[1].min()+1)/im.width
    occupied_center=(np.nonzero(mask)[1].max()+np.nonzero(mask)[1].min()+1)/im.width*.5
    rng=np.random.default_rng(seed+17);z=route.start
    while z<(route.mouth+.55 if portal_preview else 82 if route.exits==3 else route.end+1):
        intervals=route.intervals(z)
        for left,right in zip(intervals,intervals[1:]):
            gap=right[0]-left[1]
            if gap<.20:continue
            # Fit the actual opaque silhouette, NOT the transparent canvas.
            # Keep both pixel aspect and the maximum physical height intact.
            width=min(gap*.91/occupied_width,3.9*im.width/im.height)
            h=width*im.height/im.width
            card=dict(role='medial-rock',branch=0,asset=path,x=(left[1]+right[0])/2-(occupied_center-.5)*width,
                z=float(z),y=-(1-bottom)*h-.02,width=width,height=h,uv=[0,0,1,1])
            if crossed_medial:
                # Two fixed intersecting picture planes give a local return
                # edge. This angle is a hypothesis, NOT an asset approval or
                # the user's illustrative 15-degree condition made global.
                angle=np.deg2rad(rng.uniform(23,33))
                cards.extend([dict(card,yaw=float(angle)),dict(card,yaw=float(-angle))])
            else:cards.append(card)
        z+=rng.uniform(.26,.38)
    if portal_preview:
        # The visual seam cover must lie ON the visibility partition plane.
        # A nose 30cm behind it drifts away in projection during lateral travel.
        for a,b in zip(route.branches,route.branches[1:]):
            h=4.2;w=h*im.width/im.height
            cards.append(dict(role='medial-rock',branch=0,asset=path,
                x=(a+b)*route.mouth_offset*.5-(occupied_center-.5)*w,
                z=route.mouth,y=-(1-bottom)*h-.02,width=w,height=h,uv=[0,0,1,1]))
    # Shared roof pictures from adjacent continuations overlap on screen.
    # Do not leave copies exactly coplanar: changing batch membership can
    # otherwise change depth-tie winners even when removed art is invisible.
    # World-fixed centimetre offsets preserve source proportions and do not
    # follow the camera. Gate seam noses remain exactly on the gate plane.
    for card in cards:
        if 'crown' in card['role'] and card['z']>route.start:
            card['z']+=.045*card.get('branch',0)
    if source_variants:
        allocation=apply_source_variants(cards,seed,route,portal_preview)
        if variant_report is not None:variant_report.update(allocation)
    cards=add_ground_transitions(cards)
    if hanging:
        from cave_card_dressing import add_hanging
        cards=add_hanging(cards,route,seed)
    if len(cards)>3000:raise ValueError('Fork research guard exceeded; reject recipe.')
    return sorted(cards,key=lambda c:c['z'])

def apply_source_variants(cards,seed,route,portal_preview):
    """World-identity selection, independent of draw order and camera motion.

    Separate continuation branches can have distinct geology. Sources retain
    their own aspect and measured grounding; counts alone never art-approve.
    Current variants are deliberately a bounded two-source trial per role.
    """
    pools={'left':['shoulder-left-a','shoulder-left-b'],
           'right':['shoulder-right-a','shoulder-right-b'],
           'outer-left':['backing-a','backing-b'],'outer-right':['backing-a','backing-b'],
           'crown':['crown-b','crown-c'],'outer-crown':['crown-b','crown-c']}
    from cave_card_variants import allocate
    portal=dict(z=route.mouth,offset=route.mouth_offset,branches=route.branches) if portal_preview else None
    choices,report=allocate(cards,camera_suite(route),portal,pools,seed)
    sources={}
    for name in {n for pool in pools.values() for n in pool}:
        path=f'godot/assets/biomes/crystal/cards-study/{name}.png'
        im=Image.open(ROOT/path);mask=np.asarray(im)[:,:,3]>=128
        sources[name]=(path,im.width/im.height,(np.nonzero(mask)[0].max()+1)/im.height)
    for i,c in enumerate(cards):
        if c['role'] not in pools:continue
        name=choices[i]
        path,aspect,bottom=sources[name]
        c['asset']=path;c['width']=c['height']*aspect
        if 'crown' not in c['role']:c['y']=-(1-bottom)*c['height']-.015
    return report

def camera_suite(route):
    shots=[]
    for z in (5.,6.5,8.):
        shots.append(dict(name=f'approach-{z:g}',pose=[0.,1.3,z],scope='unselected_preview'))
    for b in route.branches:
        for i,z in enumerate(np.linspace(8,32,13)):
            shots.append(dict(name=f'branch-{b}-{i:02d}',pose=route.pose(z,b),branch=b,scope='selected_camera_rail'))
        for i,z in enumerate([12.75,13.,13.25,13.5,13.75,13.999,14.,14.001,14.25]):
            pose=route.pose(z,b);pose[1]=1.78
            shots.append(dict(name=f'crossing-{b}-{i:02d}',pose=pose,branch=b,lens=.9545,horizon=.37194,
                              scope='raised_camera_and_gate_crossing'))
    return shots

def retirement_safe(portal,pose,branch,aspect=1552/830,lens=1.):
    """All horizontal screen rays already lie in the selected gate cell.
    Valid for the declared fixed heading only; no approximate visibility timer.
    Shared enclosure is retained, only unselected continuation content retires.
    """
    if not portal or branch not in portal['branches']:return False
    x,_,z=pose
    if z>=portal['z']:return True
    branches=portal['branches'];i=branches.index(branch)
    lo=-np.inf if i==0 else (branches[i-1]+branch)*portal['offset']*.5
    hi=np.inf if i==len(branches)-1 else (branches[i+1]+branch)*portal['offset']*.5
    spread=aspect/(2*min(.86,.72*aspect)*lens)*(portal['z']-z)
    return x-spread>lo+.005 and x+spread<hi-.005

def exposed_partition_seams(cards,pose,alphas,portal,branch,lens,horizon):
    """A partition is legal only while shared real artwork hides its cut.
    Inspect the exact moving screen seam plus a two-native-pixel margin.
    This detects a hard splice even when there are zero background pixels.
    """
    if not portal or pose[2]>=portal['z']:return 0
    aspect=1552/830;focal=min(.86,aspect*.72)*lens
    dy=(horizon-(np.arange(128)+.5)/128)/focal
    result=0
    for a,b in zip(portal['branches'],portal['branches'][1:]):
        x=(a+b)*portal['offset']*.5
        slope=(x-pose[0])/(portal['z']-pose[2])
        slopes=slope+np.array([-2.,0.,2.])*aspect/(1552*focal)
        slopes=slopes[np.abs(slopes)<=aspect/(2*focal)]
        if not len(slopes):continue
        dx=np.broadcast_to(slopes,(128,len(slopes)))
        ys=np.broadcast_to(dy[:,None],dx.shape)
        depth,owner=raycast(cards,pose,(len(slopes),128),alphas,aspect,lens,horizon,
                            portal,branch,ray_slopes=(dx,ys))
        bad=~np.isfinite(depth)
        for i in np.unique(owner[owner>=0]):
            if cards[int(i)].get('owner_branch') is not None:bad|=owner==i
        result+=int(bad.sum())
    return result

def screen(cards, route, shots, size=(128,80),portal=None):
    """Report whole viewport background and central locomotion obstructions.

    No arbitrary ellipse reference is used as an art pass. A missing background
    pixel and a close foreground wall are different problems and are preserved.
    Ground level body clearance is checked separately against actual alpha.
    """
    alphas={p:np.asarray(Image.open(ROOT/p).convert('RGBA'))[:,:,3] for p in {c['asset'] for c in cards}}
    rows=[]
    for shot in shots:
        lens=shot.get('lens',1.);horizon=shot.get('horizon',.48)
        depth,owner=raycast(cards,shot['pose'],size,alphas,1552/830,lens,horizon,portal,shot.get('branch'))
        missing=~np.isfinite(depth)
        edge=np.zeros_like(missing);edge[:2]=True;edge[:,:2]=True;edge[:,-2:]=True
        visible=np.unique(owner[owner>=0])
        retirement=None
        if retirement_safe(portal,shot['pose'],shot.get('branch'),lens=lens):
            kept=[i for i,c in enumerate(cards) if c.get('owner_branch') in (None,shot['branch'])]
            short=[cards[i] for i in kept]
            reduced,which=raycast(short,shot['pose'],size,alphas,1552/830,lens,horizon,portal,shot['branch'])
            owners=np.full_like(which,-1);hit=which>=0;owners[hit]=np.asarray(kept)[which[hit]]
            retirement=dict(removed=len(cards)-len(short),owner_changes=int((owners!=owner).sum()),
                depth_changes=int((~np.isclose(reduced,depth,atol=1e-6)).sum()))
        rows.append(dict(name=shot['name'],pose=shot['pose'],background_pixels=int(missing.sum()),
            border_background_pixels=int((edge&missing).sum()),visible_cards=len(visible),retirement=retirement,
            exposed_partition_seam_samples=exposed_partition_seams(cards,shot['pose'],alphas,portal,shot.get('branch'),lens,horizon)))
    collisions=[]
    # The occupied actor/camera rail is a 0.5m-wide standing envelope. This is
    # a fixture contract, not a proposed corridor width or an art acceptance.
    for b in route.branches:
        for c in cards:
            if portal is not None and c.get('owner_branch') not in (None,b):continue
            z=c['z']
            if not 7<z<34:continue
            center=float(route.center(z,b))
            alpha=alphas[c['asset']]
            for dx in (-.25,0.,.25):
                # Solve the curve/rotated-plane intersection. The local
                # contraction is checked explicitly, never assume c.z is
                # also the actor intersection after a card is rotated.
                angle=c.get('yaw',0.)
                crossing=z
                for _ in range(30):
                    x=float(route.center(crossing,b))+dx
                    crossing=c['z']-(x-c['x'])*np.tan(angle)
                center=float(route.center(crossing,b))
                residual=abs(crossing-(c['z']-(center+dx-c['x'])*np.tan(angle)))
                if residual>1e-6:raise ValueError('Curve/card intersection did not converge; fixture cannot be certified.')
                for y in (.3,.8,1.3,1.75):
                    u=((center+dx-c['x'])*np.cos(angle)-(crossing-c['z'])*np.sin(angle))/c['width']+.5
                    v=1-(y-c['y'])/c['height']
                    if 0<=u<1 and 0<=v<1 and alpha[int(v*alpha.shape[0]),int(u*alpha.shape[1])]>=128:
                        collisions.append(dict(branch=b,role=c['role'],z=z,world_point=[center+dx,y,crossing]))
    return dict(status='measured_not_art_accepted',frames=rows,body_intersections=collisions,
                max_border_background_pixels=max(r['border_background_pixels'] for r in rows))

def main():
    p=argparse.ArgumentParser();p.add_argument('--out',required=True)
    p.add_argument('--spec',help='Audit an existing compiler output without silently changing its geometry.')
    p.add_argument('--exits',type=int,choices=[2,3],default=2)
    p.add_argument('--crossed-medial',action='store_true')
    p.add_argument('--portal-preview',action='store_true')
    p.add_argument('--source-variants',action='store_true',help='Bounded independently authored 2D source library trial')
    p.add_argument('--hanging',action='store_true',help='Sparse ceiling attachments; never gap fillers')
    a=p.parse_args();out=ROOT/a.out;out.mkdir(parents=True,exist_ok=False)
    if a.spec:
        spec=json.loads((ROOT/a.spec).read_text(encoding='utf-8'))
        route=Junction(int(spec['route']['exits']));vars(route).update(spec['route'])
        cards=spec['cards'];shots=spec['shots'];portal=spec.get('portal')
    else:
        variation={}
        route=Junction(a.exits);cards=compile_fork(route,crossed_medial=a.crossed_medial,portal_preview=a.portal_preview,source_variants=a.source_variants,variant_report=variation,hanging=a.hanging);shots=camera_suite(route)
        portal=dict(z=route.mouth,offset=route.mouth_offset,half_width=route.throat,branches=route.branches,
            mode='nearest_opening_partition_hidden_by_shared_rims') if a.portal_preview else None
        spec=dict(status='2d_fork_research_not_accepted',cards=cards,shots=shots,
            camera_aspect=1552/830,lens=1.,horizon=.48,route=vars(route),
            exclusions=['no production integration','no runtime memory retirement yet','no event or combat gate'],
            structural_meshes=0,portal=portal,crossed_medial=a.crossed_medial,source_variants=a.source_variants,hanging=a.hanging,variant_allocation=variation,source_images=sorted({c['asset'] for c in cards}))
    (out/'fork.json').write_text(json.dumps(spec,indent=2),encoding='utf-8')
    audit=screen(cards,route,shots,portal=portal)
    reasons=[]
    if audit['max_border_background_pixels']:reasons.append('viewport border exposes background')
    if audit['body_intersections']:reasons.append('authored rock intersects sampled standing envelope')
    if any(f['exposed_partition_seam_samples'] for f in audit['frames']):reasons.append('preview partition splice is visible')
    if any(f['retirement'] and (f['retirement']['owner_changes'] or f['retirement']['depth_changes']) for f in audit['frames']):
        reasons.append('retirement changes a visible first hit')
    audit['rejection_reasons']=reasons
    audit['status']='rejected_geometry_fixture' if reasons else 'geometry_fixture_ready_for_visual_probe_not_art_accepted'
    (out/'screen.json').write_text(json.dumps(audit,indent=2),encoding='utf-8')
    print(json.dumps(dict(instances=len(cards),sources=len(spec['source_images']),
        border_background=audit['max_border_background_pixels'],body_intersections=len(audit['body_intersections']),
        rejection_reasons=reasons,art_accepted=False)))
    if reasons:raise SystemExit(2)

if __name__=='__main__':main()
