extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(128,128)
 var scene:=Node3D.new();root.add_child(scene)
 var camera:=Camera3D.new();scene.add_child(camera);camera.current=true
 var pixels:=Image.create(2,2,false,Image.FORMAT_RGBA8);pixels.fill(Color.BLUE)
 var prop:=Sprite3D.new();prop.texture=ImageTexture.create_from_image(pixels);prop.pixel_size=.5;prop.position.z=-3;scene.add_child(prop)
 var service=load("res://scripts/world3d/prop_atmosphere.gd").new()
 service.setup([{"node":prop,"slot":0}],[{"clearance":0}])
 prop.material_override=service.entries[0].material
 var leaf:=MeshInstance3D.new();leaf.mesh=QuadMesh.new();leaf.position.z=-2;scene.add_child(leaf)
 var material:=ShaderMaterial.new();var shader:=Shader.new()
 shader.code="shader_type spatial; render_mode unshaded,cull_disabled,depth_draw_never; void fragment(){ALBEDO=vec3(1,0,0);ALPHA=0.5;}"
 material.shader=shader;material.render_priority=-90;leaf.material_override=material
 for i in 4:await process_frame
 await RenderingServer.frame_post_draw
 var front:Color=root.get_texture().get_image().get_pixel(64,64)
 print("PROP_LEAF_FRONT ",front)
 assert(front.r>.3 and front.b>.2,"Foreground translucent leaf must blend over prop")
 leaf.position.z=-4
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 var behind:Color=root.get_texture().get_image().get_pixel(64,64)
 assert(behind.r<.1 and behind.b>.8,"Background leaf must not cover opaque prop")
 print("WORLD3D_PROP_TRANSPARENCY_PASS front blend and rear depth occlusion")
 quit()
