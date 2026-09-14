extends SceneTree
const GRID=preload("res://scripts/world3d/ground_grid.gd")
func _initialize():call_deferred("run")
func capture()->Image:
 for frame in 3:await process_frame
 await RenderingServer.frame_post_draw
 return root.get_texture().get_image()
func run():
 if DisplayServer.get_name()=="headless":quit(1);return
 root.size=Vector2i(480,320)
 var scene:=Node3D.new();root.add_child(scene)
 var camera:=Camera3D.new();scene.add_child(camera);camera.current=true
 # Look down far enough that every pixel sees the common interior of all patches;
 # the intentionally recycled far outer edge is not a ground-contact comparison.
 camera.position=Vector3(0,8,-60);camera.look_at(Vector3(0,0,-65))
 var ground:=MeshInstance3D.new();ground.mesh=GRID.mesh();scene.add_child(ground)
 var source:String=load("res://scripts/world3d/ground.gdshader").code
 var shader:=Shader.new()
 # Actual production vertex displacement; view-space position exposes changes
 # in the sampled surface without introducing texture filtering or lighting noise.
 shader.code=source.substr(0,source.find("void fragment(){"))+"void fragment(){ALBEDO=vec3(.5+VERTEX.y*.1,.5+VERTEX.z*.01,.5);}"
 var material:=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("terrain_amplitude",5.0);ground.material_override=material
 ground.position=GRID.patch_origin(Vector2.ZERO)
 var reference:PackedByteArray=(await capture()).get_data()
 var worst:=0;var checked:=0
 for offset in [Vector2(.1,.1),Vector2(-.1,-.1),Vector2(20.01,20.01),Vector2(-20.01,-20.01),Vector2(59.9,-39.9)]:
  ground.position=GRID.patch_origin(offset)
  var actual:PackedByteArray=(await capture()).get_data()
  for i in actual.size():worst=maxi(worst,absi(actual[i]-reference[i]))
  checked+=root.size.x*root.size.y
 if worst>1:
  push_error("Recycling ground patch changes terrain: max_byte_difference="+str(worst));quit(1);return
 print("WORLD3D_GROUND_GRID_GPU_PASS pixels=",checked," max_byte_difference=",worst)
 quit()
