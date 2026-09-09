import bpy,pathlib,json,array
from mathutils import Matrix
BASE=pathlib.Path('F:/GitHub/project18buxiuxiuxian');OUT=BASE/'godot/assets/motions';m=json.loads((OUT/'catalog.json').read_text(encoding='utf-8'));C=Matrix(((1,0,0,0),(0,0,1,0),(0,-1,0,0),(0,0,0,1)))
for path in sorted((BASE/'tempassets/work/fbx').glob('EM_*.fbx')):
 bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.fbx(filepath=str(path));s=next(o for o in bpy.data.objects if o.type=='ARMATURE');a=s.animation_data.action
 start,end=map(int,a.frame_range);rest={b.name:C@s.matrix_world@b.matrix_local for b in s.data.bones};height=abs(rest['pelvis'].translation.y);v=array.array('f')
 for f in range(start,end+1):
  bpy.context.scene.frame_set(f)
  hip=(C@s.matrix_world@s.pose.bones['pelvis'].matrix).translation-rest['pelvis'].translation;v.extend(hip/height)
  for n in m['bones']:
   if n not in rest:v.extend((0,0,0,1));continue
   q=(C@s.matrix_world@s.pose.bones[n].matrix).to_quaternion()@rest[n].to_quaternion().inverted();v.extend((q.x,q.y,q.z,q.w))
 name=path.stem;(OUT/(name+'.motion')).write_bytes(v.tobytes());m['clips'].append({'id':name,'name':name,'frames':end-start+1,'fps':bpy.context.scene.render.fps,'file':'res://assets/motions/'+name+'.motion'})
(OUT/'catalog.json').write_text(json.dumps(m,ensure_ascii=False),encoding='utf-8');print('EM_ADDED',len(m['clips']))
