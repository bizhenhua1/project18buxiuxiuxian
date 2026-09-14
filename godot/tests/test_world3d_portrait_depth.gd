extends SceneTree
func _initialize():call_deferred("run")
func frame_pixel(p:Vector2)->Color:
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 return root.get_texture().get_image().get_pixelv(Vector2i(p))
func run():
 root.size=Vector2i(320,240)
 var stage:=Node3D.new();root.add_child(stage)
 var camera:=Camera3D.new();stage.add_child(camera);camera.current=true
 var shader:=Shader.new();shader.code='shader_type spatial;render_mode unshaded,cull_disabled;\n#include "res://scripts/world3d/portrait_projection.gdshaderinc"\nvoid vertex(){POSITION=portrait_position(VERTEX,MODELVIEW_MATRIX,PROJECTION_MATRIX,VIEW_MATRIX);}\nvoid fragment(){ALBEDO=vec3(0,1,0);}'
 var material:=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("portrait_weight",1.0)
 var atmosphere:ShaderMaterial
 if "--atmosphere" in OS.get_cmdline_user_args():
  atmosphere=ShaderMaterial.new();atmosphere.shader=load("res://scripts/world3d/actor_atmosphere.gdshader")
  atmosphere.render_priority=preload("res://scripts/world3d/actor_atmosphere.gd").PASS_PRIORITY
  atmosphere.set_shader_parameter("textured",false);atmosphere.set_shader_parameter("portrait_weight",1.0)
  atmosphere.set_shader_parameter("lantern_enabled",true);atmosphere.set_shader_parameter("team_light_energy",0.0)
  material.next_pass=atmosphere
 var actor:=MeshInstance3D.new();actor.mesh=QuadMesh.new();actor.mesh.size=Vector2(.7,.7);actor.material_override=material;stage.add_child(actor)
 var blocker:=MeshInstance3D.new();blocker.mesh=QuadMesh.new();blocker.mesh.size=Vector2(6,6)
 var blue:=StandardMaterial3D.new();blue.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;blue.albedo_color=Color.BLUE;blocker.material_override=blue;stage.add_child(blocker)
 for anchor in [Vector3(0,0,-4),Vector3(.4,.2,-3)]:
  actor.position=anchor+Vector3(.35,.2,.5);material.set_shader_parameter("portrait_anchor",anchor)
  if atmosphere:
   atmosphere.set_shader_parameter("portrait_anchor",anchor);atmosphere.set_shader_parameter("actor_anchor",anchor)
  var projected:=camera.unproject_position(anchor+Vector3(.35,.2,0))
  if "--near" in OS.get_cmdline_user_args():
   var calculator=preload("res://scripts/world3d/enemy_portrait_projection.gd")
   var parameters:Dictionary=calculator.parameters(anchor,.73,200)
   for key in parameters:
    material.set_shader_parameter(key,parameters[key])
    if atmosphere:atmosphere.set_shader_parameter(key,parameters[key])
   var offset:Vector2=calculator.offset(actor.position,parameters)
   projected=camera.unproject_position(anchor+Vector3(offset.x,offset.y,0))
  blocker.position=Vector3(0,0,-7)
  var behind:Color=await frame_pixel(projected)
  if atmosphere:assert(behind.g>.1 and behind.g<.8 and behind.b<.15,"Post-light atmosphere must shade the visible actor")
  else:assert(behind.g>.8 and behind.b<.1,"Actor must cover a surface behind its real depth")
  blocker.position=Vector3(0,0,-1)
  var front:Color=await frame_pixel(projected)
  assert(front.b>.8 and front.g<.1,"Foreground must occlude the projected actor")
  if atmosphere:
   var mist_shader:=Shader.new();mist_shader.code="shader_type spatial;render_mode unshaded,cull_disabled,depth_draw_never;void fragment(){ALBEDO=vec3(0,0,1);ALPHA=.5;}"
   var mist:=ShaderMaterial.new();mist.shader=mist_shader;blocker.material_override=mist
   var overlay:Color=await frame_pixel(projected)
   print("TRANSPARENT_FOREGROUND_SAMPLE ",overlay)
   if overlay.b<.45 or overlay.g>behind.g*.8:
    push_error("Actor post-pass erased transparent foreground");quit(1);return
   blocker.position=Vector3(0,0,-7)
   var rear_mist:Color=await frame_pixel(projected)
   assert(absf(rear_mist.g-behind.g)<.02 and rear_mist.b<.1,"Transparent background cannot bleed through opaque actor")
   blocker.material_override=blue
 print("WORLD3D_PORTRAIT_DEPTH_PASS GPU front/back occlusion at two moving anchors")
 quit()
