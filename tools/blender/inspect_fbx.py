import bpy,json,pathlib
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.fbx(filepath='F:/GitHub/project18buxiuxiuxian/tempassets/work/fbx/EM_Idle.fbx')
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
r={'matrix':[list(v) for v in rig.matrix_world],'bones':[{'name':b.name,'head':list(rig.matrix_world@b.head_local),'tail':list(rig.matrix_world@b.tail_local)} for b in rig.data.bones], 'actions':[(a.name,list(a.frame_range)) for a in bpy.data.actions]}
pathlib.Path('F:/GitHub/project18buxiuxiuxian/tempassets/work/fbx-inspection.json').write_text(json.dumps(r,indent=2))
