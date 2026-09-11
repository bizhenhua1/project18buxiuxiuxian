"""Remove explicitly audited accessory surfaces without changing skinning/bind poses.
Original GLBs are retained locally; repeat runs always start from those originals.
"""
import json, struct, shutil
from pathlib import Path
BASE=Path(__file__).resolve().parents[2]
RULES={
 'antiquarian':{'remove':['小鸟']},
 'batter-helmsman':{'remove':['船','螃蟹'],'weapons':['棍','棍2']},
 'cheerleader-melody':{'remove':['彩球']},
 'fools-gold':{'remove':['石头'],'weapons':['武器']},
 'gardener-kitty-dada':{'remove':['毛绒球','手持包','手持物','宠物','宠物装饰']},
 'gardener-kitty':{'remove':['hello kitty','包']},
 'gentleman':{'remove':['兔1','兔2']},
 'hermit':{'weapons':['武器']},
 'joseph-cinnamoroll':{'remove':['大耳狗b','大耳狗','星星','牌'],'weapons':['武器']},
 'joseph-necromancer-old':{'weapons':['剑']},
 'joseph-necromancer-young':{'weapons':['剑']},
 'king-h1':{'remove':['paper']},
 'lucky-egg':{'remove':['蛋小黄','鱼','机械']},
 'mary-kuromi':{'remove':['骷髅1','骷髅2','骷髅3'],'weapons':['武器']},
 'scarlet-banquet':{'remove':['镜子','镜子鸟'],'weapons':['刀']},
 'geisha-thirteen':{'weapons':['扇子']}
}
def main():
 backup=BASE/'tempassets/work/character-originals';backup.mkdir(parents=True,exist_ok=True)
 report={}
 for name,rule in RULES.items():
  dest=BASE/'godot/assets/characters3d'/f'{name}.glb';src=backup/dest.name
  if not src.exists():shutil.copy2(dest,src)
  raw=src.read_bytes();size=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+size]);removed=[]
  names=set(rule.get('remove',[])+rule.get('weapons',[]))
  for mi,mesh in enumerate(doc['meshes']):
   kept=[]
   for part in mesh['primitives']:
    mat=doc['materials'][part['material']]['name']
    if mat in names:removed.append(mat)
    else:kept.append(part)
   if kept:mesh['primitives']=kept
   else:
    for node in doc['nodes']:
     if node.get('mesh')==mi:node.pop('mesh');node.pop('skin',None)
  payload=json.dumps(doc,ensure_ascii=False,separators=(',',':')).encode();payload+=b' '*((-len(payload))%4)
  tail=raw[20+size:];dest.write_bytes(struct.pack('<4sII',b'glTF',2,20+len(payload)+len(tail))+struct.pack('<II',len(payload),0x4E4F534A)+payload+tail)
  report[name]={**rule,'removed_surfaces':removed,'original':str(src.relative_to(BASE))}
 out=BASE/'art/3d/character-prop-cleanup.json';out.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
 print('Cleaned',len(report),'models; original skin, node and animation data preserved')
if __name__=='__main__':main()
