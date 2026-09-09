import bpy,pathlib,json,array,math,traceback
from mathutils import Matrix
BASE=pathlib.Path('F:/GitHub/project18buxiuxiuxian');OUT=BASE/'godot/assets/motions'
old=json.loads((OUT/'catalog.json').read_text(encoding='utf8'));bones=old['bones']
entries=json.loads((BASE/'tempassets/work/current-fbx/manifest.json').read_text(encoding='utf8'))
C=Matrix(((1,0,0,0),(0,0,1,0),(0,-1,0,0),(0,0,0,1)))
result={'bones':bones,'clips':[],'packs':[],'excluded':[],'source':'Current packs 04-10'}
for entry in entries:
 try:
  if not entry['ok']:raise ValueError('FBX export failed')
  bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.fbx(filepath=entry['file'])
  s=next(o for o in bpy.data.objects if o.type=='ARMATURE')
  a=s.animation_data.action
  rest={b.name:C@s.matrix_world@b.matrix_local for b in s.data.bones}
  if 'pelvis' not in rest:raise ValueError('unsupported skeleton '+','.join(list(rest)[:8]))
  start,end=map(int,a.frame_range)
  if end<=start:raise ValueError('empty animation')
  height=abs(rest['pelvis'].translation.y)
  values=array.array('f')
  for f in range(start,end+1):
   bpy.context.scene.frame_set(f)
   hip=(C@s.matrix_world@s.pose.bones['pelvis'].matrix).translation-rest['pelvis'].translation;values.extend(hip/max(height,.001))
   for n in bones:
    if n not in rest:values.extend((0,0,0,1));continue
    q=(C@s.matrix_world@s.pose.bones[n].matrix).to_quaternion()@rest[n].to_quaternion().inverted()
    values.extend((q.x,q.y,q.z,q.w))
  if not all(math.isfinite(v) for v in values):raise ValueError('non finite animation')
  key=entry['id'];(OUT/(key+'.motion')).write_bytes(values.tobytes())
  result['clips'].append(dict(id=key,name=entry['name'],pack=entry['pack'],group=entry['group'],frames=end-start+1,fps=bpy.context.scene.render.fps/bpy.context.scene.render.fps_base,file='res://assets/motions/'+key+'.motion'))
  print('CLIP_DONE',key,flush=True)
 except Exception as e:
  result['excluded'].append(dict(name=entry['id'],reason=str(e)));print('CLIP_FAILED',entry['id'],str(e),flush=True)
labels={'4':'武士','5':'战士','6':'制作采集','7':'剑盾','8':'长矛','9':'邪恶法师','10':'女性交互'}
for key,label in labels.items():
 result['packs'].append(dict(id=key,label=label,count=sum(c['pack']==key for c in result['clips'])))
(OUT/'catalog.json').write_text(json.dumps(result,ensure_ascii=False),encoding='utf8')
print('PACKS_DONE',len(result['clips']),result['packs'],result['excluded'],flush=True)
