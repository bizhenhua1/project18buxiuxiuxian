import bpy,pathlib,json,re,array,math
from mathutils import Matrix,Vector
BASE=pathlib.Path('F:/GitHub/project18buxiuxiuxian');OUT=BASE/'godot/assets/motions';OUT.mkdir(exist_ok=True)
p=next((BASE/'tempassets').glob('3-*/3-*/AnimationBlenderSource/Amplify_AnimationPack_v1.0.2.blend'));bpy.ops.wm.open_mainfile(filepath=str(p))
rig=bpy.data.objects['Amplify_Rig_Default'];source=bpy.data.objects['root']
# Keep constraint targets but remove heavy mesh evaluation during motion sampling.
for o in list(bpy.data.objects):
 if o.type=='MESH':bpy.data.objects.remove(o,do_unlink=True)
rig.hide_viewport=False;source.hide_viewport=False;rig.hide_set(False);source.hide_set(False)
rig.animation_data_create();rig.animation_data.action=None
for track in rig.animation_data.nla_tracks:track.mute=True
bones=[b.name for b in source.data.bones if b.name not in ['weapon_l','weapon_r']]
C=Matrix(((1,0,0,0),(0,0,1,0),(0,-1,0,0),(0,0,0,1)))
rest={n:C@source.matrix_world@source.data.bones[n].matrix_local for n in bones}
hipheight=abs(rest['pelvis'].translation.y)
actions=[];excluded=[]
for a in bpy.data.actions:
 targets={re.findall(r'pose.bones\["([^"]+)"\]',c.data_path)[0] for c in a.fcurves if re.findall(r'pose.bones\["([^"]+)"\]',c.data_path)}
 if targets.intersection({'torso','hips','chest','thigh_fk.L','foot_ik.L'}) and a.frame_range[1]>a.frame_range[0]:actions.append(a)
 else:excluded.append(a.name)
manifest={'bones':bones,'clips':[],'excluded':excluded,'source':'Amplify AnimationPack v1.0.2','hip_height':hipheight}
for idx,a in enumerate(actions):
 path=OUT/f'amplify-{idx:04}.motion'
 start,end=map(int,a.frame_range);fps=bpy.context.scene.render.fps/bpy.context.scene.render.fps_base
 if True:
  rig.animation_data.action=None
  for b in rig.pose.bones:b.matrix_basis=Matrix.Identity(4)
  rig.animation_data.action=a;rig.animation_data.action_slot=a.slots[0]
  values=array.array('f')
  for frame in range(start,end+1):
   bpy.context.scene.frame_set(frame);bpy.context.view_layer.update()
   hip=(C@source.matrix_world@source.pose.bones['pelvis'].matrix).translation-rest['pelvis'].translation
   values.extend(hip/hipheight)
   for name in bones:
    q=(C@source.matrix_world@source.pose.bones[name].matrix).to_quaternion()@rest[name].to_quaternion().inverted()
    values.extend((q.x,q.y,q.z,q.w))
  path.write_bytes(values.tobytes())
 manifest['clips'].append({'id':f'amplify-{idx:04}','name':a.name,'frames':end-start+1,'fps':fps,'file':f'res://assets/motions/{path.name}'})
 if idx%25==0:print('MOTION_PROGRESS',idx,len(actions),a.name,flush=True)
(OUT/'catalog.json').write_text(json.dumps(manifest,ensure_ascii=False),encoding='utf-8')
print('MOTIONS_DONE',len(actions),flush=True)
