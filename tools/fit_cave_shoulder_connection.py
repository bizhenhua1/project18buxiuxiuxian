"""Bounded upper-connection fit for a grounded, top-continuing 2D shoulder.

Native terrain placement is queried in one batch before source-alpha visibility
tests. Depth candidates either preserve the side sequence or place the shoulder
just behind its preceding roof card. Hidden picture height may grow, but source
aspect, the body-clear passage and visible overhead clearance are preserved.
"""
import argparse
import copy
import json
import subprocess
from pathlib import Path

from audit_cave_continuation_edges import audit
from cave_algorithm_lab import geology_noise
from cave_card_junction import Junction
from compile_cave_side_profile import anchored_shoulder

ROOT=Path(__file__).resolve().parents[1]
ASSET='godot/assets/biomes/crystal/cards-study/shoulder-left-covered-c.png'


def prepare(spec,data):
    route=Junction(spec['route']['exits']);vars(route).update(spec['route'])
    roof=sorted(c['z'] for c in spec['cards'] if c['role']=='outer-crown' and c.get('branch')==-1)
    targets=[(i,c) for i,c in enumerate(data['instances']) if c['source'].endswith('/shoulder-left-covered-c.png')]
    if not targets:raise ValueError('No grounded continuation shoulders')
    variants=[];queries=[]
    for height in (4.4,4.8,5.2,5.6):
        for align in (False,True):
            variant=dict(height=height,align_to_roof=align,placements=[])
            for index,record in targets:
                original_z=-record['position_m'][2]
                z=original_z
                if align:
                    preceding=[v for v in roof if v<z-.08]
                    if not preceding:raise ValueError('No foreground roof to connect')
                    z=preceding[-1]+.08
                h=height+.24*float(geology_noise(z-7,311))
                card=anchored_shoulder(ASSET,h,float(route.center(z,-1)),z,-1,float(route.width(z))+.15)
                card['id']=len(queries)
                queries.append(card)
                variant['placements'].append(dict(record_index=index,query_id=card['id'],card=card,original_z=original_z))
            variants.append(variant)
    return variants,queries


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--spec',required=True)
    parser.add_argument('--run',required=True);parser.add_argument('--godot',required=True)
    parser.add_argument('--out',required=True);args=parser.parse_args()
    out=Path(args.out).resolve();out.mkdir(parents=True,exist_ok=False)
    spec=json.loads(Path(args.spec).read_text(encoding='utf-8'))
    data=json.loads((Path(args.run)/'manifest.json').read_text(encoding='utf-8'))
    variants,queries=prepare(spec,data)
    query_path=out/'queries.json';answer_path=out/'native-placements.json'
    query_path.write_text(json.dumps(queries,indent=2),encoding='utf-8')
    command=[args.godot,'--headless','--path',str(ROOT/'godot'),'--script',
             'res://tests/measure_cave_ground_placements.gd','--',
             '--input='+str(query_path),'--out='+str(answer_path)]
    process=subprocess.run(command,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=60)
    (out/'native.log').write_text(process.stdout+process.stderr,encoding='utf-8')
    if process.returncode or 'SCRIPT ERROR' in process.stdout+process.stderr or not answer_path.exists():
        raise RuntimeError('Native support query failed; see native.log')
    placements={v['id']:v for v in json.loads(answer_path.read_text(encoding='utf-8'))}
    reports=[];accepted=None
    for variant in variants:
        candidate=copy.deepcopy(data)
        for entry in variant['placements']:
            i=entry['record_index'];card=entry['card'];ground=placements[entry['query_id']]
            old=candidate['instances'][i]
            old.update(position_m=[card['x'],ground['y'],-card['z']],
                       width_m=card['width'],height_m=card['height'],burial_m=ground['burial'])
        result=audit(candidate,'/shoulder-left-covered-c.png')
        reports.append(dict(height=variant['height'],align_to_roof=variant['align_to_roof'],
                            exposed_samples=result['exposed_samples']))
        if result['exposed_samples']==0:
            accepted=variant
            (out/'fitted-manifest.json').write_text(json.dumps(candidate,indent=2),encoding='utf-8')
            break
    report=dict(scope='bounded shape/roof-depth fit on recorded native cameras; new motion holdout and native render required',
                candidates=reports,accepted=accepted,art_accepted=False)
    (out/'fit.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps(dict(candidates=reports,accepted=bool(accepted))))
