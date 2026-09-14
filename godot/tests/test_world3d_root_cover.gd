extends SceneTree
func _initialize():call_deferred("run")
func height_at(p:Vector3,amplitude:float)->float:
 return (2.2*sin(-p.z*20*.009)+1.3*sin(p.x*20*.017-p.z*20*.004))*amplitude/20
func capture()->Image:
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 return root.get_texture().get_image()
func run():
 if DisplayServer.get_name()=="headless":quit(1);return
 root.size=Vector2i(320,240)
 var scene:=Node3D.new();root.add_child(scene)
 var camera:=Camera3D.new();scene.add_child(camera);camera.current=true;camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=5
 var mat:=ShaderMaterial.new();mat.shader=load("res://scripts/world3d/cutout.gdshader")
 var pixels:=Image.create(32,32,false,Image.FORMAT_RGBA8)
 for y in 32:
  for x in 32:pixels.set_pixel(x,y,Color(0,1,0) if x>3 and x<27 and y>2 and y<29 else Color.TRANSPARENT)
 mat.set_shader_parameter("art",ImageTexture.create_from_image(pixels));mat.set_shader_parameter("fog_range",Vector2(10000,20000))
 var mesh:=QuadMesh.new();mesh.material=mat
 var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true;mm.use_custom_data=true;mm.mesh=mesh;mm.instance_count=1;mm.set_instance_color(0,Color.WHITE)
 var node:=MultiMeshInstance3D.new();scene.add_child(node);node.multimesh=mm;node.extra_cull_margin=100
 var checks:=0;var worst:=0.0
 for angle in [-.6,-.5,0.0,.5,.6]:
  # Compatibility packs MultiMesh custom values to half precision. The reference
  # must use the uploaded heading rather than a higher-precision CPU heading.
  var packed:=PackedByteArray();packed.resize(2);packed.encode_half(0,angle)
  var uploaded_angle:=packed.decode_half(0)
  for flip in [-1.0,1.0]:
   for amplitude in [1.0,5.0]:
    var parent:=Vector3(10,0,0);parent.y=height_at(parent,amplitude)
    var offset:float=(.5-2.0)*flip
    var support:=parent+Vector3(cos(uploaded_angle)*offset,0,sin(uploaded_angle)*offset);support.y=height_at(support,amplitude)
    camera.position=support+Vector3(0,.5,12)
    mat.set_shader_parameter("terrain_amplitude",amplitude)
    mm.set_instance_transform(0,Transform3D(Basis.IDENTITY,parent));mm.set_instance_custom_data(0,Color(2,1,34*flip,angle))
    var actual:=await capture()
    # Independent ordinary centered sprite at the physical support point.
    mm.set_instance_transform(0,Transform3D(Basis.IDENTITY,support));mm.set_instance_custom_data(0,Color(.5,1,2*flip,angle))
    var expected:=await capture();var visible:=0;var changed:=0
    for y in 240:
     for x in 320:
      var a:=actual.get_pixel(x,y);var b:=expected.get_pixel(x,y)
      if b.g>b.r+.05:visible+=1
      var error:float=maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)));worst=maxf(worst,error)
      if error>2.0/255:changed+=1
    assert(visible>500,"Root fixture must be visible")
    print("ROOT_CASE ",angle," ",flip," ",amplitude," changed=",changed," worst=",worst)
    if changed>=5:
     actual.save_png("res://../tempassets/work/root-cover-actual.png");expected.save_png("res://../tempassets/work/root-cover-expected.png")
    assert(changed<5,"Off-center root differs from independently positioned foliage")
    checks+=1
 print("WORLD3D_ROOT_COVER_PASS cases=",checks," max_channel_error=",worst)
 scene.free();quit()

