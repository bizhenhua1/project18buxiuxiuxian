extends Node
## Shared runtime material settings; preview lighting never replaces scene lighting.
const SAVE="user://character-shader.cfg"
const SURFACE=preload("res://shaders/character_study.gdshader")
const OUTLINE=preload("res://shaders/character_study_outline.gdshader")
const DEFAULTS={"scheme":2,"threshold":.52,"softness":.03,"ambient":.22,"saturation":.55,"ink":.35,"width":.012,"shadow_color":"18232eff"}
static var cached:Dictionary={}
static var next_poll:int=0
var surfaces:Array=[]
var current:Dictionary={}
var timer:=0.0
static func settings() -> Dictionary:
 var now=Time.get_ticks_msec()
 if cached.is_empty() or now>=next_poll:
  next_poll=now+500
  var config=ConfigFile.new();cached=DEFAULTS.duplicate()
  if config.load(SAVE)==OK:cached.merge(config.get_value("material","parameters",{}),true)
 return cached.duplicate()
static func save_game(data:Dictionary) -> Error:
 var parameters=DEFAULTS.duplicate()
 for key in parameters:
  if data.has(key):parameters[key]=data[key]
 if data.has("team_lights"):parameters.team_lights=data.team_lights.duplicate(true)
 var config=ConfigFile.new();config.set_value("material","parameters",parameters)
 var error=config.save(SAVE)
 if error==OK:cached=parameters;next_poll=0
 return error
static func apply(root:Node) -> void:
 var controller=load("res://scripts/battle/character_ink_material.gd").new()
 controller.collect(root)
 root.add_child(controller)
 controller.refresh(settings())
func collect(root:Node):
 if root is MeshInstance3D:
  for i in range(root.mesh.get_surface_count()):
   var original=root.get_active_material(i)
   if not original is StandardMaterial3D:continue
   var material=ShaderMaterial.new();material.shader=SURFACE
   material.set_shader_parameter("base_texture",original.albedo_texture)
   material.set_shader_parameter("textured",original.albedo_texture!=null)
   material.set_shader_parameter("base_color",original.albedo_color)
   var outline=ShaderMaterial.new();outline.shader=OUTLINE
   outline.set_shader_parameter("base_texture",original.albedo_texture)
   outline.set_shader_parameter("textured",original.albedo_texture!=null)
   outline.set_shader_parameter("opacity",original.albedo_color.a)
   outline.set_shader_parameter("ink_color",Color("#0c1119"))
   material.next_pass=outline
   surfaces.append({"mesh":root,"index":i,"original":original,"material":material})
 for child in root.get_children():collect(child)
func refresh(data:Dictionary):
 current=data.duplicate()
 for surface in surfaces:
  var material:ShaderMaterial=surface.material
  for key in ["threshold","softness","ambient","saturation","ink"]:material.set_shader_parameter(key,data[key])
  material.set_shader_parameter("style",int(data.scheme))
  material.set_shader_parameter("shadow_color",Color(data.shadow_color))
  material.next_pass.set_shader_parameter("width",data.width)
  surface.mesh.set_surface_override_material(surface.index,surface.original if int(data.scheme)==0 else material)
func _process(dt:float):
 timer+=dt
 if timer<.5:return
 timer=0
 var data=get_meta("preview_parameters",settings())
 if data!=current:refresh(data)

static func set_environment_fill(root:Node,energy:float,color:Color) -> void:
 for child in root.get_children():
  if child.get_script()==load("res://scripts/battle/character_ink_material.gd"):
   for surface in child.surfaces:
    surface.material.set_shader_parameter("environment_fill",energy)
    surface.material.set_shader_parameter("environment_fill_color",color)
  else:set_environment_fill(child,energy,color)
