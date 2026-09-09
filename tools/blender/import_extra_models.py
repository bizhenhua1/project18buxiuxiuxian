import bpy,sys,pathlib,json
BASE=pathlib.Path('F:/GitHub/project18buxiuxiuxian');sys.path.insert(0,'C:/Users/admin/.local/share/blender-tools');import mmd_tools;mmd_tools.register()
for key,pattern in [('isabella','伊莎貝拉*/*/伊莎貝拉.pmx'),('joseph-summer','约瑟夫*/*/盛夏光影_形状変化_辅助骨.pmx'),('composer-reason','作曲家 澄明*/*/澄明 辅助骨.pmx'),('composer-george','作曲家——被遗忘*/*/被遗忘的乔治改——辅助骨.pmx')]:
 bpy.ops.wm.read_factory_settings(use_empty=True)
 pmx=next((BASE/'tempassets').glob(pattern));bpy.ops.mmd_tools.import_model(filepath=str(pmx),scale=.1)
 rigs=[o for o in bpy.context.scene.objects if o.type=='ARMATURE'];rig=rigs[0]
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' for m in o.modifiers)]
 for o in list(bpy.data.objects):
  if o not in [rig]+meshes:bpy.data.objects.remove(o,do_unlink=True)
 rig.parent=None;rig.name='Character_Rig';rig.animation_data_clear()
 for b in rig.pose.bones:
  for c in list(b.constraints):b.constraints.remove(c)
 for mesh in meshes:
  mesh.parent=rig
  for mat in mesh.data.materials:
   if not mat:continue
   old=mat.node_tree.nodes.get('mmd_base_tex') if mat.use_nodes else None;im=old.image if old else None
   mat.use_nodes=True;n=mat.node_tree.nodes;n.clear();bs=n.new('ShaderNodeBsdfPrincipled');bs.inputs['Roughness'].default_value=.85;bs.inputs['Emission Strength'].default_value=.12
   out=n.new('ShaderNodeOutputMaterial');mat.node_tree.links.new(bs.outputs['BSDF'],out.inputs['Surface'])
   if im:
    im.file_format='PNG';im.pack();tex=n.new('ShaderNodeTexImage');tex.image=im
    for socket in ['Base Color','Emission Color']:mat.node_tree.links.new(tex.outputs['Color'],bs.inputs[socket])
    mat.node_tree.links.new(tex.outputs['Alpha'],bs.inputs['Alpha'])
   mat.use_backface_culling=False
 bpy.ops.object.select_all(action='DESELECT')
 for o in [rig]+meshes:o.select_set(True)
 bpy.context.view_layer.objects.active=rig
 bpy.ops.export_scene.gltf(filepath=str(BASE/f'godot/assets/characters3d/{key}.glb'),export_format='GLB',use_selection=True,export_animations=False,export_morph=False)
 (BASE/f'tempassets/work/{key}-bones.json').write_text(json.dumps([b.name for b in rig.data.bones],ensure_ascii=False),encoding='utf-8')
 print('MODEL_DONE',key,flush=True)
