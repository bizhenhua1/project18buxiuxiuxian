import json, struct, pathlib
base=pathlib.Path(__file__).resolve().parents[2]
report=[]
for path in sorted((base/'godot/assets/characters3d').glob('*.glb')):
 if 'skeleton' in path.name:continue
 raw=path.read_bytes();length=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+length])
 mats=doc.get('materials',[])
 parts=[]
 for mesh in doc.get('meshes',[]):
  for index,p in enumerate(mesh['primitives']):
   mat=mats[p['material']] if 'material'in p else {}
   ti=mat.get('pbrMetallicRoughness',{}).get('baseColorTexture',{}).get('index')
   tex=doc['images'][doc['textures'][ti]['source']].get('name','') if ti is not None else ''
   parts.append({'mesh':mesh.get('name',''),'surface':index,'material':mat.get('name',''),'texture':tex, 'vertices':doc['accessors'][p['attributes']['POSITION']]['count']})
 report.append({'file':path.name,'parts':parts})
out=base/'tempassets/work/character-parts-audit.json';out.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(out)
