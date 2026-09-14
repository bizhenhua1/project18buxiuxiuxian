extends SceneTree
func _initialize():call_deferred("run")
func scan(node:Node,meshes:Array,attachments:Array):
 if node is MeshInstance3D:meshes.append(node)
 if node is BoneAttachment3D:attachments.append(node)
 for child in node.get_children():scan(child,meshes,attachments)
func run():
 var rows:Array=[]
 var specs:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/defense_sample.json")).enemies
 for spec in specs:
  var actor=load("res://scripts/world3d/actor.gd").new();root.add_child(actor);actor.setup(spec.model)
  var meshes:Array=[];var attachments:Array=[];scan(actor.body,meshes,attachments)
  var used:Dictionary={};var skins:Dictionary={};var missing:=0;var vertices:=0;var influences:=0
  for mesh in meshes:
   if mesh.skin==null:missing+=1;continue
   skins[mesh.skin.get_instance_id()]=mesh.skin.get_bind_count()
   for surface in mesh.mesh.get_surface_count():
    var arrays:Array=mesh.mesh.surface_get_arrays(surface)
    vertices+=arrays[Mesh.ARRAY_VERTEX].size()
    var bones=arrays[Mesh.ARRAY_BONES];var weights=arrays[Mesh.ARRAY_WEIGHTS]
    if bones==null or weights==null:continue
    for i in bones.size():
     if weights[i]<=0:continue
     influences+=1
     var bind:int=bones[i];var name:StringName=mesh.skin.get_bind_name(bind)
     var bone:int=actor.rig.find_bone(name) if not name.is_empty() else mesh.skin.get_bind_bone(bind)
     assert(bone>=0 and bone<actor.rig.get_bone_count())
     used[bone]=true
  var closure:Dictionary=used.duplicate()
  for attachment in attachments:
   var bone:int=actor.rig.find_bone(attachment.bone_name)
   if bone>=0:closure[bone]=true
  for key in closure.keys():
   var parent:int=actor.rig.get_bone_parent(key)
   while parent>=0:
    closure[parent]=true;parent=actor.rig.get_bone_parent(parent)
  var palette:=0
  for count in skins.values():palette+=count
  var row={"model":spec.model,"skeleton_bones":actor.rig.get_bone_count(),"weighted_bones":used.size(),"weighted_and_attachment_ancestors":closure.size(),"unique_skins":skins.size(),"total_skin_bind_slots":palette,"meshes":meshes.size(),"meshes_without_skin":missing,"vertices":vertices,"positive_influences":influences,"retarget_evaluated":actor.retarget.evaluation_bones.size()}
  rows.append(row);print("SKIN_USAGE ",JSON.stringify(row))
  actor.queue_free();await process_frame
 var file:=FileAccess.open("res://../tempassets/work/world3d-skin-usage.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(rows,"  "));print("WORLD3D_SKIN_USAGE_AUDIT_DONE")
 quit()
