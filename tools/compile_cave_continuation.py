"""Compile finite, axial-return bends into both 2D placement and route tables.
The same serialized samples drive runtime actors and the ground shader.
Battle geometry is immutable before the continuation starts.
"""
import argparse,json
from pathlib import Path
import numpy as np
from cave_card_junction import Junction,apply_source_variants
from cave_art_cards import authored_cards,crown_gap_budget,add_ground_transitions
from cave_card_dressing import add_hanging


def compile_layout(source,offset):
    spec=json.loads(json.dumps(source))
    r=Junction(spec['route']['exits']);vars(r).update(spec['route'])
    r.continuation=dict(start=51.,peak=65.,end=79.,offset=float(offset),camera_lead_m=1.6)
    if r.continuation['start'] <= max(z for needs in spec['event']['requirements'].values() for z,_ in needs)+3:
        raise ValueError('Bend overlaps battle display reserve')
    for c in spec['cards']:
        b=c.get('branch',c.get('owner_branch',0)) or 0
        shift=float(r.center(c['z'],b)-b*r.offset(c['z']))
        c['x']+=shift
        if c.get('support_kind')=='ceiling_attachment':
            # Parent and child have different depths; preserve the authored
            # attachment translation instead of bending the assembled group.
            old_z=c['support_reference'][1]
            parent_shift=float(r.center(old_z,b)-b*r.offset(old_z))
            c['x']+=parent_shift-shift
            c['support_reference'][0]+=parent_shift
            c['attachment']['parent_position'][0]+=parent_shift
    # The camera must not outrun the structural art buffer while testing the
    # return to axis. Compile a real forward guard, not a hidden end wall or
    # removal of the final test camera. Two metres of authored overlap join it.
    budget=min([crown_gap_budget(2.25,1552/830,True,s) for s in ['crown-b','crown-c']],key=lambda b:b['max_gap_m'])
    source_tail=authored_cards(1.2,seed=194,backing=True,outer_crown=True,
        coherent_profile=True,gap_budget=budget,quiet_crown=True,formation_groups=True,end=116.)
    tail=[]
    for card in source_tail:
        if card['z']<80:continue
        for b in r.branches:
            value=dict(card,branch=b,owner_branch=None if 'crown' in card['role'] else b)
            value['x']+=float(r.center(card['z'],b))
            if 'crown' in card['role']:value['z']+=.045*b
            tail.append(value)
    apply_source_variants(tail,194,r,True)
    tail=add_ground_transitions(tail)
    if spec.get('hanging'):tail=add_hanging(tail,r,194)
    spec['cards']=sorted(spec['cards']+tail,key=lambda c:c['z'])
    if len(spec['cards'])>3000:raise ValueError('Research instance budget exceeded')
    spec['continuation_guard']={'authored_overlap_start_m':80,'end_m':116,'terminal_unfinished':True}
    rdata=vars(r).copy();rdata['samples']={}
    zs=np.linspace(r.start,r.continuation['end'],257)
    for b in [-1,0,1]:
        xs=np.array([r.center(z,b) for z in zs]);s=np.r_[0.,np.cumsum(np.hypot(np.diff(xs),np.diff(zs)))]
        # Angles are obtained from this exact sampled route, not another bend formula.
        angle=np.arctan(np.gradient(xs,zs));angle[0]=0.;angle[-1]=0.
        rdata['samples'][str(b)]=np.c_[xs,zs-r.start,s,angle].tolist()
    spec['route']=rdata
    spec['status']='finite_continuation_research_not_art_accepted'
    spec['shots']=[dict(name='battle-continuation',pose=[-r.final_offset,1.944,34.025],branch=-1,lens=1.02,horizon=.24,scope='sightline_study')]
    for b in r.branches:
        for z in [40,48,51,55,59,63,65,68,72,76,79]:
            table=np.asarray(rdata['samples'][str(b)])
            s=np.interp(z-r.start,table[:,1],table[:,2])
            x=float(np.interp(s+r.continuation['camera_lead_m'],table[:,2],table[:,0]))
            spec['shots'].append(dict(name=f'bend-{b}-{z}',pose=[x,1.3,z],branch=b,scope='feet_leading_camera_rail'))
    return spec


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--spec',required=True);p.add_argument('--offset',type=float,required=True);p.add_argument('--out',required=True)
    a=p.parse_args();out=Path(a.out);out.mkdir(parents=True,exist_ok=False)
    spec=compile_layout(json.loads(Path(a.spec).read_text(encoding='utf-8')),a.offset)
    (out/'fork.json').write_text(json.dumps(spec,indent=2),encoding='utf-8')
    print(json.dumps({'cards':len(spec['cards']),'continuation':spec['route']['continuation']}))
