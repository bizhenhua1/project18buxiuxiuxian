extends SceneTree
func _initialize():call_deferred("run")
func run():
 if DisplayServer.get_name()=="headless":quit(1);return
 root.size=Vector2i(320,240)
 var scene:=Node3D.new();root.add_child(scene)
 var camera:=Camera3D.new();scene.add_child(camera);camera.current=true
 var curve:Array=[[0,.7,1.3,.1],[.2,.5,2.0,.4]]
 var data:Dictionary=preload("res://scripts/spaces/epic181_gpu_curves.gd").prepare(curve,[[[1,1,1,1]],[[1,1,1,1]]])
 var shader:=Shader.new()
 shader.code=FileAccess.get_file_as_string("res://shaders/epic181_particle.gdshader").get_slice("void vertex()",0)+"uniform float expected;varying float error;void vertex(){float t=INSTANCE_CUSTOM.g;float r=INSTANCE_CUSTOM.b;float s=max(.001,INSTANCE_CUSTOM.a*mix(curve_at(t,curve_counts.x,0).r,curve_at(t,curve_counts.y,0).g,r));error=abs(s-expected)*10000.0;}void fragment(){ALBEDO=vec3(error,0,0);ALPHA=1.0;}"
 if "--uniform-input" in OS.get_cmdline_user_args():
  shader.code=shader.code.replace("uniform float expected;","uniform float expected;uniform vec3 raw_input;").replace("INSTANCE_CUSTOM.g","raw_input.x").replace("INSTANCE_CUSTOM.b","raw_input.y").replace("INSTANCE_CUSTOM.a","raw_input.z")
 if "--residual-input" in OS.get_cmdline_user_args():
  shader.code=shader.code.replace("uniform float expected;","uniform float expected;uniform vec3 raw_input;").replace("INSTANCE_CUSTOM.g","(INSTANCE_CUSTOM.g+INSTANCE_CUSTOM.r/2048.0)").replace("INSTANCE_CUSTOM.b","raw_input.y").replace("INSTANCE_CUSTOM.a","raw_input.z")
 var mat:=ShaderMaterial.new();mat.shader=shader;mat.set_shader_parameter("particle_curves",data.texture);mat.set_shader_parameter("curve_counts",data.counts)
 var mesh:=QuadMesh.new();mesh.material=mat
 var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_custom_data=true;mm.mesh=mesh;mm.instance_count=1
 mm.set_instance_transform(0,Transform3D(Basis.IDENTITY,Vector3(0,0,-2)))
 var node:=MultiMeshInstance3D.new();node.multimesh=mm;scene.add_child(node)
 var fx=preload("res://scripts/spaces/epic181_effect.gd").new()
 var worst:=0.0
 for sample in [Vector3(.1,.2,.3),Vector3(.35,.85,2.5),Vector3(.91,.51,.025),Vector3(.49,.21,5.3)]:
  mm.set_instance_custom_data(0,Color(0,sample.x,sample.y,sample.z))
  if "--residual-input" in OS.get_cmdline_user_args():
   var half:=PackedByteArray([0,0]);half.encode_half(0,sample.x)
   var high:float=half.decode_half(0)
   mm.set_instance_custom_data(0,Color((sample.x-high)*2048.0,high,0,0))
  mat.set_shader_parameter("raw_input",sample)
  mat.set_shader_parameter("expected",maxf(.001,sample.z*fx.sample(curve,sample.x,sample.y)))
  for i in 3:await process_frame
  await RenderingServer.frame_post_draw
  var value:float=root.get_texture().get_image().get_pixel(160,120).r
  worst=maxf(worst,value);print("CURVE_VALUE_ERROR_X10000 ",sample," ",value)
 fx.free();scene.queue_free();await process_frame
 if worst>.025:push_error("GPU size values differ");quit(1);return
 print("EPIC_GPU_CURVE_VALUES_PASS");quit()
