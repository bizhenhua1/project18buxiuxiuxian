"""Append traversal clips from the supplied blend, preserving existing pack IDs."""
import bpy, pathlib, json, array, math
from mathutils import Matrix
BASE=pathlib.Path('F:/GitHub/project18buxiuxiuxian')
OUT=BASE/'godot/assets/motions'
catalog=json.loads((OUT/'catalog.json').read_text(encoding='utf-8'))
bones=catalog['bones']
rig=bpy.data.objects['Amplify_Rig_Default'];source=bpy.data.objects['root']
for obj in list(bpy.data.objects):
    if obj.type=='MESH':bpy.data.objects.remove(obj,do_unlink=True)
for obj in [rig,source]:
    obj.hide_viewport=False;obj.hide_set(False);obj.animation_data_create()
    obj.animation_data.action=None
    for track in obj.animation_data.nla_tracks:track.mute=True
C=Matrix(((1,0,0,0),(0,0,1,0),(0,-1,0,0),(0,0,0,1)))
rest={n:C@source.matrix_world@source.data.bones[n].matrix_local for n in bones}
height=abs(rest['pelvis'].translation.y)
assert height>.001
chosen=[a for a in bpy.data.actions if a.name.lower().startswith('ladder_') or a.name.startswith('Obstacle_Climb') or a.name in ['Obstacle_Drop_Loop','Obstacle_Drop_Loop_01','WallPoints_Idle','WallPoints_jump_grab_V2','WallPoints_Release_Start','WallPoints_Release_End','Obstacle_Move_L','Obstacle_Move_R'] or a.name.startswith(('WallPoints_Jump_Up','WallPoints_Jump_Dn'))]
assert len(chosen)>=25
clips=[];report=[]
for action in sorted(chosen,key=lambda a:a.name):
    rig.animation_data.action=None
    for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
    rig.animation_data.action=action
    if action.slots:rig.animation_data.action_slot=action.slots[0]
    start,end=map(int,action.frame_range)
    fps=bpy.context.scene.render.fps/bpy.context.scene.render.fps_base
    values=array.array('f');trajectory=[]
    for frame in range(start,end+1):
        bpy.context.scene.frame_set(frame);bpy.context.view_layer.update()
        hip=((C@source.matrix_world@source.pose.bones['pelvis'].matrix).translation-rest['pelvis'].translation)/height
        values.extend(hip);trajectory.append(list(hip))
        for n in bones:
            q=(C@source.matrix_world@source.pose.bones[n].matrix).to_quaternion()@rest[n].to_quaternion().inverted()
            q.normalize();values.extend((q.x,q.y,q.z,q.w))
    assert all(math.isfinite(v) for v in values)
    key='3_'+action.name
    (OUT/(key+'.motion')).write_bytes(values.tobytes())
    loop='loop' in action.name.lower() or 'idle' in action.name.lower()
    group='梯子上下' if action.name.lower().startswith('ladder') else '立面攀爬与悬挂'
    clip=dict(id=key,name=action.name,pack='3',group=group,frames=end-start+1,fps=fps,file='res://assets/motions/'+key+'.motion',traversal=True,loop_hint=loop)
    clips.append(clip)
    report.append(dict(**clip,source_action=action.name,source_frame_start=start,hip_height_source=height,hip_displacement_normalized=[trajectory[-1][i]-trajectory[0][i] for i in range(3)],hip_trajectory_normalized=trajectory))
    print('TRAVERSAL_EXPORTED',key,end-start+1,flush=True)
existing=[c for c in catalog['clips'] if c.get('pack')!='3']
catalog['clips']=existing+clips
catalog['packs']=[p for p in catalog.get('packs',[]) if str(p['id'])!='3']+[dict(id='3',label='攀爬与上下通行',count=len(clips))]
catalog['source']='Existing packs 04-10 + Amplify traversal from supplied Blender source'
(OUT/'catalog.json').write_text(json.dumps(catalog,ensure_ascii=False),encoding='utf-8')
(OUT/'traversal-source.json').write_text(json.dumps(dict(source=bpy.data.filepath,coordinate_system='Godot Y-up; translation normalized by source rest pelvis height',clips=report),ensure_ascii=False),encoding='utf-8')
print('TRAVERSAL_DONE',len(clips),'PRESERVED',len(existing),flush=True)
