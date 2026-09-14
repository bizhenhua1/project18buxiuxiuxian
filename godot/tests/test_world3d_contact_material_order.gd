extends SceneTree
func _initialize():call_deferred("run")
func run():
 var scenery=load("res://scripts/world3d/scenery.gd").new();root.add_child(scenery)
 var pixels:=Image.create(32,32,false,Image.FORMAT_RGBA8)
 for y in 32:
  for x in 32:pixels.set_pixel(x,y,Color.WHITE if y<29 else Color.TRANSPARENT)
 var texture:=ImageTexture.create_from_image(pixels)
 var space:=SpaceType.new();space.key=&"swamp"
 var region:=RouteRegion.new();region.space=space
 var sprite:Dictionary={"texture":texture,"position":Vector2(20,20),"route_s":20.0,"w":30.0,"h":50.0,"flip":false,"region":region}
 scenery.append_sprites([sprite])
 var material:ShaderMaterial=scenery.by_texture[texture]
 assert(not material.has_meta("base_contact_ready"))
 var arch:=sprite.duplicate();arch.shell=true;arch.position=Vector2(20,500)
 scenery.append_sprites([arch])
 assert(scenery.by_texture.size()==1 and scenery.by_texture[texture]==material)
 var profile:PackedFloat32Array=material.get_shader_parameter("base_contact")
 assert(profile.size()==17)
 for foot in profile:assert(is_equal_approx(foot,28.5/32))
 assert(scenery.chunks[0].multimesh.mesh is QuadMesh)
 assert(scenery.chunks[1].multimesh.mesh is ArrayMesh)
 assert(int(scenery.chunks[1].multimesh.get_instance_custom_data(0).b)%8==6)
 scenery.free()
 print("WORLD3D_CONTACT_MATERIAL_ORDER_PASS ordinary then adaptive shares material and initializes real profile")
 quit()
