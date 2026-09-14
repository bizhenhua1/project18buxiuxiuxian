extends Node
# High resolution independent actors reuse the same corridor projection and depth order.
const ACTOR=preload("res://scripts/battle/enemy_actor.gd")
const CELL=Vector2i(640,800)
const COUNT=15
const WORLD_PER_MODEL=38.0/2.6
var app
var atlas:SubViewport
var slots:Array=[]
var bindings:Dictionary={}
var clip_catalog:Dictionary={}
var custom={"fall":"7_Jump_Landing_Seq","landing":"5_ARPG_Warrior_Anim_rig_Landing2","rise":"7_Getup_Seq","crawl":"3_Obstacle_Climb_Loop"}
var speed_cache:Dictionary={}
var highwater:=0
func setup(owner_app):
 app=owner_app
 clip_catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/motions/catalog.json"))
 atlas=SubViewport.new();atlas.size=Vector2i(CELL.x*5,CELL.y*3);atlas.disable_3d=true;atlas.transparent_bg=true;atlas.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(atlas)
 for kind in 5:
  for n in 3:
   var actor=ACTOR.new();actor.retarget=preload("res://scripts/defense/defense_retarget.gd").new();actor.model_scene=load("res://assets/characters3d/"+app.defense.config.enemies[kind].model);add_child(actor)
   actor.viewport.size=CELL;actor.viewport.msaa_3d=Viewport.MSAA_2X
   for key in custom:
    for clip in clip_catalog.clips:
     if clip.id==custom[key]:actor.clips[key]=clip;break
   actor.retarget.configure(actor.rig,clip_catalog.bones)
   var index=slots.size()
   var rect:=TextureRect.new();rect.texture=actor.texture();rect.position=Vector2(index%5*CELL.x,index/5*CELL.y);rect.size=Vector2(CELL);atlas.add_child(rect)
   if not speed_cache.has(kind):
    speed_cache[kind]={"walk":measure_speed(actor,"walk"),"run":measure_speed(actor,"run"),"crawl":.8}
   actor.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
   slots.append({"actor":actor,"kind":kind,"id":-1,"state":"","clock":0.0,"distance":0.0,"last_change":-1.0})
   await get_tree().process_frame
func measure_speed(actor,key:String)->float:
 actor.play(key)
 var duration:float=(actor.clips[key].frames-1)/actor.clips[key].fps
 var low:=INF;var high:=-INF
 var foot:int=actor.rig.find_bone("足首.L")
 if foot<0:return 1.0 if key=="walk" else 2.5
 for frame in 32:
  actor.retarget.apply(duration*frame/31.0)
  var p:Vector3=actor.body.transform*actor.rig.get_bone_global_pose(foot).origin
  low=minf(low,p.z);high=maxf(high,p.z)
 return clampf((high-low)*2/maxf(duration,.1),.3,5.0)
func reset():
 bindings.clear()
 for slot in slots:slot.id=-1;slot.actor.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
func update(dt:float):
 var candidates:Array=[]
 var r=app.arena.scenery.renderer
 for e in app.defense.enemies:
  if app.defense.clock<e.activate_at or e.state=="leaked" or (e.hp<=0 and app.defense.clock-e.changed>3):continue
  var world:Vector2=app.defense_world(render_position(e))
  var relative:Vector2=ForestRoute.to_camera(world,r.camera_world,r.heading)
  var pixels:float=38.0*e.body_scale*r.focal()/maxf(10,relative.y)
  if pixels>(125 if bindings.has(e.id) else 140):candidates.append({"unit":e,"pixels":pixels*(1.12 if bindings.has(e.id) else 1.0)})
 candidates.sort_custom(func(a,b):return a.pixels>b.pixels)
 var wanted:Dictionary={};var counts:Dictionary={}
 for c in candidates:
  var e=c.unit
  if int(counts.get(e.type,0))>=3:continue
  wanted[e.id]=e;counts[e.type]=int(counts.get(e.type,0))+1
 for slot in slots:
  if slot.id>=0 and not wanted.has(slot.id):bindings.erase(slot.id);slot.id=-1;slot.actor.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
 for id in wanted:
  var e=wanted[id]
  if not bindings.has(id):
   for index in slots.size():
    var slot=slots[index]
    if slot.id<0 and slot.kind==e.type:
     slot.id=id;slot.state="";slot.distance=render_distance(e);slot.clock=0;slot.last_change=-1
     bindings[id]=index;break
  if bindings.has(id):animate(slots[bindings[id]],e,dt)
 highwater=maxi(highwater,bindings.size())
func animate(slot:Dictionary,e:Dictionary,dt:float):
 var actor=slot.actor
 var bucket:String=app.motion_bucket(e)
 var state:String="walk" if bucket.begins_with("walk") else "run" if bucket.begins_with("run") else bucket
 if state!=slot.state:
  var initial:bool=slot.state==""
  var phase:=0.0
  if slot.state in ["walk","run"]:
   var old=actor.clips[slot.state];phase=fmod(slot.clock,maxf(.01,(old.frames-1)/old.fps))/maxf(.01,(old.frames-1)/old.fps)
  actor.play(state);slot.state=state
  slot.clock=phase*(actor.clips[state].frames-1)/actor.clips[state].fps
  if state in ["walk","run","crawl"] and phase==0:
   slot.clock=fmod(float(e.get("phase",0)),1.0)*(actor.clips[state].frames-1)/actor.clips[state].fps
  if initial and state in ["walk","run","crawl"]:
   slot.clock=app.sources[str(e.type)+bucket].elapsed
 var moved=maxf(0,render_distance(e)-float(slot.distance));slot.distance=render_distance(e)
 if state in ["walk","run","crawl"]:
  slot.clock+=moved*8/(WORLD_PER_MODEL*e.body_scale*float(speed_cache[e.type][state]))
 elif state in ["fall","landing","rise"]:slot.clock=app.defense.clock-e.phase_started
 elif state=="death":slot.clock=app.defense.clock-e.changed
 else:
  if state=="attack" and slot.last_change!=e.changed:slot.clock=0;slot.last_change=e.changed
  slot.clock+=dt/sqrt(e.body_scale)
 var duration:float=(actor.clips[state].frames-1)/actor.clips[state].fps
 actor.retarget.apply(minf(slot.clock,duration) if state in ["death","landing","rise","attack"] else fmod(slot.clock,duration))
 actor.body.rotation=Vector3(PI*.5 if state=="crawl" else 0,float(e.heading),0)
 actor.body.position.y=.3 if state=="crawl" else 0.0
 var r=app.arena.scenery.renderer
 var world:Vector2=app.defense_world(render_position(e))
 var relative:Vector2=ForestRoute.to_camera(world,r.camera_world,r.heading)
 var ground:float=ForestEcology.height_at(world)-ForestEcology.height_at(r.camera_world)
 var units:=WORLD_PER_MODEL*float(e.body_scale)
 var eye:=Vector3(-relative.x,(r.camera_height()-ground-render_position(e).y*20),relative.y)/units
 eye.z=maxf(.6,eye.z)
 var center:=Vector3(0,.9,0)
 actor.actor_camera.projection=Camera3D.PROJECTION_PERSPECTIVE
 actor.actor_camera.position=eye;actor.actor_camera.look_at(center)
 actor.actor_camera.fov=clampf(rad_to_deg(2*atan(1.3/maxf(.3,eye.distance_to(center)))),4,110)
 actor.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
func render_position(e:Dictionary)->Vector3:
 return e.get("previous_pos",e.pos).lerp(e.pos,clampf(app.defense_clock/.05,0,1))
func render_distance(e:Dictionary)->float:
 var last_step:float=e.pos.distance_to(e.get("previous_pos",e.pos)) if e.entry_phase=="advance" else 0.0
 return maxf(0,float(e.get("travelled",0))-last_step*(1-clampf(app.defense_clock/.05,0,1)))
func presentation(e:Dictionary)->Dictionary:
 if not bindings.has(e.id):return {}
 var i:int=bindings[e.id];var actor=slots[i].actor
 return {"slot":i,"texture":actor.texture(),"ground":actor.ground_uv()}
