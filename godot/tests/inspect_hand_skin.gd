extends SceneTree
var actor
func _initialize():call_deferred("run")
func run():
 actor=load("res://scripts/world3d/allied_actor.gd").new();root.add_child(actor);actor.setup("gardener-kitty-dada.glb");actor.refresh_equipment();actor.play("idle");actor.retarget.apply(.5)
 if "--fingers-rest" in OS.get_cmdline_user_args():
  for i in actor.rig.get_bone_count():
   if "指" in actor.rig.get_bone_name(i):actor.rig.set_bone_pose_rotation(i,actor.rig.get_bone_rest(i).basis.get_rotation_quaternion())
 await process_frame
 scan(actor.body)
 quit()
func scan(node:Node):
 if node is MeshInstance3D and node.skin:
  var transforms:Array=[];var names:Array=[]
  for bind in node.skin.get_bind_count():
   var idx:int=actor.rig.find_bone(node.skin.get_bind_name(bind))
   if idx<0:idx=node.skin.get_bind_bone(bind)
   if actor.rig.get_bone_name(idx) in ["手首.R","小指１.R","中指３.R"]:print("BIND ",actor.rig.get_bone_name(idx)," ",actor.rig.get_bone_global_rest(idx)*node.skin.get_bind_pose(bind))
   names.append(actor.rig.get_bone_name(idx));transforms.append(actor.rig.get_bone_global_pose(idx)*node.skin.get_bind_pose(bind))
  var worst:=0.0;var note:=""
  for surface in node.mesh.get_surface_count():
   var arrays=node.mesh.surface_get_arrays(surface);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var bones=arrays[Mesh.ARRAY_BONES];var weights=arrays[Mesh.ARRAY_WEIGHTS];var posed:=PackedVector3Array();var labels:Array=[]
   if bones==null:continue
   var count:int=bones.size()/vertices.size()
   for v in vertices.size():
    var p:=Vector3.ZERO;var label:=""
    for j in count:
     var b:int=bones[v*count+j];var w:float=weights[v*count+j];p+=(transforms[b]*vertices[v])*w
     if w>.1:label+=str(names[b])+":"+str(snappedf(w,.01))+" "
    posed.append(p);labels.append(label)
   var indices=arrays[Mesh.ARRAY_INDEX]
   for t in range(0,indices.size(),3):
    for pair in [[0,1],[1,2],[2,0]]:
     var a:int=indices[t+pair[0]];var b:int=indices[t+pair[1]]
     if not ("指" in labels[a] or "手首" in labels[a]):continue
     var rest:float=vertices[a].distance_to(vertices[b]);var stretch:float=posed[a].distance_to(posed[b])/maxf(rest,.001)
     if stretch>worst:worst=stretch;note=labels[a]+" -> "+labels[b]+" rest="+str(rest)+" point="+str(vertices[a])+" pinky="+str(actor.rig.get_bone_global_rest(actor.rig.find_bone("小指１.R")).origin)
  print("STRETCH ",worst," ",note)
 for c in node.get_children():scan(c)



