extends SceneTree
# Offline base-LOD skinning diagnostic. Does not include shader projection,
# terrain slope; low opaque vertices are candidates, not full pixel errors.
func _initialize():call_deferred("run")
func collect(node:Node,out:Array):
 if node is MeshInstance3D and node.skin!=null:out.append(node)
 for child in node.get_children():collect(child,out)
func run():
 var death_id:=""
 var cloth_support:bool="--cloth-support" in OS.get_cmdline_user_args()
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--death="):death_id=argument.get_slice("=",1)
 var specs:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/defense_sample.json")).enemies
 var report:Array=[]
 for spec in specs:
  var actor=preload("res://scripts/world3d/actor.gd").new();root.add_child(actor);actor.setup(spec.model)
  if not death_id.is_empty():
   var found:=false
   for entry in actor.catalog.clips:
    if entry.id==death_id:actor.library.clips.death=entry;actor.cache.erase("death");found=true;break
   assert(found,"Requested death clip missing")
  var meshes:Array=[];collect(actor.body,meshes)
  actor.play("death")
  var duration:float=(actor.library.clips.death.frames-1)/actor.library.clips.death.fps
  for fraction in [.0,.5,.75,1.0]:
   actor.retarget.apply(duration*fraction)
   # Reset unmapped clothing before each independent sampled pose.
   if cloth_support:
    for bone in actor.rig.get_bone_count():
     if actor.rig.get_bone_name(bone).begins_with("sk_"):actor.rig.set_bone_pose_rotation(bone,actor.rig.get_bone_rest(bone).basis.get_rotation_quaternion())
    preload("res://tests/cloth_ground_fit.gd").apply(actor.rig)
   var parts:Array=[]
   for node in meshes:
    var transforms:Array[Transform3D]=[]
    for bind in node.skin.get_bind_count():
     var bone:int=actor.rig.find_bone(node.skin.get_bind_name(bind)) if node.skin.get_bind_name(bind)!=&"" else node.skin.get_bind_bone(bind)
     assert(bone>=0,"Unresolved skin bind")
     transforms.append(actor.rig.global_transform*actor.rig.get_bone_global_pose(bone)*node.skin.get_bind_pose(bind))
    for surface in node.mesh.get_surface_count():
     var arrays:Array=node.mesh.surface_get_arrays(surface)
     var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
     var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
     var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
     var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
     var material=node.get_active_material(surface)
     var texture:Texture2D=material.get_shader_parameter("base_texture")
     var art:Image=texture.get_image() if texture else null
     var color:Color=material.get_shader_parameter("base_color")
     var influences:int=bones.size()/vertices.size()
     assert(influences in [4,8])
     var lowest:=INF;var below:=0;var severe:=0;var opaque:=0;var low_bones:Dictionary={}
     for vertex in vertices.size():
      var alpha:float=color.a
      if art and not uv.is_empty():
       var texel:=Vector2i(clampi(int(fposmod(uv[vertex].x,1.0)*art.get_width()),0,art.get_width()-1),clampi(int(fposmod(uv[vertex].y,1.0)*art.get_height()),0,art.get_height()-1))
       alpha*=art.get_pixelv(texel).a
      if alpha<.3:continue
      opaque+=1
      var p:=Vector3.ZERO
      for influence in influences:
       var k:int=vertex*influences+influence
       if weights[k]>0:p+=(transforms[bones[k]]*vertices[vertex])*weights[k]
      lowest=minf(lowest,p.y)
      if p.y<-.02:below+=1
      if p.y<-.1:
       severe+=1
       for influence in influences:
        var k:int=vertex*influences+influence
        if weights[k]<=0:continue
        var bind:int=bones[k]
        var name:String=String(node.skin.get_bind_name(bind))
        if name.is_empty():name=actor.rig.get_bone_name(node.skin.get_bind_bone(bind))
        low_bones[name]=float(low_bones.get(name,0.0))+weights[k]
     if opaque>0:parts.append({"mesh":node.name,"surface":surface,"vertices":vertices.size(),"opaque_vertices":opaque,"lowest":lowest,"below_2cm":below,"below_10cm":severe,"low_vertex_weight_by_bone":low_bones})
   var hip:int=actor.rig.find_bone("下半身")
   var head:int=actor.rig.find_bone("頭")
   var hip_world:Vector3=actor.rig.global_transform*actor.rig.get_bone_global_pose(hip).origin
   var head_world:Vector3=actor.rig.global_transform*actor.rig.get_bone_global_pose(head).origin
   var rest_hip:Vector3=actor.rig.global_transform*actor.rig.get_bone_global_rest(hip).origin
   var rest_head:Vector3=actor.rig.global_transform*actor.rig.get_bone_global_rest(head).origin
   var entry:Dictionary={"model":spec.model,"fraction":fraction,"parts":parts,"hip_height_ratio":hip_world.y/rest_hip.y,"head_height_ratio":head_world.y/rest_head.y}
   report.append(entry)
   var lowest:=INF;var below:=0;var severe:=0
   for part in parts:lowest=minf(lowest,part.lowest);below+=part.below_2cm;severe+=part.below_10cm
   print("CORPSE_SURFACE ",spec.model," t=",fraction," min=",lowest," below2cm=",below," below10cm=",severe," hip_ratio=",entry.hip_height_ratio," head_ratio=",entry.head_height_ratio)
  actor.queue_free();await process_frame
 assert(not report.is_empty())
 var suffix:String="-"+death_id if not death_id.is_empty() else ""
 if cloth_support:suffix+="-cloth-support"
 FileAccess.open("res://../tempassets/work/world3d-corpse-surfaces"+suffix+".json",FileAccess.WRITE).store_string(JSON.stringify({"death_override":death_id,"scope":"Base LOD skinned vertices against flat y=0; nearest UV alpha >= .3. Triangle interiors, filtered alpha, terrain slope and portrait projection excluded; diagnostics only","samples":report},"  "))
 quit()
