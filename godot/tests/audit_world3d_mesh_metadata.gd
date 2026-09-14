extends SceneTree
func _initialize():call_deferred("run")
func scan(node:Node):
 if node is MeshInstance3D and node.mesh is ArrayMesh:
  var mesh:ArrayMesh=node.mesh
  print("MESH_METADATA surfaces=",mesh.get_surface_count()," blend_shapes=",mesh.get_blend_shape_count())
  if mesh.get_surface_count()>0:
   var first:Dictionary=RenderingServer.mesh_get_surface(mesh.get_rid(),0)
   print("RAW_SKIN stride=",first.skin_data.size()/first.vertex_count," bounds type=",type_string(typeof(first.bone_aabbs))," bounds_count=",first.bone_aabbs.size())
   var copy:=ArrayMesh.new();copy.set("_surfaces",mesh.get("_surfaces"))
   assert(copy.get_surface_count()==mesh.get_surface_count(),"Raw surface roundtrip must retain ArrayMesh metadata")
  for surface in mesh.get_surface_count():
   var raw:Dictionary=RenderingServer.mesh_get_surface(mesh.get_rid(),surface)
   print("SURFACE ",surface," format=",mesh.surface_get_format(surface)," metadata_keys=",raw.keys()," lods=",raw.get("lods",[]).size())
 for child in node.get_children():scan(child)
func run():
 var specs:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/defense_sample.json")).enemies
 for spec in specs:
  print("MODEL ",spec.model)
  var node=load("res://assets/characters3d/"+spec.model).instantiate();root.add_child(node);scan(node);node.queue_free();await process_frame
 quit()
