extends Node
const MODEL=preload("res://assets/characters3d/gentleman.glb")
var model_scene:PackedScene=MODEL
var ally:=false
var auto_locomotion:=true
var native_pose_external:=false
var pose_samples:=0
const RETARGET=preload("res://scripts/spaces/preview_retarget.gd")
var viewport:SubViewport
var body:Node3D
var rig:Skeleton3D
var retarget=RETARGET.new()
var clips:Dictionary
var clip_cache:Dictionary={}
var health_effect:Node
var uid:=-1
var state:="idle"
var elapsed:=0.0
var dead:=false
var actor_camera:Camera3D
var corpse_frame:=0.0
func frame_scale()->float:return actor_camera.size/2.6
var cleanup_age:=0.0
var removing:=false
var death_fog:CPUParticles3D
func death_remaining()->float:
 return maxf(0,(clips.death.frames-1)/clips.death.fps-elapsed) if dead else 0.0
func restore_body():
 cleanup_age=0;removing=false;body.show()
 if is_instance_valid(death_fog):death_fog.queue_free()
func remove_in_mist():
 removing=true
 death_fog=CPUParticles3D.new()
 death_fog.amount=48;death_fog.lifetime=1.35;death_fog.one_shot=true;death_fog.explosiveness=1.0
 death_fog.emission_shape=CPUParticles3D.EMISSION_SHAPE_SPHERE;death_fog.emission_sphere_radius=.35
 death_fog.direction=Vector3.UP;death_fog.spread=85;death_fog.gravity=Vector3(0,.3,0)
 death_fog.initial_velocity_min=.45;death_fog.initial_velocity_max=1
 death_fog.scale_amount_min=.25;death_fog.scale_amount_max=.55
 var gradient:=Gradient.new();gradient.set_color(0,Color.WHITE);gradient.set_color(1,Color(1,1,1,0));death_fog.color_ramp=gradient
 var quad:=QuadMesh.new();quad.size=Vector2.ONE
 var material:=ShaderMaterial.new();material.shader=preload("res://shaders/island_fog_particle.gdshader");quad.material=material
 death_fog.mesh=quad;death_fog.position=Vector3(0,.15,0)
 viewport.add_child(death_fog);death_fog.emitting=true
var blend_time:=1.0
var team_key:OmniLight3D
var team_rim:DirectionalLight3D
var team_environment:Environment
var scene_light_tint:=Color.WHITE
var last_fill_color:=Color.TRANSPARENT
var last_environment_fill:=-1.0
var light_blend:=0.0
var team_light_override:Dictionary={}
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
 actor_camera=cam
 team_key=key;team_environment=env.environment
 if ally:team_rim=viewport.get_children().filter(func(n):return n is DirectionalLight3D)[0]
 health_effect=preload("res://scripts/battle/health_transformation.gd").new();add_child(health_effect);health_effect.setup(body,rig)
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
 if health_effect:health_effect.unit=unit
 if uid==int(unit.uid):
  if dead and float(unit.hp)>0:trigger("revive")
  return
 uid=unit.uid;dead=false;restore_body();play("idle")
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
 if kind=="revive":dead=false;restore_body();play("idle");return
 if dead:return
 if kind=="death":dead=true;play("death")
 elif kind=="damage":play("hit")
 elif kind in ["shot","cast"]:play("attack")
func advance(dt:float,phase:String,paused:bool,speed:float,enabled:bool,entrance:float=-1.0) -> void:
 if ally:update_team_light(phase,dt)
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if enabled and not native_pose_external else SubViewport.UPDATE_DISABLED
 if not enabled or paused:return
 corpse_frame=move_toward(corpse_frame,1.0 if dead else 0.0,dt*speed*2.5)
 actor_camera.size=lerpf(2.6,3.4,corpse_frame)
 actor_camera.position=Vector3(0,1,5).lerp(Vector3(0,3.5,5),corpse_frame)
 actor_camera.look_at(Vector3(0,1,0).lerp(Vector3(0,.35,0),corpse_frame))
 if phase=="defeat" or (phase=="clearing" and (dead or not ally)):
  if death_remaining()<=0.001:
   if not removing:remove_in_mist()
   cleanup_age+=dt*speed
   if cleanup_age>.28:body.hide()
 elif removing and not dead:restore_body()
 if not ally and not dead and health_effect:
  var returning:bool=health_effect.unit.get("returning_to_slot",false)
  if returning and state=="idle" and clips.has("walk"):play("walk")
  elif not returning and state=="walk":play("idle")
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
 # Keep timing and framing metadata for SceneFormation, but let the native
 # world actor own the only skeleton evaluation while it replaces this view.
 if native_pose_external:return
 pose_samples+=1
 retarget.apply(fmod(elapsed,duration) if state in ["idle","walk","run"] else minf(elapsed,duration))
 var weight=smoothstep(0,.12,blend_time)
 if weight<1:
  for i in range(rig.get_bone_count()):
   rig.set_bone_pose_rotation(i,old_rotations[i].slerp(rig.get_bone_pose_rotation(i),weight))
   rig.set_bone_pose_position(i,old_positions[i].lerp(rig.get_bone_pose_position(i),weight))
func head_uv() -> Vector2:
 var index=rig.find_bone("頭")
 var point:Vector3=body.transform*rig.get_bone_global_pose(index).origin
 return actor_camera.unproject_position(point)/Vector2(viewport.size)-Vector2(0,.045)
func ground_uv() -> float:return actor_camera.unproject_position(Vector3.ZERO).y/viewport.size.y
func texture() -> Texture2D:return viewport.get_texture()

func update_team_light(phase:String,dt:float):
 var target=1.0 if phase in ["battle","entering","encounter","sighting","defeat","reviving"] else 0.0
 light_blend=lerpf(light_blend,target,1-exp(-6*dt)) if dt>0 else target
 var data=preload("res://scripts/battle/team_lighting.gd").sample(light_blend,team_light_override)
 team_key.position=Vector3(data.x,data.y,data.z);team_key.light_energy=data.energy;team_key.omni_range=data.range;team_key.light_color=data.color*scene_light_tint
 team_environment.ambient_light_energy=data.ambient
 var fill_color:Color=Color("98afbf")*scene_light_tint
 team_environment.ambient_light_color=fill_color
 if not is_equal_approx(last_environment_fill,data.ambient) or last_fill_color!=fill_color:
  preload("res://scripts/battle/character_ink_material.gd").set_environment_fill(body,data.ambient,team_environment.ambient_light_color)
  last_environment_fill=data.ambient;last_fill_color=fill_color
 if team_rim:team_rim.light_energy=data.rim;team_rim.light_color=Color("829cab")*scene_light_tint
