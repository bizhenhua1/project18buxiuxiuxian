extends Node
const MASK_LAYER:=1<<19
var stage
var viewport:SubViewport
var camera:Camera3D
var overlay:ColorRect
var material:ShaderMaterial
var groups:Dictionary={}
const STYLE_NAMES:=["月白细线","旧金流光","幽灵柔辉","绯红余烬"]
var style_index:=1
var effect_clock:=0.0
func set_style(value:int,save:=true):
 style_index=clampi(value,0,STYLE_NAMES.size()-1)
 material.set_shader_parameter("style",style_index)
 if save:
  var config:=ConfigFile.new();config.set_value("selection","style",style_index);config.save("user://tactical-outline.cfg")
func _process(dt:float):
 if overlay and overlay.visible:
  effect_clock+=dt;material.set_shader_parameter("effect_time",effect_clock)
func setup(owner_stage,canvas:Control):
 stage=owner_stage
 viewport=SubViewport.new();viewport.transparent_bg=true;viewport.world_3d=stage.get_world_3d();viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;viewport.handle_input_locally=false;add_child(viewport)
 viewport.msaa_3d=Viewport.MSAA_4X
 camera=Camera3D.new();camera.cull_mask=MASK_LAYER;viewport.add_child(camera);camera.current=true
 camera.environment=Environment.new();camera.environment.background_mode=Environment.BG_COLOR;camera.environment.background_color=Color.BLACK
 stage.camera.cull_mask=stage.camera.cull_mask & ~MASK_LAYER
 overlay=ColorRect.new();overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 material=ShaderMaterial.new();material.shader=preload("res://scripts/tactical/selection_outline.gdshader");material.set_shader_parameter("mask_image",viewport.get_texture());overlay.material=material
 var config:=ConfigFile.new();config.load("user://tactical-outline.cfg");set_style(int(config.get_value("selection","style",1)),false)
 canvas.add_child(overlay);canvas.move_child(overlay,0);overlay.hide()
func collect(node:Node,output:Array):
 if node is MeshInstance3D and not node.has_meta("tactical_mask"):output.append(node)
 for child in node.get_children():
  if not child.has_meta("tactical_mask"):collect(child,output)
func build(actor)->Array:
 var sources:Array=[];collect(actor,sources);var result:Array=[]
 for source in sources:
  if source.mesh==null:continue
  var clone:=MeshInstance3D.new();clone.set_meta("tactical_mask",true);clone.mesh=source.mesh;clone.skin=source.skin;clone.skeleton=source.skeleton;clone.transform=source.transform;clone.layers=MASK_LAYER;clone.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;clone.extra_cull_margin=source.extra_cull_margin
  source.get_parent().add_child(clone)
  var materials:Array=[]
  for i in source.mesh.get_surface_count():
   var original=source.get_active_material(i);var mask:=ShaderMaterial.new();mask.shader=preload("res://scripts/tactical/selection_mask.gdshader")
   if original is ShaderMaterial:
    var texture=original.get_shader_parameter("base_texture")
    mask.set_shader_parameter("base_texture",texture);mask.set_shader_parameter("textured",texture!=null)
   elif original is StandardMaterial3D:
    mask.set_shader_parameter("base_texture",original.albedo_texture);mask.set_shader_parameter("textured",original.albedo_texture!=null)
   clone.set_surface_override_material(i,mask);materials.append(mask)
  result.append({"source":source,"mesh":clone,"materials":materials})
 return result
func sync(ids:Array):
 var requested:Dictionary={}
 for id in ids:
  var index:int=stage.team_slots.find(id)
  if index<0:continue
  var actor=stage.team[index]
  if not actor.is_visible_in_tree() or actor.opacity<.1:continue
  requested[actor]=true
  if not groups.has(actor):groups[actor]=build(actor)
 var enabled:bool=not requested.is_empty()
 overlay.visible=enabled;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if enabled else SubViewport.UPDATE_DISABLED
 for actor in groups:
  var show:bool=requested.has(actor)
  for entry in groups[actor]:
   if not is_instance_valid(entry.mesh):continue
   if not is_instance_valid(entry.source):entry.mesh.hide();continue
   entry.mesh.visible=show and entry.source.is_visible_in_tree()
   if not show:continue
   entry.mesh.transform=entry.source.transform
   for mask in entry.materials:
    mask.set_shader_parameter("opacity",actor.opacity)
    mask.set_shader_parameter("portrait_anchor",actor.global_position)
    mask.set_shader_parameter("portrait_weight",1.0 if actor.portrait_presenter.enabled else 0.0)
    mask.set_shader_parameter("portrait_vertical_offset",actor.portrait_presenter.vertical_offset)
    for key in actor.portrait_presenter.near_parameters:mask.set_shader_parameter(key,actor.portrait_presenter.near_parameters[key])
 if not enabled:return
 var size:Vector2i=Vector2i(stage.get_viewport().get_visible_rect().size)
 if viewport.size!=size:viewport.size=size;material.set_shader_parameter("texel",Vector2.ONE/Vector2(size))
 camera.global_transform=stage.camera.global_transform;camera.projection=stage.camera.projection;camera.fov=stage.camera.fov;camera.size=stage.camera.size;camera.near=stage.camera.near;camera.far=stage.camera.far;camera.keep_aspect=stage.camera.keep_aspect;camera.frustum_offset=stage.camera.frustum_offset;camera.h_offset=stage.camera.h_offset;camera.v_offset=stage.camera.v_offset
