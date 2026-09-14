extends SceneTree
func _initialize():call_deferred("run")
func frame()->Image:
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 return root.get_texture().get_image()
func run():
 root.size=Vector2i(320,240)
 var scene:=Node3D.new();root.add_child(scene)
 var camera:=Camera3D.new();scene.add_child(camera);camera.current=true
 var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color.BLACK;scene.add_child(environment)
 var bitmap:=Image.create(32,32,false,Image.FORMAT_RGBA8);bitmap.fill(Color.GREEN)
 var prop:=Sprite3D.new();prop.texture=ImageTexture.create_from_image(bitmap);prop.pixel_size=1.0/32;prop.position=Vector3(0,0,-3);scene.add_child(prop)
 var material:=ShaderMaterial.new();material.shader=load("res://scripts/world3d/prop_atmosphere.gdshader");material.render_priority=-80;material.set_shader_parameter("art",prop.texture);material.set_shader_parameter("lantern_enabled",false);prop.material_override=material
 var widths:Array=[]
 for angle in [0.0,.65,-.65]:
  camera.position=prop.position+Vector3(sin(angle),0,cos(angle))*3;camera.look_at(prop.position)
  var image:=await frame();var count:=0
  for x in 320:
   if image.get_pixel(x,120).g>.8:count+=1
  widths.append(count)
  assert(count>40)
 assert(widths.max()-widths.min()<=1,"Prop billboard width must survive route turns")
 material.set_shader_parameter("opacity",.25)
 var faded:Image=await frame()
 assert(absf(faded.get_pixel(160,120).g-.25)<.04,"Prop fades in place without opaque prepass residue")
 material.set_shader_parameter("opacity",1.0)
 var blocker:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2.ONE
 var blue:=StandardMaterial3D.new();blue.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;blue.albedo_color=Color.BLUE;quad.material=blue;blocker.mesh=quad;scene.add_child(blocker)
 blocker.transform=camera.global_transform*Transform3D(Basis.IDENTITY,Vector3(0,0,-1.5))
 var front:Image=await frame();assert(front.get_pixel(160,120).b>.9 and front.get_pixel(160,120).g<.05,"Foreground geometry must occlude props")
 blocker.transform=camera.global_transform*Transform3D(Basis.IDENTITY,Vector3(0,0,-5))
 var back:Image=await frame();assert(back.get_pixel(160,120).g>.9,"Rear geometry must not cover props")
 print("WORLD3D_PROP_PROJECTION_PASS turning widths=",widths," alpha=.25, front/back depth")
 quit()
