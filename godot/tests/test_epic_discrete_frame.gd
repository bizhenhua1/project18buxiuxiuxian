extends SceneTree
func _initialize():call_deferred("run")
func run():
 if DisplayServer.get_name()=="headless":quit(1);return
 root.size=Vector2i(320,240)
 var scene:=Node3D.new();root.add_child(scene)
 var camera:=Camera3D.new();scene.add_child(camera);camera.current=true
 var shader:=Shader.new();shader.code=FileAccess.get_file_as_string("res://shaders/epic181_particle.gdshader").get_slice("void fragment()",0)+"void fragment(){ALBEDO=floor(tile_index)==7.0?vec3(1,0,0):vec3(0,1,0);ALPHA=1.0;}"
 var mat:=ShaderMaterial.new();mat.shader=shader
 var mesh:=QuadMesh.new();mesh.size=Vector2(1.5,1.5);mesh.material=mat
 var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_custom_data=true;mm.mesh=mesh;mm.instance_count=1;mm.set_instance_custom_data(0,Color(7,0,0,0))
 var node:=MultiMeshInstance3D.new();node.multimesh=mm;scene.add_child(node)
 var red:=0;var wrong:=0
 for frame in 12:
  mm.set_instance_transform(0,Transform3D(Basis.from_euler(Vector3(.05*frame,.03*frame,.07*frame)).scaled(Vector3.ONE*(1+.03*frame)),Vector3(.03*frame,0,-3)))
  await process_frame;await RenderingServer.frame_post_draw
  var pixels:Image=root.get_texture().get_image()
  for y in pixels.get_height():
   for x in pixels.get_width():
    var c:=pixels.get_pixel(x,y)
    if c.r>.9:red+=1
    if c.g>.9:wrong+=1
 scene.queue_free();await process_frame
 assert(red>10000 and wrong==0,"Frame index must not interpolate to another tile")
 print("EPIC_DISCRETE_FRAME_PASS red=",red," wrong_tile=",wrong);quit()
