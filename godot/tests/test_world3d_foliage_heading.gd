extends SceneTree
func _initialize():call_deferred("run")
func run():
 if DisplayServer.get_name()=="headless":
  push_error("GPU backend required for MultiMesh instance readback");quit(1);return
 var scene=load("res://scenes/world3d_stage.tscn").instantiate();root.add_child(scene)
 while not scene.ready_stage:await process_frame
 scene.set_process(false)
 var plants:Array=[]
 for sprite in scene.world.sprites:
  if scene.scenery.is_low_foliage(sprite.texture) and not sprite.has("plane_heading"):plants.append(sprite)
 assert(not plants.is_empty())
 var converted:Array=scene.scenery.route_shells(plants,scene.route_segment)
 for i in plants.size():
  assert(not plants[i].has("plane_heading"),"Legacy source dictionaries must remain unchanged")
  assert(converted[i].has("plane_heading"))
  assert(converted[i].position==plants[i].position)
  assert(is_equal_approx(converted[i].plane_heading,scene.route_segment.pose(converted[i].route_s,converted[i].get("route_branch",0)).heading))
 var covers:=0
 for chunk in scene.scenery.chunks:
  var material=chunk.multimesh.mesh.surface_get_material(0)
  if material.shader!=load("res://scripts/world3d/foliage_depth.gd").shader():continue
  for i in chunk.multimesh.instance_count:
   var custom:Color=chunk.multimesh.get_instance_custom_data(i)
   if absf(custom.b)<32:continue
   covers+=1
   assert(is_equal_approx(absf(custom.b),34),"Root grass must use a fixed plane, not the parent-screen clipping path")
   assert(Vector2(custom.r,custom.g).is_equal_approx(Vector2(.5,1)),"Root grass must have its own centred ground anchor")
   var position:Vector3=chunk.multimesh.get_instance_transform(i).origin
   assert(chunk.multimesh.custom_aabb.has_point(position),"Relocated root must remain inside its culling bounds")
 assert(covers>0)
 print("ROOT_COVER_FIXED_COUNT ",covers)
 print("FOLIAGE_HEADING_PASS fixed route-facing low plants=",plants.size()," source positions retained")
 quit()
