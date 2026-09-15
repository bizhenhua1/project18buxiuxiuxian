extends Node3D
var body:Node3D
var rig:Skeleton3D
var retarget=preload("res://scripts/spaces/preview_retarget.gd").new()
var library:Dictionary
var cache:Dictionary={}
var clip:="idle"
var clock:=0.0
var action:=0.0
var dead:=false
var speed:=0.0
var fade_materials:Array=[]
var opacity:=1.0
func setup(file:String) -> void:
 library=JSON.parse_string(FileAccess.get_file_as_string("res://data/enemy_3d_motions.json"))
 body=load("res://assets/characters3d/"+file).instantiate();add_child(body)
 scan(body)
 body.scale=Vector3.ONE*1.8/(rig.get_bone_global_rest(rig.find_bone("頭")).origin.y+.2)
 prepare_body()
 preload("res://scripts/battle/character_ink_material.gd").apply(body)
 setup_fade(body)
 retarget.configure(rig,library.bones)
 play("idle")
func prepare_body()->void:
 pass
func scan(node:Node) -> void:
 if node is Skeleton3D:rig=node
 if node is AnimationPlayer:node.active=false
 for child in node.get_children():scan(child)
func play(name:String) -> void:
 clip=name;clock=0
 if not cache.has(name):
  retarget.load_clip(library.clips[name]);cache[name]=retarget.data
 else:
  retarget.data=cache[name];retarget.frames=library.clips[name].frames;retarget.fps=library.clips[name].fps
func trigger(kind:String) -> void:
 if kind=="revive":dead=false;action=0;play("idle");return
 if dead:return
 if kind=="death":dead=true
 play(kind);action=float(library.clips[kind].frames)/library.clips[kind].fps
func locomotion_rate(move_speed:float)->float:
 return clampf(move_speed/1.17,.15,2.5) if clip=="walk" else clampf(move_speed/2.7,.2,1.7) if clip=="run" else 1.0
func locomotion_clip(move_speed:float)->String:
 return "run" if move_speed>2.0 else "walk" if move_speed>.06 else "idle"
func advance(dt:float,velocity:Vector3) -> void:
 speed=Vector2(velocity.x,velocity.z).length()
 if speed>.05 and not dead:rotation.y=lerp_angle(rotation.y,atan2(velocity.x,velocity.z),1-exp(-dt*12))
 action=maxf(0,action-dt)
 if not dead and action<=0:
  var desired:=locomotion_clip(speed)
  if desired!=clip:play(desired)
 clock+=dt*locomotion_rate(speed)
 var duration:float=(library.clips[clip].frames-1)/library.clips[clip].fps
 retarget.apply(fmod(clock,duration) if clip in ["walk","run","idle"] else minf(clock,duration))

func setup_fade(node:Node) -> void:
 if node is MeshInstance3D:
  for i in range(node.mesh.get_surface_count()):
   var mat=node.get_active_material(i)
   if mat is ShaderMaterial:
    mat.shader=preload("res://scripts/native3d/character_study_fade.gdshader")
    fade_materials.append(mat)
    if mat.next_pass is ShaderMaterial:
     mat.next_pass.shader=preload("res://scripts/native3d/character_study_outline_fade.gdshader")
     fade_materials.append(mat.next_pass)
 for child in node.get_children():setup_fade(child)
func set_opacity(value:float) -> void:
 opacity=value
 for mat in fade_materials:mat.set_shader_parameter("actor_opacity",value)
 visible=value>.001
