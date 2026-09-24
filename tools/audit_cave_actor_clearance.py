"""Reject a captured traversal when an upright body envelope crosses opaque art.

Uses actual terrain-adjusted sprite transforms and actual visible actor roots,
not the camera rail. This is a conservative sampled cylinder contract, not a
skinned-mesh collision proof. Transparent canvas margins do not block passage.
"""
import argparse
import json
from pathlib import Path
import numpy as np
from PIL import Image


def audit(folder, root, radius=.28, height=1.75):
    data = json.loads((folder/'manifest.json').read_text(encoding='utf-8'))
    cards = data['instances']
    alpha = {}
    for card in cards:
        key = card['source']
        if key not in alpha:
            alpha[key] = np.asarray(Image.open(root/'godot'/key.removeprefix('res://')).convert('RGBA'))[:,:,3]
    failures = []
    samples = data.get('trajectory', [])
    if not samples:
        raise ValueError('No actual actor trajectory captured')
    for sample in samples:
        x,y,z = sample['position_m']
        branch = sample['branch']
        branch = 0 if branch == 2 else branch
        for index, card in enumerate(cards):
            if data.get('chain_probe'):
                choices=sample.get('chain_choices',{})
                parent=card.get('study_parent_owner',99)
                if parent!=99 and choices.get('0')!=parent:continue
                branch_for_card=choices.get(str(card.get('study_node',0)))
                owner=card.get('owner_branch')
                if owner is not None and owner!=branch_for_card:continue
            else:
                owner = card.get('owner_branch')
                if owner is not None and owner != branch:
                    continue
            cx,cy,neg_cz = card['position_m']; cz=-neg_cz
            yaw = card['yaw']; co=np.cos(yaw); si=np.sin(yaw)
            # Plane tangent (cos yaw, -sin yaw) in logical X/+forward.
            distance = (x-cx)*si+(z-cz)*co
            if abs(distance)>radius:
                continue
            along = (x-cx)*co-(z-cz)*si
            half = np.sqrt(max(0, radius**2-distance**2))
            u = .5+np.linspace(along-half,along+half,17)/card['width_m']
            v = 1-(np.linspace(y+.10,y+height,23)-cy)/card['height_m']
            u=u[(u>=0)&(u<1)];v=v[(v>=0)&(v<1)]
            if len(u)==0 or len(v)==0:continue
            texture=alpha[card['source']]
            occupied=texture[(v*texture.shape[0]).astype(int)[:,None],(u*texture.shape[1]).astype(int)[None,:]]>=128
            if occupied.any():
                failures.append(dict(tick=sample['tick'],uid=sample['uid'],position_m=sample['position_m'],card=index,role=card['role'],source=card['source'],opaque_samples=int(occupied.sum())))
    result=dict(status='rejected_body_intersection' if failures else 'sampled_actor_envelope_clear_not_art_acceptance',
                scope='actual roots, terrain-adjusted fixed art; sampled upright cylinder, not animated limbs or continuous swept collision',
                radius_m=radius,height_m=height,trajectory_samples=len(samples),intersections=len(failures),failures=failures)
    (folder/'actor-clearance.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps({k:v for k,v in result.items() if k!='failures'}))
    return 2 if failures else 0


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--run',required=True)
    parser.add_argument('--radius',type=float,default=.28);parser.add_argument('--height',type=float,default=1.75)
    args=parser.parse_args()
    raise SystemExit(audit(Path(args.run),Path(__file__).resolve().parents[1],args.radius,args.height))
