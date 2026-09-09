extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(64,64)
 var node=MultiMeshInstance2D.new();root.add_child(node)
 var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_2D;mm.use_custom_data=true;mm.mesh=QuadMesh.new();mm.mesh.size=Vector2(64,64);mm.instance_count=1;node.multimesh=mm
 mm.set_instance_transform_2d(0,Transform2D(0,Vector2(32,32)))
 var mat=ShaderMaterial.new();mat.shader=Shader.new()
 mat.shader.code="shader_type canvas_item; render_mode unshaded; uniform float expected; varying float val; void vertex(){val=INSTANCE_CUSTOM.x;} void fragment(){COLOR=vec4(.5+(val-expected),.5,.5,1);}"
 node.material=mat
 for v in [26.123,600.123,2000.123]:
  mm.set_instance_custom_data(0,Color(v,0,0,0));mat.set_shader_parameter("expected",v)
  await process_frame;await RenderingServer.frame_post_draw
  var pixel=root.get_texture().get_image().get_pixel(32,32)
  print("GPU_CUSTOM_PRECISION value=",v," error=",pixel.r-.5)
 # Same precision route used by ForestBatch: exact index + 32-bit relative position.
 mat.shader.code="shader_type canvas_item; render_mode unshaded; uniform vec2 dynamic_positions[256]; uniform float expected; varying float val; void vertex(){val=dynamic_positions[int(INSTANCE_CUSTOM.x)].x;} void fragment(){COLOR=vec4(.5+(val-expected)*10.0,.5,.5,1);}"
 var positions=PackedVector2Array();positions.resize(256)
 for distance in [0.0,600.0,2000.0,10000.0]:
  positions[0]=Vector2(distance+26.123,0)-Vector2(distance,0)
  mm.set_instance_custom_data(0,Color(0,0,0,0));mat.set_shader_parameter("dynamic_positions",positions);mat.set_shader_parameter("expected",positions[0].x)
  await process_frame;await RenderingServer.frame_post_draw
  var pixel=root.get_texture().get_image().get_pixel(32,32)
  assert(absf(pixel.r-.5)<.005)
  print("GPU_POSITION_PASS distance=",distance," error<0.0005")
 quit()
