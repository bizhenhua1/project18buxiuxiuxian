"""Retarget exported UE animations onto the supplied PMX deformation rig."""
import bpy,math,json,pathlib
from mathutils import Matrix,Vector
BASE=pathlib.Path('F:/GitHub/project18buxiuxiuxian');WORK=BASE/'tempassets/work'
OUT=BASE/'art/3d/seer';OUT.mkdir(parents=True,exist_ok=True)
GAME=BASE/'godot/assets/characters3d';GAME.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(WORK/'seer-source.blend'))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
mesh=next(o for o in bpy.context.scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' for m in o.modifiers))
for ob in list(bpy.context.scene.objects):
    if ob not in (rig,mesh):bpy.data.objects.remove(ob,do_unlink=True)
rig.parent=None;mesh.parent=rig;rig.name='Seer_Rig';mesh.name='Seer_Body'
for b in rig.pose.bones:
    for c in list(b.constraints):b.constraints.remove(c)
    b.rotation_mode='QUATERNION';b.matrix_basis=Matrix.Identity(4)
# Preserve the original UV textures, replacing MMD-only shaders with exportable materials.
material_report=[]
for mat in mesh.data.materials:
    old=mat.node_tree.nodes.get('mmd_base_tex') if mat.use_nodes else None
    im=old.image if old else None
    material_report.append({'material':mat.name,'texture':im.name if im else None})
    mat.use_nodes=True;nodes=mat.node_tree.nodes;nodes.clear()
    bs=nodes.new('ShaderNodeBsdfPrincipled');bs.inputs['Roughness'].default_value=.86;bs.inputs['Specular IOR Level'].default_value=.15
    bs.inputs['Emission Strength'].default_value=.22
    output=nodes.new('ShaderNodeOutputMaterial');mat.node_tree.links.new(bs.outputs['BSDF'],output.inputs['Surface'])
    if im:
        tex=nodes.new('ShaderNodeTexImage');tex.image=im
        for socket in ['Base Color','Emission Color']:mat.node_tree.links.new(tex.outputs['Color'],bs.inputs[socket])
        mat.node_tree.links.new(tex.outputs['Alpha'],bs.inputs['Alpha'])
    mat.use_backface_culling=False
mapping={'腰':'pelvis','下半身':'pelvis','上半身':'spine_01','上半身2':'spine_02','上半身3':'spine_03','首':'neck_01','頭':'head'}
for suffix,side in [('L','l'),('R','r')]:
    for target,source in [('肩','clavicle'),('腕','upperarm'),('ひじ','lowerarm'),('手首','hand'),('足','thigh'),('ひざ','calf'),('足首','foot'),('足D','thigh'),('ひざD','calf'),('足首D','foot'),('足先EX','ball')]:mapping[target+'.'+suffix]=source+'_'+side
    for finger,jp in [('thumb','親指'),('index','人指'),('middle','中指'),('ring','薬指'),('pinky','小指')]:
        for i in range(3):mapping[jp+chr(0xff10+i+(0 if finger=='thumb' else 1))+'.'+suffix]=f'{finger}_{i+1:02}_{side}'
rest={b.name:b.matrix_local.copy() for b in rig.data.bones}
ordered=[]
def visit(b):
    ordered.append(b.name)
    for c in b.children:visit(c)
for b in rig.data.bones:
    if b.parent is None:visit(b)
rig.animation_data_clear();rig.animation_data_create()
clip_report=[]
for fbx in sorted((WORK/'fbx').glob('EM_*.fbx')):
    before=set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=str(fbx),use_anim=True)
    added=set(bpy.data.objects)-before
    source=next(o for o in added if o.type=='ARMATURE')
    action=source.animation_data.action
    start,end=map(int,action.frame_range)
    src_rest={b.name:b.matrix_local.copy() for b in source.data.bones}
    scale=rest['腰'].translation.z/(source.matrix_world@src_rest['pelvis'].translation).z
    dest=bpy.data.actions.new(fbx.stem);dest.use_fake_user=True
    rig.animation_data.action=dest
    root_name='全ての親'
    for frame in range(start,end+1):
        bpy.context.scene.frame_set(frame)
        deltas={}
        for name in set(mapping.values()):
            if name in source.pose.bones:
                deltas[name]=(source.matrix_world@source.pose.bones[name].matrix).to_quaternion() @ (source.matrix_world@src_rest[name]).to_quaternion().inverted()
        hip_delta=((source.matrix_world@source.pose.bones['pelvis'].matrix).translation-(source.matrix_world@src_rest['pelvis']).translation)*scale
        poses={}
        for name in ordered:
            b=rig.data.bones[name];base=poses[b.parent.name]@rest[b.parent.name].inverted()@rest[name] if b.parent else rest[name].copy()
            desired=base.copy()
            if name in mapping and mapping[name] in deltas:
                desired=(deltas[mapping[name]]@rest[name].to_quaternion()).to_matrix().to_4x4();desired.translation=base.translation
            if name==root_name:desired.translation+=hip_delta
            pb=rig.pose.bones[name];pb.matrix_basis=base.inverted()@desired;poses[name]=desired
        # Correct leg-length differences using the lowest ankle, retaining the PMX contact height.
        if fbx.stem!='EM_Death':
            correction=min(poses['足首D.'+s].translation.z-rest['足首D.'+s].translation.z for s in ['L','R'])
            rig.pose.bones[root_name].location+=rest[root_name].to_3x3().inverted()@Vector((0,0,-correction))
        for name in ordered:
            pb=rig.pose.bones[name]
            pb.keyframe_insert('rotation_quaternion',frame=frame-start+1,group=name)
            if name==root_name:pb.keyframe_insert('location',frame=frame-start+1,group=name)
    track=rig.animation_data.nla_tracks.new();track.name=fbx.stem;track.strips.new(fbx.stem,1,dest);track.mute=True
    clip_report.append({'name':fbx.stem,'frames':end-start+1,'fps':bpy.context.scene.render.fps})
    for ob in added:bpy.data.objects.remove(ob,do_unlink=True)
    print('RETARGETED',fbx.stem,flush=True)
rig.animation_data.action=bpy.data.actions.get('EM_Idle');bpy.context.scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);mesh.select_set(True);bpy.context.view_layer.objects.active=rig
rig.animation_data.action=None
for t in rig.animation_data.nla_tracks:t.mute=False
bpy.ops.export_scene.gltf(filepath=str(GAME/'seer-treading-snow.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_nla_strips=True,export_skins=True,export_morph=False)
for t in rig.animation_data.nla_tracks:t.mute=True
rig.animation_data.action=bpy.data.actions.get('EM_Idle');bpy.context.scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'seer-animated.blend'))
(OUT/'manifest.json').write_text(json.dumps({'materials':material_report,'bones':len(rest),'vertices':len(mesh.data.vertices),'triangles':sum(len(p.vertices)-2 for p in mesh.data.polygons),'clips':clip_report},ensure_ascii=False,indent=2),encoding='utf8')
print('SEER_BUILD_COMPLETE',flush=True)
