extends SceneTree
func _initialize():call_deferred("run")
func sample(pixel:Vector2i=Vector2i(160,120))->Color:
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 return root.get_texture().get_image().get_pixelv(pixel)
func run():
 root.size=Vector2i(320,240)
 var scene:=Node3D.new();root.add_child(scene)
 var camera:=Camera3D.new();scene.add_child(camera);camera.current=true
 var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;scene.add_child(environment)
 var bitmap:=Image.create(4,4,false,Image.FORMAT_RGBA8);bitmap.fill(Color(0,1,0,1))
 var material:=ShaderMaterial.new();material.shader=load("res://scripts/world3d/cutout.gdshader");material.set_shader_parameter("art",ImageTexture.create_from_image(bitmap));material.set_shader_parameter("lantern_enabled",false)
 var quad:=QuadMesh.new();quad.size=Vector2(2,2);quad.material=material
 var batch:=MultiMesh.new();batch.transform_format=MultiMesh.TRANSFORM_3D;batch.use_custom_data=true;batch.use_colors=true;batch.mesh=quad;batch.instance_count=1
 batch.set_instance_transform(0,Transform3D(Basis.IDENTITY,Vector3(0,0,-2)))
 batch.set_instance_custom_data(0,Color(.5,.5,1,0));batch.set_instance_color(0,Color.WHITE)
 var node:=MultiMeshInstance3D.new();node.multimesh=batch;scene.add_child(node)
 environment.environment.background_color=Color.BLACK;var black:=await sample()
 environment.environment.background_color=Color.WHITE;var white:=await sample()
 var coverage:=smoothstep(16.0,70.0,40.0)
 assert(absf((white.r-black.r)-(1-coverage))<.04,"Near cutout must blend with background, not become an opaque alpha-scissored silhouette")
 batch.set_instance_custom_data(0,Color(.5,.5,17,0))
 environment.environment.background_color=Color.BLACK;var shell_black:=await sample()
 environment.environment.background_color=Color.WHITE;var shell_white:=await sample()
 var shell_coverage:=smoothstep(18.0,95.0,40.0)
 assert(absf((shell_white.r-shell_black.r)-(1-shell_coverage))<.04,"Rock shells must use the formal longer near fade")
 batch.set_instance_custom_data(0,Color(.5,.5,2,.65))
 for side in [-.5,.5]:
  var point:Vector3=Vector3(0,0,-2)+Vector3(cos(.65),0,sin(.65))*side
  var pixel:=Vector2i(camera.unproject_position(point))
  environment.environment.background_color=Color.BLACK;var angled_black:=await sample(pixel)
  environment.environment.background_color=Color.WHITE;var angled_white:=await sample(pixel)
  assert(absf((angled_white.r-angled_black.r)-(1-coverage))<.04,"Angled cutout must fade from its anchor depth, not each vertex depth")
 batch.set_instance_custom_data(0,Color(.5,.5,1,0))
 bitmap.fill(Color(0,1,0,.08));material.set_shader_parameter("art",ImageTexture.create_from_image(bitmap))
 environment.environment.background_color=Color.BLACK;var edge_black:=await sample()
 environment.environment.background_color=Color.WHITE;var edge_white:=await sample()
 assert(absf((edge_white.r-edge_black.r)-(1-coverage*.08))<.015,"Formal low-alpha foliage edges must not be hard discarded")
 bitmap.fill(Color(0,1,0,1));material.set_shader_parameter("art",ImageTexture.create_from_image(bitmap))
 material.render_priority=-90
 var fog:=MeshInstance3D.new();var fog_quad:=QuadMesh.new();fog_quad.size=Vector2(2,2)
 var fog_material:=StandardMaterial3D.new();fog_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;fog_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;fog_material.albedo_color=Color(0,0,1,.5)
 fog_quad.material=fog_material;fog.mesh=fog_quad;fog.position.z=-1;scene.add_child(fog)
 environment.environment.background_color=Color.BLACK
 var with_fog:=await sample()
 assert(with_fog.b>.45,"Foreground mist must remain visible over the faded plant")
 print("WORLD3D_CUTOUT_FADE_PASS background contribution=",white.r-black.r," expected=",1-coverage)
 quit()
