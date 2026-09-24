"""Bounded 2D-primary comparison. Analytic cards, not approved bitmap assets.

Reuses the SAME route and lens as the mesh research. The optional connector
is limited to the medial fork saddle. No structural meshes down the corridor.
Failure of a candidate is not evidence that the whole 2D approach is impossible.
"""
import argparse
import json
from dataclasses import asdict,replace
from cave_algorithm_lab import Recipe,ROOT,poses,cast,evaluate,planes,section,profile

def main():
    p=argparse.ArgumentParser();p.add_argument('--out',required=True)
    p.add_argument('--exits',type=int,choices=[2,3],default=2)
    a=p.parse_args();out=ROOT/a.out;out.mkdir(parents=True,exist_ok=False)
    base=Recipe(method='union',exits=a.exits,offset=3.1 if a.exits==2 else 5.4,
                radius=1.85,throat=1.10,height=3.,spring=.7,band=1.6,
                relief=.4,jitter=.15,seed=91,forward_end=96.)
    refs=[cast(base,pose,(80,50),True)[0] for pose in poses(base,37)]
    results=[]
    for mode in ['union','card-hybrid']:
        for step in [.5,.8,1.1,1.4]:
            r=replace(base,method=mode,step=step)
            result=evaluate(r,37,(80,50),refs);results.append(result)
            key=f'{mode}-{step}'
            spec=dict(recipe=asdict(r),planes=planes(r).tolist(),lens=1.,horizon=.48,
                      representation='2d_cards_with_local_connector' if mode=='card-hybrid' else '2d_cards',
                      sections=[dict(z=float(z),centers=section(z,r)[0],radius=section(z,r)[1],height=float(profile(z,r)[1])) for z in planes(r)],
                      shots=[dict(name=f'card-{i}',pose=pose) for i,pose in enumerate(poses(r,9))])
            if mode=='card-hybrid':
                from cave_lab_mesh import divider_skin
                import numpy as np
                mesh_name=key+'-connector.json'
                # Only the local fork saddle. Never export the old corridor ribs.
                skin=divider_skin(r)
                (out/mesh_name).write_text(json.dumps([dict(index=0,z=10,critical_skin=True,vertices=np.round(skin.reshape(-1,3),6).tolist())],separators=(',',':')),encoding='utf-8')
                spec['connector_mesh_file']=mesh_name
            (out/(key+'.json')).write_text(json.dumps(spec,indent=2),encoding='utf-8')
            print(key,result['screened'],result['max_missing_fraction'],result['max_p99_extra_depth_m'],flush=True)
    (out/'results.json').write_text(json.dumps(dict(status='geometry_screen_not_asset_or_art_acceptance',results=results),indent=2),encoding='utf-8')

if __name__=='__main__':main()
