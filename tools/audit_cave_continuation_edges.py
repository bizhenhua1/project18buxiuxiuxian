"""Detect visible clipped canvas edges in intentional 2D coverage patches.

A full opaque top band may permit wider depth spacing, but trades an isolated
silhouette for a crop-through surface. Audit that new obligation independently
of background-hole detection, using native transforms and camera positions.
"""
import argparse
import copy
import json
from pathlib import Path
import numpy as np
from audit_cave_event_visibility import load_cards
from cave_art_cards import raycast


def camera_holdout(data, phases=(.23,.57,.81)):
    """Independent between-frame stress samples; never label these native poses."""
    if not phases or any(not 0<t<1 for t in phases):
        raise ValueError('Holdout phases must be strictly between recorded poses')
    result=copy.deepcopy(data)
    recorded=[v for v in data['views'] if -v['camera_world_m'][2]>51]
    result['views']=[]
    for a,b in zip(recorded,recorded[1:]):
        for t in phases:
            position=(1-t)*np.asarray(a['camera_world_m'])+t*np.asarray(b['camera_world_m'])
            for dx,dy in [(0,0),(-.05,-.05),(-.05,.05),(.05,-.05),(.05,.05)]:
                view=copy.deepcopy(a)
                view['index']=len(result['views'])
                view['camera_world_m']=(position+np.array([dx,dy,0])).tolist()
                view['frame_origin']='synthetic interpolation and 5cm stress margin, not native capture'
                result['views'].append(view)
    return result


def audit(data, suffix):
    cards, alphas=load_cards(data)
    rows=[]
    for view in data['views']:
        camera=np.array(view['camera_world_m'],dtype=float)
        camera[2]*=-1
        if camera[2]<=51:
            continue
        if abs(view['heading'])>1e-6:
            raise ValueError('Continuation edge study requires fixed forward camera')
        branch=0 if view['branch']==2 else view['branch']
        selected=[c for c in cards if c.get('owner_branch') in (None,branch)
                  and c['z']>camera[2]+.05]
        points=[]; identities=[]; edges=[]
        for index,c in enumerate(selected):
            if not c['asset'].endswith(suffix):
                continue
            if abs(c['yaw'])>1e-6 or c['uv']!=[0,0,1,1]:
                raise ValueError('Coverage images must preserve full frontal source')
            alpha=alphas[c['asset']]
            du=.5/alpha.shape[1];dv=.5/alpha.shape[0]
            t=np.linspace(.001,.999,80)
            for name,uv in [('top',np.c_[t,np.full(len(t),dv)]),
                            ('left',np.c_[np.full(len(t),du),t]),
                            ('right',np.c_[np.full(len(t),1-du),t])]:
                occupied=alpha[(uv[:,1]*alpha.shape[0]).astype(int),
                               (uv[:,0]*alpha.shape[1]).astype(int)]>=128
                uv=uv[occupied]
                p=np.c_[c['x']+(uv[:,0]-.5)*c['width'],
                        c['y']+(1-uv[:,1])*c['height'],np.full(len(uv),c['z'])]
                points.extend(p.tolist());identities.extend([index]*len(p));edges.extend([name]*len(p))
        if not points:
            raise ValueError('No eligible coverage patches')
        p=np.asarray(points)-camera
        dx=p[:,0]/p[:,2];dy=p[:,1]/p[:,2]
        focal=.86*view['lens'];aspect=view['viewport'][0]/view['viewport'][1]
        sx=.5+dx*focal/aspect;sy=view['horizon']-dy*focal
        seen=(sx>=0)&(sx<=1)&(sy>=0)&(sy<=1)
        kept=np.flatnonzero(seen)
        if not len(kept):
            rows.append(dict(view=view['index'],in_frame=0,exposed=0,examples=[]))
            continue
        _,owners=raycast(selected,camera,(1,len(kept)),alphas,
                         ray_slopes=(dx[seen][None,:],dy[seen][None,:]))
        identity=np.asarray(identities)
        exposed=kept[owners[0]==identity[seen]]
        examples=[dict(edge=edges[i],source=selected[identity[i]]['asset'],
                       depth_m=float(p[i,2]),screen=[float(sx[i]),float(sy[i])])
                  for i in exposed[:12]]
        rows.append(dict(view=view['index'],in_frame=len(kept),exposed=len(exposed),examples=examples))
    if not rows:
        raise ValueError('No post-selection cameras')
    total=sum(r['exposed'] for r in rows)
    return dict(status='rejected_visible_canvas_edges' if total else 'sampled_continuation_edges_concealed',
                source_suffix=suffix,
                exposed_samples=total,frames=rows,art_accepted=False,
                scope='source alpha/native transforms, sampled clip edges; not continuous motion or perceptual acceptance')


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--run',required=True)
    parser.add_argument('--source-suffix',default='/roof-coverage-a.png')
    parser.add_argument('--camera-holdout',action='store_true')
    parser.add_argument('--holdout-phases',type=float,nargs='+',default=[.23,.57,.81])
    args=parser.parse_args();folder=Path(args.run)
    data=json.loads((folder/'manifest.json').read_text(encoding='utf-8'))
    if args.camera_holdout:data=camera_holdout(data,args.holdout_phases)
    result=audit(data,args.source_suffix)
    result['camera_origin']='synthetic interpolation plus 5cm x/y stress probes' if args.camera_holdout else 'native captured poses'
    if args.camera_holdout:result['holdout_phases']=args.holdout_phases
    stem='continuation-edges'
    if args.source_suffix!='/roof-coverage-a.png':stem+='-'+Path(args.source_suffix).stem
    name=stem+('-holdout' if args.camera_holdout else '')+'.json'
    (folder/name).write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps({k:v for k,v in result.items() if k!='frames'}))
    raise SystemExit(2 if result['exposed_samples'] else 0)
