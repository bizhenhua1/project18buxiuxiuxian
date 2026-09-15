extends SceneTree
var material:ShaderMaterial
var wall:MeshInstance3D
func _initialize():call_deferred("run")
func sample(gap:float,softness:float)->float:
 wall.position.z=-gap;material.set_shader_parameter("intersection_softness",softness)
 for frame in 3:await process_frame
 await RenderingServer.frame_post_draw
 var image:Image=root.get_texture().get_image();var green:=0.0
 for y in range(90,150):
  for x in range(130,190):green+=image.get_pixel(x,y).g
 return green/3600
func run():
 root.size=Vector2i(320,240)
 var scene:=Node3D.new();root.add_child(scene)
 var camera:=Camera3D.new();scene.add_child(camera);camera.position.z=5;camera.current=true
 wall=MeshInstance3D.new();wall.mesh=QuadMesh.new();wall.mesh.size=Vector2(20,20);scene.add_child(wall)
 var surface:=StandardMaterial3D.new();surface.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;surface.albedo_color=Color(.1,0,0);wall.material_override=surface
 material=ShaderMaterial.new();material.shader=load("res://scripts/world3d/mist.gdshader")
 var mesh:=QuadMesh.new();mesh.material=material
 var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true;mm.use_custom_data=true;mm.mesh=mesh;mm.instance_count=1
 mm.set_instance_transform(0,Transform3D(Basis.from_scale(Vector3(4,4,1)),Vector3.ZERO));mm.set_instance_color(0,Color.WHITE);mm.set_instance_custom_data(0,Color(.5,.5,1,1))
 var mist:=MultiMeshInstance3D.new();mist.multimesh=mm;scene.add_child(mist)
 var near_raw:float=await sample(.02,0);var near_soft:float=await sample(.02,.45)
 var far_raw:float=await sample(1,0);var far_soft:float=await sample(1,.45)
 assert(near_raw>.01 and near_soft<near_raw*.2,"Intersection must fade at the opaque surface")
 assert(absf(far_raw-far_soft)<.002,"Separated mist must retain its original appearance")
 print("MIST_CONTACT_PASS near=",near_raw," -> ",near_soft," separated=",far_raw," / ",far_soft)
 quit()
