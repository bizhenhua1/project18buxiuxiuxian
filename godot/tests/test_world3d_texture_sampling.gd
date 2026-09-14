extends SceneTree
func _initialize():call_deferred("run")
func run():
 if DisplayServer.get_name()=="headless":
  push_error("Texture sampling validation requires an actual GPU renderer");quit(1);return
 root.size=Vector2i(320,240)
 var pixels:=Image.create(256,256,false,Image.FORMAT_RGBA8)
 for y in 256:
  for x in 256:pixels.set_pixel(x,y,Color.WHITE if (x+y)%2 else Color.BLACK)
 var source:=ImageTexture.create_from_image(pixels)
 var sampled:Texture2D=preload("res://scripts/world3d/texture_sampling.gd").mipmapped(source)
 assert(not source.get_image().has_mipmaps(),"Source artwork must remain unchanged")
 assert(sampled.get_image().has_mipmaps())
 var restored:=sampled.get_image();restored.clear_mipmaps()
 assert(restored.get_data()==pixels.get_data(),"Full resolution artwork must stay byte-identical")
 assert(preload("res://scripts/world3d/texture_sampling.gd").mipmapped(sampled)==sampled)
 var scene:=Node3D.new();root.add_child(scene)
 var camera:=Camera3D.new();scene.add_child(camera);camera.current=true
 var shader:=Shader.new()
 shader.code="shader_type spatial;render_mode unshaded;uniform sampler2D art:source_color,filter_linear_mipmap;void fragment(){ALBEDO=textureLod(art,UV,4.0).rgb;}"
 var material:=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("art",sampled)
 var mesh:=QuadMesh.new();mesh.size=Vector2(2,2);mesh.material=material
 var node:=MeshInstance3D.new();node.mesh=mesh;scene.add_child(node);node.position.z=-2
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 var result:Color=root.get_texture().get_image().get_pixelv(Vector2i(camera.unproject_position(node.global_position)))
 assert(result.r>.45 and result.r<.55,"GPU must sample the averaged checker mip: "+str(result))
 scene.queue_free();await process_frame
 print("WORLD3D_TEXTURE_SAMPLING_PASS unchanged source/base pixels, mip reuse, GPU minification ",result)
 quit()
