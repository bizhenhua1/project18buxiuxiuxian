"""Compile a bounded two-leg card tree before traversal, without scene swaps.

Each possible first exit owns a complete second preview. Parent/child gates
remain independent. This intentionally tests two consecutive decisions; it is
not an unbounded streamer or a complete biome certification.
"""
import argparse
import copy
import json
from pathlib import Path
from cave_card_junction import Junction
from compile_cave_formation_groups import parent_links


def compile_chain(source, join=90.):
    route=Junction(source['route']['exits']);vars(route).update(source['route'])
    if join < float(route.continuation['end'])+4:
        raise ValueError('Join must follow the settled axial return with a straight reserve')
    cards=source['cards'];links=parent_links(cards)
    result=copy.deepcopy(source);result['cards']=[]
    def parent_z(i):return cards[links.get(i,i)]['z']
    # Keep a single, explicit ownership plane: old groups before join, new
    # groups from their local zero onward. Child foot dressing follows parent.
    for i,c in enumerate(cards):
        if parent_z(i)>=join:continue
        q=copy.deepcopy(c);q['study_node']=0;q['study_parent_owner']=99
        result['cards'].append(q)
    nodes=[dict(id=0,origin=[0.,0.],parent_owner=99,route=source['route'],portal=source['portal'])]
    for node_id,branch in enumerate(route.branches,1):
        origin=[float(route.center(join,branch)),join]
        nodes.append(dict(id=node_id,origin=origin,parent_owner=branch,
                          route=source['route'],portal=source['portal']))
        for i,c in enumerate(cards):
            if not 0<=parent_z(i)<join:continue
            q=copy.deepcopy(c);q['x']+=origin[0];q['z']+=origin[1]
            if 'support_reference' in q:
                q['support_reference']=[q['support_reference'][0]+origin[0],q['support_reference'][1]+origin[1]]
            if q.get('support_kind')=='ceiling_attachment':
                p=q['attachment']['parent_position'];q['attachment']['parent_position']=[p[0]+origin[0],p[1]+origin[1]]
            q['study_node']=node_id;q['study_parent_owner']=branch
            result['cards'].append(q)
    result['cards'].sort(key=lambda c:c['z'])
    result['chain']=dict(nodes=nodes,join_local_forward_m=join,max_legs=2,
                         end_local_forward_m=join,prepared_before_first_frame=True)
    result['status']='two_leg_study_not_art_or_streaming_acceptance'
    return result


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--spec',required=True);p.add_argument('--out',required=True)
    p.add_argument('--join',type=float,default=90.)
    a=p.parse_args();result=compile_chain(json.loads(Path(a.spec).read_text(encoding='utf-8')),a.join)
    out=Path(a.out);out.mkdir(parents=True,exist_ok=False)
    (out/'fork.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps(dict(cards=len(result['cards']),nodes=len(result['chain']['nodes']),join=a.join)))
