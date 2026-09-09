extends Node
const MODEL=preload("res://assets/characters3d/gentleman.glb")
var model_scene:PackedScene=MODEL
var ally:=false
var auto_locomotion:=true
const RETARGET=preload("res://scripts/spaces/preview_retarget.gd")
var viewport:SubViewport
var body:Node3D
var rig:Skeleton3D
var retarget=RETARGET.new()
var clips:Dictionary
var clip_cache:Dictionary={}
var uid:=-1
var state:="idle"
var elapsed:=0.0
var dead:=false
var blend_time:=1.0
var old_rotations:Array=[]
var old_positions:Array=[]
func _ready() -> void:
 var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/enemy_3d_motions.json"))
 clips=data.clips
 viewport=SubViewport.new();viewport.size=Vector2i(640,768);viewport.transparent_bg=true;viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_2X;add_child(viewport)
 body=model_scene.instantiate();viewport.add_child(body);prepare(body)
 preload("res://scripts/battle/character_ink_material.gd").apply(body)
 retarget.configure(rig,data.bones)
 var head=rig.find_bone("頭")
 body.scale=Vector3.ONE*1.8/(rig.get_bone_global_rest(head).origin.y+.2)
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_CLEAR_COLOR
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("98afbf");env.environment.ambient_light_energy=.28;viewport.add_child(env)
 var key=OmniLight3D.new();key.position=Vector3(1.2,1.6,.3) if ally else Vector3(-1,1.8,2);key.light_color=Color("e5dfc9") if ally else Color("bedae0");key.light_energy=2.2 if ally else 1.5;key.omni_range=6;viewport.add_child(key)
 if ally:
  var rim=DirectionalLight3D.new();rim.rotation_degrees=Vector3(-30,-25,0);rim.light_color=Color("829cab");rim.light_energy=.35;viewport.add_child(rim)
 var cam=Camera3D.new();cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=2.6;cam.position=Vector3(0,1,5);viewport.add_child(cam);cam.look_at(Vector3(0,1,0));cam.current=true
 play("idle")
func prepare(node:Node) -> void:
 if node is Skeleton3D:rig=node
 if node is AnimationPlayer:node.active=false
 if node is MeshInstance3D:
  for i in range(node.mesh.get_surface_count()):
   var source=node.get_active_material(i)
   if source is StandardMaterial3D:
    var mat=source.duplicate();mat.emission_enabled=false;mat.roughness=.9;node.set_surface_override_material(i,mat)
 for child in node.get_children():prepare(child)
func bind_unit(unit:Dictionary) -> void:
 if uid==int(unit.uid):
  if dead and float(unit.hp)>0:dead=false;play("idle")
  return
 uid=unit.uid;dead=false;play("idle")
func play(next:String) -> void:
 old_rotations.clear();old_positions.clear()
 for i in range(rig.get_bone_count()):
  old_rotations.append(rig.get_bone_pose_rotation(i));old_positions.append(rig.get_bone_pose_position(i))
 state=next;elapsed=0;blend_time=0
 if not clip_cache.has(state):
  retarget.load_clip(clips[state]);clip_cache[state]=retarget.data
 else:
  retarget.data=clip_cache[state];retarget.frames=int(clips[state].frames);retarget.fps=float(clips[state].fps)
func trigger(kind:String) -> void:
 if kind=="revive":dead=false;play("idle");return
 if dead:return
 if kind=="death":dead=true;play("death")
 elif kind=="damage":play("hit")
 elif kind in ["shot","cast"]:play("attack")
func advance(dt:float,phase:String,paused:bool,speed:float,enabled:bool,entrance:float=-1.0) -> void:
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if enabled else SubViewport.UPDATE_DISABLED
 if not enabled or paused:return
 # Sample the retreat from the same entrance clock as the world-space hop.
 if ally and auto_locomotion and not dead:
  if phase in ["entering","clearing"] and state=="idle":play("walk")
  elif phase not in ["entering","clearing"] and state=="walk":play("idle")
 if not ally and phase=="entering" and entrance>=0 and entrance<.78 and not dead:
  if state!="backstep":play("backstep")
  elapsed=clampf((entrance-.02)/.76,0,1)*(clips.backstep.frames-1)/clips.backstep.fps
 elif state=="backstep":play("idle")
 if state!="backstep":elapsed+=dt*speed
 blend_time+=dt*speed
 var duration:float=(clips[state].frames-1)/clips[state].fps
 if state in ["attack","hit"] and elapsed>=duration:play("idle")
 duration=(clips[state].frames-1)/clips[state].fps
 retarget.apply(fmod(elapsed,duration) if state in ["idle","walk","run"] else minf(elapsed,duration))
 var weight=smoothstep(0,.12,blend_time)
 if weight<1:
  for i in range(rig.get_bone_count()):
   rig.set_bone_pose_rotation(i,old_rotations[i].slerp(rig.get_bone_pose_rotation(i),weight))
   rig.set_bone_pose_position(i,old_positions[i].lerp(rig.get_bone_pose_position(i),weight))
func head_uv() -> Vector2:
 var index=rig.find_bone("頭")
 var point:Vector3=body.transform*rig.get_bone_global_pose(index).origin
 return Vector2(.5+point.x/(2.6*640.0/768.0),.5-(point.y-1)/2.6)-Vector2(0,.045)
func ground_uv() -> float:return .5+1.0/2.6
func texture() -> Texture2D:return viewport.get_texture()
