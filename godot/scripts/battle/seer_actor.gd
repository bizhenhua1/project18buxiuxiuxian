extends Node
## A single live render target enters the existing world-depth batch; no image readback.
const MODEL = preload("res://assets/characters3d/seer-treading-snow.glb")
var viewport:SubViewport
var player:AnimationPlayer
var body:Node3D
var clip:=""
var action_left:=0.0
var walk_mix:=0.0
var defeated:=false
var opening_run:=false
# Measured on the retargeted ankles during their lowest 35% (stance).
const WALK_STRIDE_METERS:=1.598785
const WALK_DURATION:=1.366667
const CAPTURE_HEIGHT_METERS:=2.55
var world_units_per_meter:=30.0
var world_scale_calibrated:=false
func calibrate_world_scale(height:float) -> void:
 if world_scale_calibrated:return
 world_units_per_meter=maxf(.01,height/CAPTURE_HEIGHT_METERS)
 world_scale_calibrated=true
var previous_distance:=NAN
var gait_distance:=0.0
func travel_speed() -> float:
 return WALK_STRIDE_METERS/WALK_DURATION*world_units_per_meter
func calibrate_walk(animation_name:String="EM_Walk") -> void:
 var animation:Animation=player.get_animation(animation_name).duplicate(true)
 var library:=player.get_animation_library("")
 library.remove_animation(animation_name);library.add_animation(animation_name,animation)
 for track in range(animation.get_track_count()):
  if animation.track_get_type(track)!=Animation.TYPE_POSITION_3D:continue
  if not str(animation.track_get_path(track)).ends_with("全ての親"):continue
  var samples:Array[Vector3]=[]
  var mean:=Vector3.ZERO
  for i in range(60):
   var v:=animation.position_track_interpolate(track,animation.length*i/60.0)
   samples.append(v);mean+=v/60.0
  var cosine:Array[Vector3]=[];var sine:Array[Vector3]=[]
  for harmonic in [1,2]:
   var c:=Vector3.ZERO;var b:=Vector3.ZERO
   for i in range(60):
    c+=(samples[i]-mean)*cos(TAU*harmonic*i/60.0)/30.0
    b+=(samples[i]-mean)*sin(TAU*harmonic*i/60.0)/30.0
   cosine.append(c);sine.append(b)
  var amplitude:float=absf(cosine[0].y)+absf(sine[0].y)+absf(cosine[1].y)+absf(sine[1].y)
  for i in range(animation.track_get_key_count(track)):
   var phase:float=animation.track_get_key_time(track,i)/animation.length
   var wave:=Vector3.ZERO
   for h in range(2):wave+=cosine[h]*cos(TAU*(h+1)*phase)+sine[h]*sin(TAU*(h+1)*phase)
   # Smooth periodic body rise; world travel belongs to the scene, not root translation.
   animation.track_set_key_value(track,i,mean+Vector3(wave.x*.35,wave.y*minf(1,.022/maxf(.001,amplitude)),0))
func _ready() -> void:
 viewport=SubViewport.new();viewport.size=Vector2i(640,896)
 viewport.transparent_bg=true;viewport.own_world_3d=true
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 viewport.msaa_3d=Viewport.MSAA_2X
 add_child(viewport)
 var environment:=WorldEnvironment.new();environment.environment=Environment.new()
 environment.environment.background_mode=Environment.BG_CLEAR_COLOR
 environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 environment.environment.ambient_light_color=Color("acbbc6");environment.environment.ambient_light_energy=.22
 viewport.add_child(environment)
 body=MODEL.instantiate();viewport.add_child(body)
 apply_ink_material(body)
 player=find_player(body)
 player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 calibrate_walk();calibrate_walk("EM_Run")
 for name in ["EM_Idle","EM_Walk","EM_Run"]:player.get_animation(name).loop_mode=Animation.LOOP_LINEAR
 # Source faces +Z. Render its rear, with a slight inward turn.
 body.rotation.y=PI-.22
 var light:=OmniLight3D.new();light.position=Vector3(.95,1.25,-.25)
 light.light_color=Color("e5dfc9");light.light_energy=1.8;light.omni_range=4.0;viewport.add_child(light)
 var rim:=DirectionalLight3D.new();rim.rotation_degrees=Vector3(-30,-25,0);rim.light_color=Color("829cab");rim.light_energy=.20;viewport.add_child(rim)
 var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.size=2.55;camera.position=Vector3(0,1.1,5);viewport.add_child(camera)
 camera.look_at(Vector3(0,1.1,0));camera.current=true
 play("EM_Idle")
func find_player(node:Node) -> AnimationPlayer:
 if node is AnimationPlayer:return node
 for child in node.get_children():
  var found:=find_player(child)
  if found:return found
 return null
func play(name:String) -> void:
 if clip==name:return
 clip=name;player.play(name,.16)
func trigger(kind:String) -> void:
 if kind=="revive":defeated=false;action_left=0;return
 if kind=="death":defeated=true
 elif defeated:return
 var name:="EM_RangeAttack" if kind=="shot" else "EM_Special" if kind=="cast" else "EM_Death" if kind=="death" else ""
 if name.is_empty():return
 clip="";play(name);action_left=player.get_animation(name).length
func sync(dt:float,phase:String,moving:float,paused:bool,speed:float,enabled:bool,route_distance:float=0.0) -> void:
 if dt<=0:return # Layout-only calls must never consume travelled distance.
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if enabled else SubViewport.UPDATE_DISABLED
 player.active=enabled and not paused
 player.speed_scale=1.0
 var traveled:float=0.0 if is_nan(previous_distance) else maxf(0,route_distance-previous_distance)
 previous_distance=route_distance
 if paused or not enabled:return
 action_left=maxf(0,action_left-dt*speed)
 walk_mix=move_toward(walk_mix,1.0 if phase in ["travel","approach","entering","clearing"] else 0.0,dt*3)
 if phase in ["travel","approach"]:defeated=false
 if defeated or phase=="defeat":play("EM_Death")
 elif action_left<=0 or phase not in ["battle","clearing"]:
  play(("EM_Run" if opening_run else "EM_Walk") if (phase=="entering" and moving>.01) or (walk_mix>.1 and (moving>.01 or traveled>.001)) else "EM_Idle")
 if clip=="EM_Walk":
  gait_distance+=traveled
  player.advance(dt*speed*clampf(moving,0,1))
 else:player.advance(minf(dt,.05)*speed)
func texture() -> Texture2D:return viewport.get_texture()

func apply_ink_material(node:Node) -> void:
 preload("res://scripts/battle/character_ink_material.gd").apply(node)
