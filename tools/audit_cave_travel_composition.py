"""Reject lateral loss of the travelling leader in the finite-bend study.
Uses the unchanged incoming shoulder composition as its measured reference.
Fork narrowing intentionally recentres the leader and is outside this check.
"""
import argparse,json
from pathlib import Path
import numpy as np


def root_x(view,actor):
    if abs(view['heading'])>1e-5:raise ValueError('This gate requires the declared fixed camera heading')
    w,h=view['viewport'];focal=min(h*.86,w*.72)*view['lens']
    depth=actor['position_m'][2]+view['camera_world_m'][2]
    if depth<=0:raise ValueError('Visible leader root behind camera')
    projected=.5+(actor['position_m'][0]-view['camera_world_m'][0])*focal/(depth*w)
    if 'screen_root_ratio' in actor and abs(projected-actor['screen_root_ratio'][0])>.002:
        raise ValueError('Projection reconstruction differs from native camera')
    return projected


def audit(folder,tolerance=.04):
    data=json.loads((folder/'manifest.json').read_text(encoding='utf-8'))
    refs={}
    for view in data['views']:
        if view['phase']!='travel' or -view['camera_world_m'][2]>7:continue
        for actor in view['actors']:
            if actor['visible']:refs.setdefault(actor['uid'],[]).append(root_x(view,actor))
    refs={uid:float(np.median(values)) for uid,values in refs.items()}
    if len(refs)!=1:raise ValueError('Study needs exactly one identified travelling leader')
    rows=[]
    for view in data['views']:
        local_z=-view['camera_world_m'][2]-view.get('route_origin',[0,0])[1]
        if view['phase']!='travel' or local_z<49:continue
        for actor in view['actors']:
            if not actor['visible'] or actor['uid'] not in refs:continue
            x=root_x(view,actor);expected=refs[actor['uid']]
            rows.append(dict(frame=view['index'],actual_root_x=x,reference_root_x=expected,deviation=abs(x-expected)))
    if not rows:raise ValueError('No continued-travel frames, cannot certify camera rail')
    worst=max(r['deviation'] for r in rows)
    report=dict(status='rejected_leader_composition_drift' if worst>tolerance else 'sampled_leader_composition_preserved',
                tolerance_viewport_width=tolerance,threshold_basis='study tolerance around measured existing shoulder composition, not universal art approval',
                max_deviation=worst,frames=rows)
    (folder/'travel-composition.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k!='frames'}))
    return 2 if worst>tolerance else 0


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--run',required=True);a=p.parse_args()
    raise SystemExit(audit(Path(a.run)))
