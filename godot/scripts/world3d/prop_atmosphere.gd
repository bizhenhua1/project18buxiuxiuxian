extends RefCounted
var entries:Array=[]
var enabled:=false
var writes:=0
var texture_cache:Dictionary={}
func sampled_texture(texture:Texture2D)->Texture2D:
 if not texture_cache.has(texture):texture_cache[texture]=preload("res://scripts/world3d/texture_sampling.gd").mipmapped(texture)
 return texture_cache[texture]
func setup(props:Array,profiles:Array):
 for item in props:
  var source:Texture2D=item.node.texture
  var sampled:Texture2D=sampled_texture(source)
  item.node.texture=sampled
  item.node.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
  var material:=ShaderMaterial.new();material.shader=load("res://scripts/world3d/prop_atmosphere.gdshader")
  # Share foliage's pass so camera depth, rather than a fixed later pass,
  # decides which translucent surface is in front of the card.
  material.render_priority=-90
  material.set_shader_parameter("art",sampled)
  material.set_shader_parameter("clearance",float(profiles[item.slot].clearance))
  entries.append({"node":item.node,"material":material,"source":source,"values":{}})
func set_texture(index:int,source:Texture2D):
 var entry:Dictionary=entries[index]
 var sampled:Texture2D=sampled_texture(source)
 entry.source=source;entry.node.texture=sampled
 entry.material.set_shader_parameter("art",sampled)
func refresh_clearances(props:Array,profiles:Array):
 for i in props.size():
  entries[i].material.set_shader_parameter("clearance",float(profiles[props[i].slot].clearance))
func sync(renderer,value:bool):
 writes=0
 if value!=enabled:
  enabled=value
  for entry in entries:entry.node.material_override=entry.material if enabled else null
 if not enabled:return
 var parameters:Dictionary=renderer.combat_light_parameters();parameters.merge(renderer.biome_parameters())
 var space=renderer.world.camera_region.space
 parameters.merge({"lantern_position":renderer.lantern_position(),"lantern_enabled":renderer.lantern_enabled,"lantern_forward":Vector2(sin(renderer.heading),cos(renderer.heading)),"atmosphere_time":renderer.elapsed,"fog_color":space.atmosphere.depth_color,"fog_range":Vector2(space.depth_start,space.depth_end),"region_tint":space.ambient})
 for entry in entries:
  parameters.opacity=entry.node.modulate.a
  parameters.clearance=float(entry.node.get_meta("presentation_clearance",entry.material.get_shader_parameter("clearance")))
  for key in parameters:
   if entry.values.has(key) and entry.values[key]==parameters[key]:continue
   entry.values[key]=parameters[key];entry.material.set_shader_parameter(key,parameters[key]);writes+=1
