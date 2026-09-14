extends Node
const SAVE="user://health-transformation.cfg"
const FIT=preload("res://scripts/spaces/skeleton_fit.gd")
const HEIGHT=preload("res://scripts/spaces/transformation_height.gd")
const SKIN_SHADER=preload("res://shaders/character_health_transform.gdshader")
const EDGE_SHADER=preload("res://shaders/character_health_outline.gdshader")
const INK=preload("res://scripts/battle/character_ink_material.gd")
static var cached:Dictionary={}
static var next_poll:=0
var unit:Dictionary={}
var body:Node3D
var rig:Skeleton3D
var ink:Node
var ready_effect:=false
var active:=false
var progress:=0.0
var skull_scale:=1.0
var skeletons:Array=[]
var skeleton_materials:Array=[]
var height_bottom:=0.0
var height_top:=1.9
static func settings()->Dictionary:
 if cached.is_empty() or Time.get_ticks_msec()>=next_poll:
  next_poll=Time.get_ticks_msec()+400
  cached={"display":"ui","mode":0,"opacity":.4,"energy":1.5,"color":"70ecdfff","head_scales":{},"material_style":0}
  var config:=ConfigFile.new()
  if config.load(SAVE)==OK:cached.merge(config.get_value("health","settings",{}),true)
 return cached
static func save_game(data:Dictionary)->Error:
 var merged:Dictionary=settings().duplicate(true)
 merged.merge(data,true)
 var config:=ConfigFile.new();config.set_value("health","settings",merged)
 var error:=config.save(SAVE)
 next_poll=0;cached={}
 return error
func setup(root:Node3D,skeleton:Skeleton3D):
 body=root;rig=skeleton
 for child in root.get_children():
  if child.get_script()==INK:ink=child;break
func prepare_effect():
 if not ink:return
 var meshes:Array=[]
 for entry in ink.surfaces:
  if entry.mesh not in meshes:meshes.append(entry.mesh)
 height_bottom=INF;height_top=-INF
 for mesh in meshes:
  var bounds:AABB=mesh.get_aabb()
  for corner in range(8):
   var point:Vector3=mesh.global_transform*bounds.get_endpoint(corner)
   height_bottom=minf(height_bottom,point.y);height_top=maxf(height_top,point.y)
 for mesh in meshes:HEIGHT.bake(mesh,height_bottom,height_top)
 ready_effect=true
func prepare_skeleton():
 for mesh in skeletons:
  mesh.get_parent().remove_child(mesh);mesh.queue_free()
 skeletons.clear();skeleton_materials.clear()
 skull_scale=float(settings().get("head_scales",{}).get(body.scene_file_path.get_file(),1.0))
 skeletons=FIT.build(rig,skull_scale)
 for mesh in skeletons:
  HEIGHT.bake(mesh,height_bottom,height_top)
  for i in range(mesh.mesh.get_surface_count()):
   var mat:=ShaderMaterial.new();mat.shader=preload("res://shaders/character_transform.gdshader")
   mat.set_shader_parameter("skeleton_part",true);mat.set_shader_parameter("mode",1)
   mesh.set_surface_override_material(i,mat);skeleton_materials.append(mat)
func _process(dt:float):
 if not is_instance_valid(body) or not ink:return
 var data:=settings()
 var enabled:bool=data.display=="transform" and unit.has("hp") and unit.has("maxHp")
 if enabled and not ready_effect:prepare_effect()
 if enabled and int(data.mode)==1 and (skeletons.is_empty() or not is_equal_approx(skull_scale,float(data.get("head_scales",{}).get(body.scene_file_path.get_file(),1.0)))):prepare_skeleton()
 if enabled!=active:
  active=enabled
  for entry in ink.surfaces:
   entry.material.shader=SKIN_SHADER if active else INK.SURFACE
   entry.material.next_pass.shader=EDGE_SHADER if active else INK.OUTLINE
  ink.refresh(INK.settings())
  progress=1.0-clampf(float(unit.get("hp",1))/maxf(1,float(unit.get("maxHp",1))),0,1)
 if not unit.is_empty():unit.health_transformation_active=enabled and ready_effect and (int(data.mode)==0 or not skeletons.is_empty())
 if active:
  var target:=1.0-clampf(float(unit.hp)/maxf(1,float(unit.maxHp)),0,1)
  progress=move_toward(progress,target,dt*3.5)
  for entry in ink.surfaces:
   entry.mesh.set_surface_override_material(entry.index,entry.material)
   entry.material.set_shader_parameter("health_progress",progress)
   entry.material.set_shader_parameter("health_mode",int(data.mode))
   entry.material.set_shader_parameter("health_opacity",float(data.opacity))
   entry.material.set_shader_parameter("health_energy",float(data.energy))
   entry.material.set_shader_parameter("health_color",Color(data.color))
   entry.material.set_shader_parameter("material_style",int(data.get("material_style",0)))
   entry.material.next_pass.set_shader_parameter("health_progress",progress)
 for mesh in skeletons:mesh.visible=active and int(data.mode)==1
 if active:
  for material in skeleton_materials:
   material.set_shader_parameter("material_style",int(data.get("material_style",0)))
   material.set_shader_parameter("progress",progress);material.set_shader_parameter("opacity",float(data.opacity))
   material.set_shader_parameter("emission_strength",float(data.energy));material.set_shader_parameter("glow_color",Color(data.color))
