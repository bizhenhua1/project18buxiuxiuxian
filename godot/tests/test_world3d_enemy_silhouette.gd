extends SceneTree
func _initialize():call_deferred("run")
func snapshot()->Image:
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 return root.get_texture().get_image()
func run():
 root.size=Vector2i(640,800)
 var scene:=Node3D.new();root.add_child(scene)
 var camera:=Camera3D.new();scene.add_child(camera);camera.current=true
 var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color.BLACK;scene.add_child(environment)
 var plain:=Shader.new();plain.code='shader_type spatial;render_mode unshaded,cull_disabled;uniform sampler2D base_texture;uniform bool textured=true;void fragment(){if(textured && texture(base_texture,UV).a<.3)discard;ALBEDO=vec3(0,1,0);}'
 var projected:=Shader.new();projected.code='shader_type spatial;render_mode unshaded,cull_disabled;uniform sampler2D base_texture;uniform bool textured=true;\n#include "res://scripts/world3d/portrait_projection.gdshaderinc"\nvoid vertex(){POSITION=portrait_position(VERTEX,MODELVIEW_MATRIX,PROJECTION_MATRIX,VIEW_MATRIX);}\nvoid fragment(){if(textured && texture(base_texture,UV).a<.3)discard;ALBEDO=vec3(0,1,0);}'
 var minimum:=1.0;var count:=0
 var specs:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/defense_sample.json")).enemies
 for spec in specs:
  var actor=load("res://scripts/world3d/actor.gd").new();scene.add_child(actor);actor.setup(spec.model)
  # Remove outline passes so this measures actual mesh/alpha-cutout silhouettes.
  for material in actor.fade_materials:material.next_pass=null
  for clip in ["walk","attack","death"]:
   actor.play(clip);actor.retarget.apply((actor.library.clips[clip].frames-1)/actor.library.clips[clip].fps*.6)
   var scale_factor:=.73;var anchor:=Vector3(.3,-.7,-3)
   var eye:Vector3=-anchor/scale_factor
   camera.position=eye;camera.look_at(Vector3(0,.9,0));camera.fov=rad_to_deg(2*atan(1.3/eye.distance_to(Vector3(0,.9,0))))
   actor.position=Vector3.ZERO;actor.scale=Vector3.ONE
   for material in actor.fade_materials:material.shader=plain
   var ground_uv:Vector2=camera.unproject_position(Vector3.ZERO)/Vector2(root.size)
   var reference:=await snapshot()
   camera.position=Vector3.ZERO;camera.rotation=Vector3.ZERO;camera.fov=70
   actor.position=anchor;actor.scale=Vector3.ONE*scale_factor
   var focal:float=400/tan(deg_to_rad(70)*.5)
   var height:float=2.6*scale_factor*focal/-anchor.z
   var parameters:Dictionary=preload("res://scripts/world3d/enemy_portrait_projection.gd").parameters(anchor,scale_factor,height)
   assert(parameters.portrait_near_params.x==1)
   for material in actor.fade_materials:
    material.shader=projected;material.set_shader_parameter("portrait_weight",1.0);material.set_shader_parameter("portrait_anchor",anchor)
    for key in parameters:material.set_shader_parameter(key,parameters[key])
   var result:=await snapshot()
   var foot:Vector2=camera.unproject_position(anchor)
   var dimensions:=Vector2(height*.8,height);var origin:Vector2=foot-Vector2(.5,ground_uv.y)*dimensions
   var intersection:=0;var union:=0
   for y in root.size.y:
    for x in root.size.x:
     var uv:Vector2=(Vector2(x+.5,y+.5)-origin)/dimensions
     var expected:bool=uv.x>=0 and uv.y>=0 and uv.x<1 and uv.y<1 and reference.get_pixelv(Vector2i(uv*Vector2(root.size))).g>.5
     var actual:bool=result.get_pixel(x,y).g>.5
     if expected or actual:union+=1
     if expected and actual:intersection+=1
   assert(union>100,"Silhouette must contain visible geometry")
   var iou:float=float(intersection)/union;minimum=minf(minimum,iou);count+=1
   print("ENEMY_SILHOUETTE ",spec.model," ",clip," IoU=",iou)
   assert(iou>.96,"Native projected silhouette differs from independent perspective rendering")
  actor.queue_free();await process_frame
 print("WORLD3D_ENEMY_SILHOUETTE_PASS comparisons=",count," minimum IoU=",minimum)
 quit()
