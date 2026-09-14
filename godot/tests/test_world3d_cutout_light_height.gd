extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(320,240)
 var scene:=Node3D.new();root.add_child(scene)
 var camera:=Camera3D.new();scene.add_child(camera);camera.current=true
 var shader:=Shader.new()
 # Keep the production vertex path and expose its light sampling height.
 shader.code=FileAccess.get_file_as_string("res://scripts/world3d/cutout.gdshader").get_slice("void fragment()",0)+"void fragment(){ALBEDO=vec3(.5+point.y/100.0,0,0);ALPHA=1.0;}"
 var material:=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("terrain_amplitude",0.0)
 var mesh:=QuadMesh.new();mesh.size=Vector2(2,2);mesh.material=material
 var batch:=MultiMesh.new();batch.transform_format=MultiMesh.TRANSFORM_3D;batch.use_custom_data=true;batch.mesh=mesh;batch.instance_count=1
 batch.set_instance_custom_data(0,Color(.5,.5,1,0))
 var node:=MultiMeshInstance3D.new();node.multimesh=batch;scene.add_child(node)
 var count:=0
 for altitude in [0.0,.4]:
  batch.set_instance_transform(0,Transform3D(Basis.IDENTITY,Vector3(0,altitude,-2)))
  for i in 3:await process_frame
  await RenderingServer.frame_post_draw
  var image:Image=root.get_texture().get_image()
  for offset in [-.25,.25]:
   var pixel:=Vector2i(camera.unproject_position(Vector3(0,altitude+offset,-2)))
   var world:Vector3=camera.project_position(Vector2(pixel)+Vector2(.5,.5),2)
   var expected:float=.5+world.y*.2
   assert(absf(image.get_pixelv(pixel).r-expected)<.012,"Signed artwork height and sprite altitude must reach the lighting field")
   count+=1
 print("WORLD3D_CUTOUT_LIGHT_HEIGHT_PASS signed and elevated samples=",count)
 quit()
