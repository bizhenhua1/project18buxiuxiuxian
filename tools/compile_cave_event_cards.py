"""Reserve an event's presentation rays in a fixed 2D-card corridor.

Research compiler: a captured production formation supplies the envelope.
We translate complete authored pictures, never stretch them, delete a wall,
move the battle camera, or add a mesh shell. The resulting recipe MUST pass
fresh movement, alpha coverage and event checks; fitting alone is not approval.
"""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image
from audit_cave_event_visibility import ROOT, body_rays, load_cards
from cave_art_cards import add_ground_transitions
from cave_card_dressing import add_hanging
from cave_card_junction import Junction


def profile(z, requirements, gradient):
    # Compact C2 lobes spread each required movement over neighbouring art.
    # Max keeps every measured clearance; sampling is offline, world-fixed.
    # 1.875 is the maximum derivative of quintic smoothstep, NOT an angle cap.
    result = 0.0
    for at, amount in requirements:
        reach = max(2.0, amount*1.875/gradient)
        t = min(1.0, abs(z-at)/reach)
        q = t*t*t*(10+t*(-15+6*t))
        result = max(result, amount*(1-q))
    return result


def compile_layout(spec, capture, folder):
    route = Junction(spec['route']['exits']);vars(route).update(spec['route'])
    measured, alphas = load_cards(capture)
    if len(measured) != len(spec['cards']):raise ValueError('Capture/spec instance mismatch')
    for c, r in zip(spec['cards'], measured):
        if c['role']!=r['role'] or any(abs(c[k]-r[k])>1e-5 for k in ('x','z','width','height')):
            raise ValueError('Capture must belong to this exact unmodified layout')
    chosen = capture['branch'];bundles=[]
    for frame in capture['event_frames']:
        if not frame['formation_ready']:raise ValueError('Formation was not settled')
        for body in frame['bodies']:
            if body['hidden']:continue
            mask = np.asarray(Image.open(folder/body['mask']).convert('RGBA'))[:, :, 3]
            if not (mask >= 128).any():mask=np.full((2,2),255,dtype=np.uint8)
            dx,dy,opaque,depth=body_rays(body,frame['camera_m'],mask)
            bundles.append((np.array(frame['camera_m']),dx[opaque],dy[opaque],depth))
    if not bundles:raise ValueError('Missing event silhouettes')
    needs={'left':[], 'right':[], 'crown':[]}
    margin=.08 # This capture's static-terrain tolerance; fresh grounding recheck required.
    for original,c in zip(spec['cards'], measured):
        role=c['role']
        family='crown' if 'crown' in role else 'left' if 'left' in role else 'right' if 'right' in role else None
        if family is None and role=='ground-transition':
            pr=original.get('parent_role','');family='left' if 'left' in pr else 'right' if 'right' in pr else None
        if family is None or (original.get('branch',original.get('owner_branch')) != chosen):continue
        if abs(c['yaw'])>1e-6:raise ValueError('This compiler handles frontal authored cards only')
        amount=0.;mask=alphas[c['asset']]>=128
        h,w=mask.shape
        for camera,dx,dy,depth in bundles:
            distance=c['z']-camera[2]
            if distance<=.05 or distance>=depth-.025:continue
            x=camera[0]+dx*distance;y=camera[1]+dy*distance
            if family=='crown':
                u=(x-c['x'])/c['width']+.5
                valid=(u>=0)&(u<1)
                for column in np.unique((u[valid]*w).astype(int)):
                    rows=np.flatnonzero(mask[:,column])
                    if not rows.size:continue
                    lower=c['y']+(1-(rows[-1]+1)/h)*c['height']
                    point_y=y[valid][(u[valid]*w).astype(int)==column]
                    amount=max(amount,float(point_y.max()-lower+margin))
            else:
                v=1-(y-c['y'])/c['height'];valid=(v>=0)&(v<1)
                for row in np.unique((v[valid]*h).astype(int)):
                    columns=np.flatnonzero(mask[row])
                    if not columns.size:continue
                    point_x=x[valid][(v[valid]*h).astype(int)==row]
                    if family=='left':
                        edge=c['x']+((columns[-1]+1)/w-.5)*c['width']
                        amount=max(amount,float(edge-point_x.min()+margin))
                    else:
                        edge=c['x']+(columns[0]/w-.5)*c['width']
                        amount=max(amount,float(point_x.max()-edge+margin))
        if amount>0:needs[family].append((c['z'],amount))
    gradients={'left':.4,'right':.4,'crown':.2}
    # Fork grammar is a separate contract. Reject an event that needs its room
    # to start inside the fork instead of silently inflating the fork plaza.
    if any(profile(route.end,needs[k],gradients[k])>.001 for k in needs):
        raise ValueError('Event reserve overlaps fork alignment; schedule it farther on')
    cards=[]
    for c in spec['cards']:
        if c['role']=='ground-transition' or c.get('support_kind')=='ceiling_attachment':continue
        value=dict(c);z=c['z'];role=c['role']
        if role in ('left','outer-left'):value['x']-=profile(z,needs['left'],.4)
        elif role in ('right','outer-right'):value['x']+=profile(z,needs['right'],.4)
        elif 'crown' in role:value['y']+=profile(z,needs['crown'],.2)
        cards.append(value)
        if role=='outer-crown':
            # Widened banks also need wider OVERHEAD overlap. Keep the central
            # arch silhouette; add whole quiet background crown pictures at
            # each displaced shoulder, rather than stretching the main arch.
            for sign,family in [(-1,'left'),(1,'right')]:
                shift=profile(z,needs[family],.4)
                if shift>.10:
                    wing=dict(value,x=value['x']+sign*shift,z=z+sign*.017,
                              event_attachment='outer_crown_lateral_overlap')
                    cards.append(wing)
    cards=add_ground_transitions(cards)
    if spec.get('hanging'):cards=add_hanging(cards,route)
    result=dict(spec,cards=cards,status='event_envelope_fit_requires_fresh_native_check')
    result['exclusions']=['research event envelope only','no complete battle/exit or repeated forks','no export or art acceptance']
    result['event']={'trigger_z':34.,'capability':'required','source':'measured formation and camera rays',
                     'research_margin_m':margin,'profile_gradient_bounds':gradients,
                     'requirements':needs,'max_translation_m':{k:max([a for _,a in v],default=0) for k,v in needs.items()},
                     'limitations':['sampled two-second formation, not all parties/skills','no battle exit or successor verification']}
    result['shots']=list(spec['shots'])
    for branch in route.branches:
        for frame in capture['event_frames']:
            camera=list(frame['camera_m']);camera[0]+=(branch-chosen)*route.final_offset
            result['shots'].append(dict(name=f'event-{branch}-{frame["tick"]}',pose=camera,branch=branch,lens=frame['lens'],horizon=frame['horizon'],scope='measured_event_camera'))
    return result


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--spec',required=True);p.add_argument('--capture',required=True);p.add_argument('--out',required=True)
    args=p.parse_args();source=Path(args.spec);folder=Path(args.capture);out=Path(args.out)
    out.mkdir(parents=True,exist_ok=False)
    spec=json.loads(source.read_text(encoding='utf-8'));manifest=folder/'manifest.json'
    capture=json.loads(manifest.read_text(encoding='utf-8'))
    result=compile_layout(spec,capture,folder)
    result['event']['capture_sha256']=hashlib.sha256(manifest.read_bytes()).hexdigest()
    result['event']['source_spec_sha256']=hashlib.sha256(source.read_bytes()).hexdigest()
    (out/'fork.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps(result['event']['max_translation_m']))
