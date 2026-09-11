"""Resolve the package's projectile/muzzle/impact references (no guessed pairings)."""
from pathlib import Path
import json,re
ROOT=Path(__file__).resolve().parents[1];out=ROOT/'godot/assets/fx/epic181/library';source=ROOT/'tempassets/vfx/epic-toon-1.81/source'
index=json.loads((out/'index.json').read_text(encoding='utf-8'));by={e['id']:e for e in index}
links=0
for e in index:
 name=e['name'].removesuffix('OBJ')
 for color in ['Red','Blue','Green','Yellow','Purple','Pink','Orange','White','Black','Fire','Water','Dark','Light','Gold','Silver']:
  if name.endswith(color):e['color']=color;break
 if e['category']=='Lightning' and not e['name'].endswith('OBJ'):e['behavior']='impact' if 'Strike' in e['name'] or 'Blast' in e['name'] else 'ambient'
 if e['category']=='Flamethrower':e['behavior']='stream'
 if not '/Demo/' in e['source']:continue
 raw=(source/e['source']).read_text(encoding='utf-8-sig');refs={}
 for key in ['projectileParticle','muzzleParticle','impactParticle']:
  match=re.search(r'\b'+key+r': \{[^}]*guid: ([a-f0-9]+)',raw)
  if match and match[1] in by:refs[key]=match[1]
 if 'projectileParticle' not in refs:continue
 projectile=by[refs['projectileParticle']]
 if not projectile['playable']:continue
 e.update(playable=True,file=projectile['file'],layers=projectile['layers'],behavior='projectile',animated_sheet=projectile['animated_sheet'])
 e['muzzle_id']=refs.get('muzzleParticle','');e['impact_id']=refs.get('impactParticle','');e['projectile_id']=projectile['id']
 e['warnings']=projectile['warnings']+['原包组合引用已解析，飞行与命中由预览调度']
 projectile['muzzle_id']=e['muzzle_id'];projectile['impact_id']=e['impact_id'];links+=1
(out/'index.json').write_text(json.dumps(index,ensure_ascii=False,indent=1),encoding='utf-8')
print('Linked original combinations',links,'playable',sum(e['playable'] for e in index))
