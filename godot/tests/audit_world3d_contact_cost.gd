extends SceneTree
func _initialize():call_deferred("run")
func run():
 if DisplayServer.get_name()=="headless":push_error("Distance audit requires actual MultiMesh transform readback");quit(1);return
 var app=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(app)
 while not app.stage or not app.stage.ready_stage:await process_frame
 var stage=app.stage;stage.set_process(false);stage._process(0)
 var counts:Dictionary={};var vertices:=0;var triangles:=0
 for mesh in stage.scenery.mesh_cache.values():
  var arrays:Array=mesh.surface_get_arrays(0)
  counts[mesh]=Vector2i(arrays[Mesh.ARRAY_VERTEX].size(),arrays[Mesh.ARRAY_INDEX].size()/3)
  vertices+=counts[mesh].x;triangles+=counts[mesh].y
 var visible_vertices:=0;var visible_triangles:=0;var visible_instances:=0
 var distance_bands:Dictionary={"near_30m":{"instances":0,"triangles":0},"middle_60m":{"instances":0,"triangles":0},"far":{"instances":0,"triangles":0}}
 for chunk in stage.scenery.chunks:
  if not chunk.visible:continue
  var mm:MultiMesh=chunk.multimesh
  visible_vertices+=counts[mm.mesh].x*mm.instance_count
  visible_triangles+=counts[mm.mesh].y*mm.instance_count
  visible_instances+=mm.instance_count
  # Per-instance origins, not whole-batch centres, determine whether distant LOD
  # could plausibly remove work. This is an opportunity estimate, not an LOD.
  for i in mm.instance_count:
   var position:Vector3=mm.get_instance_transform(i).origin
   var depth:float=ForestRoute.to_camera(Vector2(position.x,-position.z)*20,stage.bridge.camera_world,stage.bridge.heading).y/20
   var band:String="near_30m" if depth<30 else "middle_60m" if depth<60 else "far"
   distance_bands[band].instances+=1;distance_bands[band].triangles+=counts[mm.mesh].y
 if counts.is_empty() or visible_instances==0:push_error("No valid scenery geometry to audit");quit(1);return
 var result:Dictionary={"theme":stage.theme_key,"bounded":stage.scenery.bounded_ground,"cached_meshes":counts.size(),"cache_vertices":vertices,"cache_triangles":triangles,"visible_instances":visible_instances,"submitted_vertices":visible_vertices,"submitted_triangles":visible_triangles,"scope":"Coarse-visible static scenery batches; submitted geometry, not pixel-visible triangles or measured GPU time"}
 var suffix:=""
 result.distance_bands=distance_bands
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--tag="):suffix="-"+argument.get_slice("=",1)
 FileAccess.open("res://../tempassets/work/world3d-contact-cost-"+stage.theme_key+suffix+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("CONTACT_COST ",JSON.stringify(result));quit()
