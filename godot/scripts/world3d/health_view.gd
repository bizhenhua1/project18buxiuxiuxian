extends RefCounted
static var shaders:Dictionary={}
var actor
var active:=false
var prepared:=false
var progress:=0.0
var originals:Array=[]
var atmosphere:Array=[]
var height_range:Dictionary={}
var skeletons:Array=[]
var skeleton_materials:Array=[]
var skull_scale:=-1.0
static func skeleton_shader()->Shader:
 if shaders.has("skeleton"):return shaders.skeleton
 var code:String=load("res://shaders/character_transform.gdshader").code
 code=code.insert(code.find("uniform "),"#include \"res://scripts/world3d/portrait_projection.gdshaderinc\"\nuniform float actor_opacity=1.0;\n")
 code=code.replace("void vertex(){","void vertex(){POSITION=portrait_position(VERTEX,MODELVIEW_MATRIX,PROJECTION_MATRIX,VIEW_MATRIX);")
 code=code.replace("void fragment(){","void fragment(){if(fract(sin(dot(floor(FRAGCOORD.xy),vec2(12.9898,78.233)))*43758.5453)>=actor_opacity)discard;")
 var shader:=Shader.new();shader.code=code;shaders.skeleton=shader;return shader
func build_skeleton(value:float):
 for mesh in skeletons:mesh.get_parent().remove_child(mesh);mesh.queue_free()
 skeletons=preload("res://scripts/spaces/skeleton_fit.gd").build(actor.rig,value)
 skeleton_materials.clear();skull_scale=value
 for mesh in skeletons:
  var frame:Transform3D=actor.body.global_transform.affine_inverse()*mesh.global_transform
  preload("res://scripts/spaces/transformation_height.gd").bake(mesh,height_range.bottom,height_range.top,frame)
  mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;mesh.extra_cull_margin=5
  for i in mesh.mesh.get_surface_count():
   var material:=ShaderMaterial.new();material.shader=skeleton_shader();material.render_priority=-95
   material.set_shader_parameter("skeleton_part",true);material.set_shader_parameter("mode",1)
   mesh.set_surface_override_material(i,material);skeleton_materials.append(material)
static func shader_variant(outline:bool,portrait:bool)->Shader:
 var key:=str(outline)+str(portrait)
 if shaders.has(key):return shaders[key]
 var path:="res://shaders/character_health_outline.gdshader" if outline else "res://shaders/character_health_transform.gdshader"
 var code:String=load(path).code
 if not outline:
  # Keep the native opaque/depth path so the atmosphere screen pass can see
  # the surviving surface. Coverage transparency also preserves scene occlusion.
  code=code.replace(", depth_prepass_alpha","").replace("ALPHA","ghost_alpha")
  code=code.replace("void fragment(){","void fragment(){\n float ghost_alpha=1.0;")
  code=code.replace("\n}\nvoid light(){","\n if(fract(sin(dot(floor(FRAGCOORD.xy),vec2(39.346,11.135)))*47453.5453)>=ghost_alpha)discard;\n}\nvoid light(){")
 var declarations:="uniform float actor_opacity=1.0;\n"
 if portrait:
  declarations+="#include \"res://scripts/world3d/portrait_projection.gdshaderinc\"\n"
  if outline:code=code.replace("VERTEX+=NORMAL*width;","VERTEX+=NORMAL*width;POSITION=portrait_position(VERTEX,MODELVIEW_MATRIX,PROJECTION_MATRIX,VIEW_MATRIX);")
  else:declarations+="void vertex(){POSITION=portrait_position(VERTEX,MODELVIEW_MATRIX,PROJECTION_MATRIX,VIEW_MATRIX);}\n"
 # Declarations must precede the outline vertex function that references them.
 var insertion:int=code.find("uniform ")
 code=code.insert(insertion,declarations)
 code=code.replace("void fragment(){","void fragment(){\n if(fract(sin(dot(floor(FRAGCOORD.xy),vec2(12.9898,78.233)))*43758.5453)>=actor_opacity)discard;")
 var shader:=Shader.new();shader.code=code;shaders[key]=shader;return shader
func setup(owner_actor,environment_service):
 actor=owner_actor
 for entry in actor.portrait_presenter.surfaces:originals.append({"original":entry.original,"replacement":entry.replacement})
 for entry in environment_service.entries:
  if entry.actor==actor and not entry.weapon:atmosphere.append(entry.material)
func sync(dt:float,hp:float,maximum:float,data:Dictionary,instant:bool=false):
 var mode:int=int(data.get("mode",0))
 var enabled:bool=data.get("display","ui")=="transform" and mode in [0,1]
 if enabled and not prepared:
  height_range=preload("res://scripts/world3d/rest_height.gd").bake(actor.body);prepared=not height_range.is_empty()
 enabled=enabled and prepared
 if enabled and mode==1:
  var requested_scale:float=float(data.get("head_scales",{}).get(actor.model_key,1.0))
  if skeletons.is_empty() or not is_equal_approx(requested_scale,skull_scale):build_skeleton(requested_scale)
  enabled=not skeletons.is_empty()
 var target:=1-clampf(hp/maxf(.001,maximum),0,1)
 if enabled!=active:
  active=enabled;progress=target
  for i in actor.portrait_presenter.surfaces.size():
   var entry:Dictionary=actor.portrait_presenter.surfaces[i]
   var outline:bool="outline" in originals[i].original.resource_path
   entry.original=shader_variant(outline,false) if active else originals[i].original
   entry.replacement=shader_variant(outline,true) if active else originals[i].replacement
   entry.material.shader=entry.replacement if actor.portrait_presenter.enabled else entry.original
  actor.portrait_presenter.last_anchor=Vector3(INF,INF,INF);actor.portrait_presenter.sync()
 if active:
  progress=target if instant else move_toward(progress,target,maxf(0,dt)*3.5)
  var values={"health_progress":progress,"health_mode":mode,"health_opacity":float(data.get("opacity",.4)),"health_energy":float(data.get("energy",1.5)),"health_color":Color(data.get("color","70ecdfff")),"material_style":int(data.get("material_style",0))}
  for entry in actor.portrait_presenter.surfaces:
   for key in values:
    entry.material.set_shader_parameter(key,values[key])
 for material in atmosphere:material.set_shader_parameter("health_ghost_progress",progress if active else 0.0)
 for mesh in skeletons:mesh.visible=active and mode==1
 if active and mode==1:
  var presenter=actor.portrait_presenter
  var values={"progress":progress,"opacity":float(data.get("opacity",.4)),"emission_strength":float(data.get("energy",1.5)),"glow_color":Color(data.get("color","70ecdfff")),"material_style":int(data.get("material_style",0)),"actor_opacity":actor.opacity,"portrait_weight":1.0 if presenter.enabled else 0.0,"portrait_anchor":actor.global_position,"portrait_vertical_offset":presenter.vertical_offset}
  values.merge(presenter.near_parameters)
  for material in skeleton_materials:
   for key in values:material.set_shader_parameter(key,values[key])
