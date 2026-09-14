extends RefCounted
const SHADER=preload("res://scripts/world3d/actor_atmosphere.gdshader")
# Runs after opaque lighting, before normal transparent foliage/mist/particles.
const PASS_PRIORITY:=-100
var entries:Array=[]
var enabled:=false
var parameter_writes:=0
var groups:Dictionary={}
var shared_parameters:Dictionary={}
var shared_revision:=0
var parameter_comparisons:=0
var shared_clock_enabled:bool="--shared-atmosphere-clock" in OS.get_cmdline_user_args()
var clock_image:=Image.create(1,1,false,Image.FORMAT_RGBAF)
var clock_texture:ImageTexture
var clock_value:float=INF
func bind_clock(material:ShaderMaterial):
 if not shared_clock_enabled:return
 if clock_texture==null:clock_texture=ImageTexture.create_from_image(clock_image)
 material.set_shader_parameter("shared_atmosphere_clock",clock_texture)
 material.set_shader_parameter("shared_atmosphere_clock_enabled",true)
func regroup():
 groups.clear()
 for entry in entries:
  var id:int=entry.actor.get_instance_id()
  if not groups.has(id):groups[id]={"actor":entry.actor,"materials":[],"values":{},"shared_revision":-1}
  groups[id].materials.append(entry.material)
func setup(actors:Array):
 for actor in actors:
  for source in actor.fade_materials:
   if "outline" in source.shader.resource_path:continue
   var tail:Material=source
   while tail.next_pass!=null:tail=tail.next_pass
   var mat:=ShaderMaterial.new();mat.shader=SHADER;mat.render_priority=PASS_PRIORITY
   bind_clock(mat)
   mat.set_shader_parameter("base_texture",source.get_shader_parameter("base_texture"))
   mat.set_shader_parameter("textured",source.get_shader_parameter("textured"))
   entries.append({"actor":actor,"tail":tail,"tails":[tail],"weapon":false,"material":mat,"values":{}})
  if actor.get("attachments")!=null:
   actor.atmosphere_service=self;add_weapons(actor)
 regroup()
func remove_weapons(actor):
 for i in range(entries.size()-1,-1,-1):
  var entry:Dictionary=entries[i]
  if entry.actor==actor and entry.weapon:
   for tail in entry.tails:tail.next_pass=null
   entries.remove_at(i)
 regroup()
func add_weapons(actor):
 var presenter=actor.portrait_presenter
 if presenter.weapons.is_empty():
  for attachment in actor.attachments:presenter.collect_weapons(attachment)
 for weapon in presenter.weapons:
  var mat:=ShaderMaterial.new();mat.shader=SHADER;mat.render_priority=PASS_PRIORITY
  bind_clock(mat)
  mat.set_shader_parameter("base_texture",weapon.original.albedo_texture)
  mat.set_shader_parameter("textured",weapon.original.albedo_texture!=null)
  var tails:Array=[]
  for source in [weapon.original,weapon.material]:
   var tail:Material=source
   while tail.next_pass!=null:tail=tail.next_pass
   tails.append(tail)
   if enabled:tail.next_pass=mat
  entries.append({"actor":actor,"tail":tails[0],"tails":tails,"weapon":true,"material":mat,"values":{}})
 regroup()
func set_enabled(value:bool):
 if value==enabled:return
 enabled=value
 for entry in entries:
  for tail in entry.tails:tail.next_pass=entry.material if enabled else null
func sync(renderer,projection_enabled:bool):
 parameter_writes=0
 parameter_comparisons=0
 if not enabled:return
 var parameters:Dictionary=renderer.combat_light_parameters();parameters.merge(renderer.biome_parameters())
 parameters.merge({"lantern_position":renderer.lantern_position(),"lantern_enabled":renderer.lantern_enabled,"lantern_forward":Vector2(sin(renderer.heading),cos(renderer.heading)),"atmosphere_time":renderer.elapsed,"fog_color":renderer.world.camera_region.space.atmosphere.depth_color,"fog_range":Vector2(renderer.world.camera_region.space.depth_start,renderer.world.camera_region.space.depth_end),"region_tint":renderer.world.camera_region.space.ambient})
 if shared_clock_enabled:
  if clock_value!=renderer.elapsed:
   clock_value=renderer.elapsed;clock_image.set_pixel(0,0,Color(clock_value,0,0,1));clock_texture.update(clock_image)
  parameters.erase("atmosphere_time")
 var previous_revision:=shared_revision
 var changed:Dictionary={}
 for key in parameters:
  parameter_comparisons+=1
  if not shared_parameters.has(key) or shared_parameters[key]!=parameters[key]:changed[key]=parameters[key]
 if not changed.is_empty():
  shared_parameters=parameters;shared_revision+=1
 for group in groups.values():
  var actor=group.actor
  if not actor.visible:continue
  if group.shared_revision!=shared_revision:
   var updates:Dictionary=changed if group.shared_revision==previous_revision else shared_parameters
   for key in updates:
    for material in group.materials:material.set_shader_parameter(key,updates[key])
    parameter_writes+=group.materials.size()
   group.shared_revision=shared_revision
  var position:Vector3=actor.global_position
  var ground:=Vector2(position.x,-position.z)*20
  var local:Dictionary={"actor_anchor":position,"portrait_anchor":position,"actor_clearance":position.y*20-ForestEcology.height_at(ground),"portrait_weight":1.0 if projection_enabled else 0.0,"portrait_vertical_offset":actor.portrait_presenter.vertical_offset,"actor_opacity":actor.opacity}
  local.merge(actor.portrait_presenter.near_parameters,true)
  for key in local:
   parameter_comparisons+=1
   var value=local[key]
   if group.values.has(key) and group.values[key]==value:continue
   group.values[key]=value
   for material in group.materials:material.set_shader_parameter(key,value)
   parameter_writes+=group.materials.size()
