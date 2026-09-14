extends SceneTree
func _initialize():call_deferred("run")
func run():
 var bodies:Array=[];var baked:Array=[]
 var box:=BoxMesh.new();box.size=Vector3(1,2,1)
 var source:=ArrayMesh.new();source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,box.surface_get_arrays(0),[],{5.0:PackedInt32Array([0,1,2])})
 for i in 2:
  var body:=Node3D.new();root.add_child(body);bodies.append(body)
  body.position=Vector3(5*i,8*i,-3*i);body.rotation.x=PI*.5*i;body.scale=Vector3.ONE*(1+i)
  var mesh:=MeshInstance3D.new();mesh.mesh=source;body.add_child(mesh);mesh.position.y=1
  var mount:=BoneAttachment3D.new();body.add_child(mount)
  var weapon:=MeshInstance3D.new();weapon.mesh=source;mount.add_child(weapon);weapon.position.y=20
  var result:Dictionary=preload("res://scripts/world3d/rest_height.gd").bake(body)
  assert(is_equal_approx(result.bottom,0) and is_equal_approx(result.top,2))
  baked.append(mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2])
  assert(mesh.mesh!=source,"Do not mutate imported/shared source meshes")
  assert(weapon.mesh==source and result.mesh_count==1,"Weapons must not shift the body height range")
  var original_lods:Array=RenderingServer.mesh_get_surface(source.get_rid(),0).lods
  var copied_lods:Array=RenderingServer.mesh_get_surface(mesh.mesh.get_rid(),0).lods
  assert(original_lods==copied_lods,"Preserve source LOD thresholds and topology")
 assert(baked[0]==baked[1],"Translation, scale and crawl rotation must not change rest height")
 for model in ["gardener-kitty-dada.glb","isabella.glb"]:
  var actor=preload("res://scripts/world3d/allied_actor.gd").new();root.add_child(actor);actor.setup(model);actor.refresh_equipment_if_changed()
  var meshes:Array=[];preload("res://scripts/world3d/rest_height.gd").collect(actor.body,meshes)
  var originals:Array=meshes.map(func(mesh):return mesh.mesh)
  var result:Dictionary=preload("res://scripts/world3d/rest_height.gd").bake(actor.body)
  assert(result.mesh_count>0 and result.top>result.bottom)
  var lod_count:=0
  for i in meshes.size():
   assert(meshes[i].mesh!=originals[i])
   for surface in originals[i].get_surface_count():
    var before:Array=originals[i].surface_get_arrays(surface)
    var after:Array=meshes[i].mesh.surface_get_arrays(surface)
    assert(before[Mesh.ARRAY_BONES]==after[Mesh.ARRAY_BONES] and before[Mesh.ARRAY_WEIGHTS]==after[Mesh.ARRAY_WEIGHTS])
    assert(after[Mesh.ARRAY_TEX_UV2].size()==after[Mesh.ARRAY_VERTEX].size())
    var original_lods:Array=RenderingServer.mesh_get_surface(originals[i].get_rid(),surface).get("lods",[])
    var copied_lods:Array=RenderingServer.mesh_get_surface(meshes[i].mesh.get_rid(),surface).get("lods",[])
    assert(original_lods==copied_lods);lod_count+=copied_lods.size()
  print("REST_HEIGHT_MODEL ",model," meshes=",meshes.size()," preserved_lods=",lod_count)
  actor.free()
 print("WORLD3D_REST_HEIGHT_PASS body-local reference, transform invariance, source isolation")
 quit()
