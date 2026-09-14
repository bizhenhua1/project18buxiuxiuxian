extends SceneTree
const PALETTE=preload("res://scripts/world3d/skin_palette.gd")
func _initialize():call_deferred("run")
func collect(node:Node,out:Array):
 if node is MeshInstance3D and node.skin!=null:out.append(node)
 for child in node.get_children():collect(child,out)
func run():
 var specs:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/defense_sample.json")).enemies
 var weights_checked:=0
 for spec in specs:
  var actor=load("res://assets/characters3d/"+spec.model).instantiate();root.add_child(actor)
  var meshes:Array=[];collect(actor,meshes)
  for node in meshes:
   var result:Dictionary=PALETTE.compact(node.mesh,node.skin)
   assert(not result.has("skipped"))
   assert(PALETTE.compact(node.mesh,node.skin).mesh==result.mesh,"Repeated models must share one remap")
   for surface in node.mesh.get_surface_count():
    var original:Dictionary=RenderingServer.mesh_get_surface(node.mesh.get_rid(),surface)
    var converted:Dictionary=RenderingServer.mesh_get_surface(result.mesh.get_rid(),surface)
    for field in ["vertex_data","attribute_data","index_data","format","vertex_count","index_count","aabb","uv_scale"]:assert(original.get(field)==converted.get(field),"Raw geometry changed: "+field)
    assert(original.get("lods",[])==converted.get("lods",[]),"All imported LODs must survive")
    var before:Array=node.mesh.surface_get_arrays(surface);var after:Array=result.mesh.surface_get_arrays(surface)
    assert(before[Mesh.ARRAY_WEIGHTS]==after[Mesh.ARRAY_WEIGHTS])
    for i in before[Mesh.ARRAY_BONES].size():
     if before[Mesh.ARRAY_WEIGHTS][i]<=0:continue
     var old:int=before[Mesh.ARRAY_BONES][i];var new_index:int=after[Mesh.ARRAY_BONES][i]
     assert(node.skin.get_bind_name(old)==result.skin.get_bind_name(new_index))
     assert(node.skin.get_bind_bone(old)==result.skin.get_bind_bone(new_index))
     assert(node.skin.get_bind_pose(old)==result.skin.get_bind_pose(new_index))
     weights_checked+=1
   print("SKIN_PALETTE ",spec.model," binds=",node.skin.get_bind_count()," -> ",result.skin.get_bind_count())
  actor.queue_free();await process_frame
 print("WORLD3D_SKIN_PALETTE_PASS positive weights=",weights_checked," exact bind targets/transforms, compressed geometry and LODs")
 quit()
