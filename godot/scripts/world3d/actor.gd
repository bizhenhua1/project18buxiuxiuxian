extends "res://scripts/native3d/actor.gd"
static var catalog:Dictionary={}
static var strides:Dictionary={}
static var death_profiles:Dictionary={}
var model_key:=""
var change_stamp:=-1.0
var death_pose_finished:=false
var prone_death_transition
func play(name:String)->void:
 if prone_death_transition!=null and name!="prone_death":
  rig.reset_bone_poses();prone_death_transition=null
 death_pose_finished=false
 super(name)
var portrait_presenter
var merge_surfaces_enabled:bool=not "--no-merge-character-surfaces" in OS.get_cmdline_user_args()
func prepare_body()->void:
 if merge_surfaces_enabled:preload("res://scripts/world3d/surface_merge.gd").apply(body)
func setup(file:String)->void:
 retarget=preload("res://scripts/defense/defense_retarget.gd").new()
 super(file);model_key=file
 if "--compact-skins" in OS.get_cmdline_user_args():preload("res://scripts/world3d/skin_palette.gd").apply(body)
 if catalog.is_empty():catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/motions/catalog.json"))
 var custom={"fall":"7_Jump_Landing_Seq","landing":"5_ARPG_Warrior_Anim_rig_Landing2","rise":"7_Getup_Seq","crawl":"3_Obstacle_Climb_Loop","prone_death":"4_Anim_ARPGSamurai_Hit_knockdown_Death"}
 if death_profiles.is_empty():death_profiles=JSON.parse_string(FileAccess.get_file_as_string("res://data/world3d_death_profiles.json"))
 if death_profiles.has(file):custom.death=death_profiles[file]
 for key in custom:
  for entry in catalog.clips:
   if entry.id==custom[key]:library.clips[key]=entry;break
 retarget.configure(rig,catalog.bones)
 if not strides.has(file):strides[file]={"walk":measure("walk"),"run":measure("run"),"crawl":.8}
 play("idle")
 portrait_presenter=preload("res://scripts/world3d/portrait_presenter.gd").new();portrait_presenter.setup(self)
func measure(key:String)->float:
 play(key)
 var foot:int=rig.find_bone("足首.L")
 if foot<0:return 1.0 if key=="walk" else 2.0
 var duration:float=(library.clips[key].frames-1)/library.clips[key].fps
 var points:Array[Vector3]=[];var low:=INF;var high:=-INF
 for i in 121:
  retarget.apply(duration*i/120.0)
  var p:Vector3=body.transform*rig.get_bone_global_pose(foot).origin
  points.append(p);low=minf(low,p.y);high=maxf(high,p.y)
 var planted:Array[float]=[]
 for i in 120:
  var backward:float=(points[i].z-points[i+1].z)/maxf(duration/120,.0001)
  if backward>.05 and maxf(points[i].y,points[i+1].y)<low+(high-low)*.3:planted.append(backward)
 if planted.is_empty():return 1.17 if key=="walk" else 2.7
 planted.sort()
 return clampf(planted[planted.size()/2],.3,5)
func locomotion_rate(move_speed:float)->float:
 if clip in ["walk","run"] and strides.has(model_key):
  return move_speed/maxf(.01,absf(scale.x)*float(strides[model_key][clip]))
 return 1.0
func animate_unit(unit:Dictionary,now:float,dt:float,velocity:Vector3):
 # Presentation consumers (corpse framing, attachment anchors) must observe
 # the same life state as the animation, including a later resurrection.
 dead=unit.hp<=0
 if dead and unit.entry=="crawl" and unit.entry_phase=="advance":
  if prone_death_transition==null:
   prone_death_transition=preload("res://scripts/world3d/prone_death.gd").new()
   prone_death_transition.begin(self)
  if not death_pose_finished:
   clock=maxf(0,now-unit.changed)
   prone_death_transition.apply(rig,clock)
   death_pose_finished=clock>=prone_death_transition.SECONDS
  return
 if prone_death_transition!=null:
  rig.reset_bone_poses();prone_death_transition=null
 var desired:String="idle"
 if dead:desired="death"
 elif unit.entry_phase!="advance":desired=unit.entry_phase
 elif unit.state=="attack":desired="attack"
 elif unit.entry=="crawl":desired="crawl"
 elif velocity.length()>.015:desired="run" if unit.running else "walk"
 if desired!=clip:play(desired)
 if desired in ["walk","run","crawl"]:
  clock+=velocity.length()*dt/maxf(.01,scale.x*strides[model_key][desired])
 elif desired in ["fall","landing","rise"]:clock=now-unit.phase_started
 elif desired=="death":clock=now-unit.changed
 else:
  if desired=="attack" and change_stamp!=unit.changed:clock=0;change_stamp=unit.changed
  clock+=dt/sqrt(unit.body_scale)
 var duration:float=(library.clips[clip].frames-1)/library.clips[clip].fps
 # A persistent corpse keeps its submitted final pose. No repeated retargeting
 # across hundreds of bones; play()/revive invalidates this cache on reuse.
 if desired!="death" or not death_pose_finished:
  retarget.apply(minf(clock,duration) if desired in ["death","attack","landing","rise"] else fmod(clock,duration))
  death_pose_finished=desired=="death" and clock>=duration
 if velocity.length()>.01 and desired!="death":rotation.y=lerp_angle(rotation.y,atan2(velocity.x,velocity.z),1-exp(-dt*10))
 # Crawl is a locomotion posture, not an override of attack/death actions.
 # Keep it through those actions; a reused road unit restores the upright pose.
 var prone:bool=unit.entry=="crawl" and unit.entry_phase=="advance"
 body.rotation.x=PI*.5 if prone else 0
 body.position.y=.3 if prone else 0
