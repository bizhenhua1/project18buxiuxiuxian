extends SceneTree
func _initialize():call_deferred("run")
func run():
 if DisplayServer.get_name()=="headless":
  push_error("Mist blending validation requires an actual GPU renderer");quit(1);return
 root.size=Vector2i(320,240)
 var scene:=Node3D.new();root.add_child(scene)
 var camera:=Camera3D.new();scene.add_child(camera);camera.current=true
 var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color.BLACK;scene.add_child(environment)
 var shader:=Shader.new();shader.code=FileAccess.get_file_as_string("res://scripts/world3d/mist.gdshader").get_slice("void fragment()",0)+"void fragment(){ALBEDO=tint.rgb;ALPHA=.5;}"
 var material:=ShaderMaterial.new();material.shader=shader
 var mesh:=QuadMesh.new();mesh.size=Vector2(2,2);mesh.material=material
 var batch:=MultiMesh.new();batch.transform_format=MultiMesh.TRANSFORM_3D;batch.use_custom_data=true;batch.use_colors=true;batch.mesh=mesh;batch.instance_count=2
 var node:=MultiMeshInstance3D.new();node.multimesh=batch;scene.add_child(node)
 for heading in [0.0,1.2,-.7]:
  var axis:=Vector2(sin(heading),cos(heading))
  var patches:Array=[{"position":axis*40,"color":Color.RED},{"position":axis*80,"color":Color.BLUE}]
  preload("res://scripts/world3d/scenery.gd").order_mist(patches,heading)
  assert(patches[0].color==Color.BLUE)
  camera.rotation.y=-heading;material.set_shader_parameter("heading",heading)
  for i in patches.size():
   var p:Vector2=patches[i].position
   batch.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(p.x,0,-p.y)/20))
   batch.set_instance_custom_data(i,Color(.5,.5,1,1));batch.set_instance_color(i,patches[i].color)
  for i in 3:await process_frame
  await RenderingServer.frame_post_draw
  var pixel:Color=root.get_texture().get_image().get_pixel(160,120)
  assert(pixel.r>pixel.b+.15 and pixel.b>.15,"Far blue mist must blend before near red mist")
 print("WORLD3D_MIST_ORDER_PASS GPU far-to-near blending at three headings")
 quit()
