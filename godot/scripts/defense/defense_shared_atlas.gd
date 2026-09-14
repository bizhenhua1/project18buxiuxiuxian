extends RefCounted
# Grouped orthographic 3D rows preserve the original 256x320 per-cell framing.
# Depth separation isolates local point lights without changing orthographic size.
var viewport:SubViewport
var groups:Dictionary={}
var shaders:Dictionary={}
var rows:Array=[]
func clipped_shader(source:Shader)->Shader:
 if shaders.has(source):return shaders[source]
 var shader:=Shader.new()
 var code:String=source.code
 code=code.replace("void fragment(){","uniform vec4 atlas_cell;\nvoid fragment(){\n if(any(lessThan(FRAGCOORD.xy,atlas_cell.xy)) || any(greaterThanEqual(FRAGCOORD.xy,atlas_cell.xy+atlas_cell.zw)))discard;")
 code=code.replace("screen_uv=FRAGCOORD.xy;","screen_uv=FRAGCOORD.xy-atlas_cell.xy;")
 shader.code=code;shaders[source]=shader;return shader
func setup(app):
 viewport=SubViewport.new();viewport.size=Vector2i(1280,5120);viewport.transparent_bg=true;viewport.disable_3d=true
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;app.add_child(viewport)
 # Five lights per row stays within Compatibility's small per-view light budget.
 for row in app.MOTION_ROWS.size():
  var view:=SubViewport.new();view.size=Vector2i(1280,320);view.transparent_bg=true;view.own_world_3d=true;view.msaa_3d=Viewport.MSAA_2X
  view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;app.add_child(view);rows.append(view)
  var rect:=TextureRect.new();rect.texture=view.get_texture();rect.position=Vector2(0,row*320);rect.size=Vector2(1280,320);viewport.add_child(rect)
  var env:=WorldEnvironment.new();env.environment=app.sources.values()[0].team_environment.duplicate();view.add_child(env)
  var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.6;camera.position=Vector3(0,0,10);camera.far=200;camera.current=true;view.add_child(camera)
 for key in app.sources:
  var source=app.sources[key];var kind:int=int(str(key).left(1));var row:int=app.MOTION_ROWS.find(str(key).substr(1))
  var group:=Node3D.new();rows[row].add_child(group)
  group.position=Vector3((kind-2)*2.08,-1,-kind*20)
  source.body.reparent(group,false);source.team_key.reparent(group,false)
  source.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
  var cell:=Vector4(kind*256,0,256,320)
  for controller in source.body.get_children():
   if controller.get_script()==load("res://scripts/battle/character_ink_material.gd"):
    for surface in controller.surfaces:
     surface.material.shader=clipped_shader(surface.material.shader)
     surface.material.next_pass.shader=clipped_shader(surface.material.next_pass.shader)
     surface.material.set_shader_parameter("atlas_cell",cell);surface.material.next_pass.set_shader_parameter("atlas_cell",cell)
  groups[key]=group
func set_active(key:String,enabled:bool):
 groups[key].visible=enabled
func finish_frame():
 for view in rows:
  var active:=false
  for child in view.get_children():
   if child is Node3D and child.get_child_count()>0 and not child is WorldEnvironment and child.visible:active=true;break
  view.render_target_update_mode=SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
