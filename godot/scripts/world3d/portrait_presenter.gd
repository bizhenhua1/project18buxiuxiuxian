extends RefCounted
const SURFACE=preload("res://scripts/world3d/character_portrait.gdshader")
const OUTLINE=preload("res://scripts/world3d/character_portrait_outline.gdshader")
const WEAPON=preload("res://scripts/world3d/weapon_portrait.gdshader")
var enabled:=false
var actor:Node3D
var surfaces:Array=[]
var weapons:Array=[]
var margins:Array=[]
var last_anchor:=Vector3(INF,INF,INF)
var vertical_offset:=0.0
var last_vertical_offset:=INF
var corpse_blend:=0.0
var near_parameters:Dictionary={"portrait_near_params":Vector3.ZERO,"portrait_near_view":Transform3D.IDENTITY}
func presented_attachment(point:Vector3,camera:Camera3D)->Vector3:
 var weak:Vector3=projected_attachment(point,actor.global_position,camera,vertical_offset)
 var weight:float=near_parameters.portrait_near_params.x
 if weight<=0:return weak
 var view:=camera.global_transform.affine_inverse()
 var p:Vector3=view*point;var a:Vector3=view*actor.global_position
 var q:Vector3=near_parameters.portrait_near_view*p
 if a.z>=-.05 or p.z>=-.05 or q.z>=-.05:return weak
 var offset:Vector2=preload("res://scripts/world3d/enemy_portrait_projection.gd").offset(p,near_parameters)
 var ratio:float=p.z/a.z
 var near_point:=Vector3((a.x+offset.x)*ratio,(a.y+offset.y)*ratio,p.z)
 return weak.lerp(camera.global_transform*near_point,weight)
func configure_enemy(camera:Camera3D,focal:float):
 if not actor.visible:return
 var anchor:Vector3=camera.global_transform.affine_inverse()*actor.global_position
 var parameters:Dictionary=preload("res://scripts/world3d/enemy_portrait_projection.gd").parameters(anchor,actor.scale.y,2.6*actor.scale.y*focal/maxf(.05,-anchor.z))
 if parameters==near_parameters:return
 near_parameters=parameters;last_anchor=Vector3(INF,INF,INF)
func advance_anchor(dt:float,leader:bool):
 corpse_blend=move_toward(corpse_blend,1.0 if actor.dead else 0.0,dt*2.5)
 vertical_offset=2.6*actor.scale.y*(.93-.884615421295166)*(1-corpse_blend) if leader else 0.0
# Equivalent world point for effects rendered by the ordinary camera. Depth is
# unchanged, matching the surface shader; this never changes a rig or collider.
static func projected_attachment(point:Vector3,anchor:Vector3,camera:Camera3D,vertical:=0.0)->Vector3:
 var view:=camera.global_transform.affine_inverse()
 var p:=view*point;var a:=view*anchor
 if a.z>=-.05 or p.z>=-.05:return point
 var ratio:=p.z/a.z
 p.x*=ratio
 p.y*=ratio
 p.y+=vertical*ratio
 return camera.global_transform*p
func setup(owner_actor:Node3D):
 actor=owner_actor
 for material in actor.fade_materials:
  surfaces.append({"material":material,"original":material.shader,"replacement":OUTLINE if "outline" in material.shader.resource_path else SURFACE})
func collect_weapons(node:Node):
 if node is MeshInstance3D:
  for i in node.mesh.get_surface_count():
   var original=node.get_active_material(i)
   if not original is StandardMaterial3D:continue
   original=original.duplicate(true)
   node.set_surface_override_material(i,original)
   var material:=ShaderMaterial.new();material.shader=WEAPON
   material.set_shader_parameter("base_color",original.albedo_color)
   material.set_shader_parameter("base_texture",original.albedo_texture);material.set_shader_parameter("textured",original.albedo_texture!=null)
   material.set_shader_parameter("roughness",original.roughness);material.set_shader_parameter("metallic",original.metallic)
   weapons.append({"mesh":node,"index":i,"original":original,"material":material,"base_alpha":original.albedo_color.a,"base_transparency":original.transparency})
   sync_opacity()
 for child in node.get_children():collect_weapons(child)
func collect_margins(node:Node):
 if node is GeometryInstance3D:margins.append({"mesh":node,"original":node.extra_cull_margin})
 for child in node.get_children():collect_margins(child)
func sync_opacity():
 for entry in weapons:
  entry.material.set_shader_parameter("actor_opacity",actor.opacity)
  entry.original.albedo_color.a=entry.base_alpha*actor.opacity
  entry.original.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_HASH if actor.opacity<.999 else entry.base_transparency
func prepare_weapons():
 # Weapon fading is required in ordinary 3D too, before any projection toggle.
 if weapons.is_empty() and actor.get("attachments")!=null:
  for attachment in actor.attachments:collect_weapons(attachment)
func set_enabled(value:bool):
 prepare_weapons()
 if enabled==value:return
 enabled=value
 if margins.is_empty():collect_margins(actor)
 for entry in surfaces:entry.material.shader=entry.replacement if enabled else entry.original
 for entry in weapons:
  if is_instance_valid(entry.mesh):entry.mesh.set_surface_override_material(entry.index,entry.material if enabled else entry.original)
 for entry in margins:
  if is_instance_valid(entry.mesh):entry.mesh.extra_cull_margin=maxf(entry.original,2.0) if enabled else entry.original
 last_anchor=Vector3(INF,INF,INF);sync()
func sync():
 if not enabled or not actor.visible or (actor.global_position==last_anchor and vertical_offset==last_vertical_offset):return
 last_anchor=actor.global_position
 last_vertical_offset=vertical_offset
 for entry in surfaces:
  entry.material.set_shader_parameter("portrait_anchor",last_anchor);entry.material.set_shader_parameter("portrait_weight",1.0)
  entry.material.set_shader_parameter("portrait_vertical_offset",vertical_offset)
  for key in near_parameters:entry.material.set_shader_parameter(key,near_parameters[key])
 for entry in weapons:
  entry.material.set_shader_parameter("portrait_anchor",last_anchor);entry.material.set_shader_parameter("portrait_weight",1.0)
  entry.material.set_shader_parameter("portrait_vertical_offset",vertical_offset)
  for key in near_parameters:entry.material.set_shader_parameter(key,near_parameters[key])
