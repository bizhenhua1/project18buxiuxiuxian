import bpy, bmesh, json
from pathlib import Path
BASE=Path(__file__).resolve().parents[2]
rules=json.loads((BASE/'art/3d/character-prop-cleanup.json').read_text(encoding='utf-8'))
out=BASE/'godot/assets/weapons/character-extracted';out.mkdir(parents=True,exist_ok=True)
manifest=[]
for name,rule in rules.items():
 wanted=rule.get('weapons',[])
 if not wanted:continue
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.ops.import_scene.gltf(filepath=str(BASE/rule['original']))
 chosen=[]
 for obj in list(bpy.data.objects):
  if obj.type!='MESH':continue
  slots={i for i,m in enumerate(obj.data.materials) if m and m.name in wanted}
  if not slots:continue
  # Source rest vertices remain untouched until detached from the rig.
  bm=bmesh.new();bm.from_mesh(obj.data)
  bmesh.ops.delete(bm,geom=[f for f in bm.faces if f.material_index not in slots],context='FACES')
  bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
  bm.to_mesh(obj.data);bm.free()
  matrix=obj.matrix_world.copy();obj.parent=None;obj.matrix_world=matrix
  obj.modifiers.clear();chosen.append(obj)
 if not chosen:raise RuntimeError(name)
 bpy.ops.object.select_all(action='DESELECT')
 for obj in chosen:obj.select_set(True)
 bpy.context.view_layer.objects.active=chosen[0]
 bpy.ops.object.join();obj=bpy.context.object
 bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
 bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY',center='BOUNDS');obj.location=(0,0,0)
 bpy.ops.export_scene.gltf(filepath=str(out/(name+'.glb')),export_format='GLB',use_selection=True,export_animations=False)
 manifest.append({'file':name+'.glb','source_character':name,'materials':wanted,'origin':'bounds centre; original proportions preserved','grip_calibrated':False})
(out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print('EXTRACTED',len(manifest))
