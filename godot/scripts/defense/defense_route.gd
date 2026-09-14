extends "res://scripts/journey/expedition_route.gd"
const MOTION_ROWS=["walk_slow","walk","walk_fast","run","run_fast","attack","death","idle","fall","landing","rise","crawl","walk_left","walk_right","walk_left_soft","walk_right_soft"]
const DEFENSE=preload("res://scripts/defense/defense_sim.gd")
var defense=DEFENSE.new()
var sources:Dictionary={}
var defense_ready:=false
var defense_clock:=0.0
var defense_info:Label
var defense_fx:Array=[]
var defense_draw:Node2D
var line_depth:=31.0
var stage_light_enabled:=true
var storm_enabled:=true
var character_fill:=.42
var missiles
var defense_panel:PanelContainer
var crowd_atlas:SubViewport
var shared_crowd
var shared_atlas_enabled:=not ("--legacy-crowd" in OS.get_cmdline_user_args())
var near_actors
var profile_enabled:=false
var profile_usec:Dictionary={}
func profile_mark(key:String,start:int):
 if profile_enabled:profile_usec[key]=int(profile_usec.get(key,0))+Time.get_ticks_usec()-start
func _ready():
 Journey.SAVE="user://defense-route-sample.json"
 Journey.state=JourneyState.new();Journey.expedition_active=true;Journey.fighting=false
 Journey.state.pending=Journey.state.zones[0].id
 Journey.state.active_zone().theme="forest"
 super()
 model.enemy.clear();model.phase="prepare"
 phase="battle";distance=float(stops()[0]);branch=0
 arena.world_anchor=ForestRoute.pose(distance,branch).position;arena.world_facing=ForestRoute.pose(distance,branch).heading
 arena.battle_mix=1;arena.entrance_progress=1;arena.rebuild()
 live_template.poll(1)
 if not live_template.data.is_empty():live_template.current=live_template.data.frames.battle.duplicate()
 camera=arena.world_anchor;heading=arena.world_facing;live_template.advance(self,0)
 presentation_camera.reset(camera,heading,1)
 var panel:=PanelContainer.new();panel.position=Vector2(22,85);panel.z_index=300;add_child(panel);defense_panel=panel
 var plate:=StyleBoxFlat.new();plate.bg_color=Color(.04,.07,.065,.92)
 for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:plate.set_content_margin(side,10)
 panel.add_theme_stylebox_override("panel",plate)
 var column:=VBoxContainer.new();panel.add_child(column)
 defense_info=Label.new();defense_info.text="原场景 · 防线战斗：预热模型…";column.add_child(defense_info)
 var row:=HBoxContainer.new();column.add_child(row)
 for entry in [["开始防守",func():defense.begin()],["重新开始",func():reset_defense(false)],["50 来敌测试",func():reset_defense(true);defense.begin()],["迟滞结界",func():defense.pulse()]]:
  var b:=Button.new();b.text=entry[0];b.pressed.connect(entry[1]);row.add_child(b)
 var lighting:=CheckButton.new();lighting.text="舞台补光"
 var prefs:=ConfigFile.new()
 if prefs.load("user://defense-presentation.cfg")==OK:
  stage_light_enabled=prefs.get_value("view","stage_light",true)
  storm_enabled=prefs.get_value("view","storm",true)
  character_fill=clampf(float(prefs.get_value("view","character_fill",.42)),0,.65)
 lighting.button_pressed=stage_light_enabled;column.add_child(lighting)
 lighting.toggled.connect(func(value):
  stage_light_enabled=value
  save_presentation())
 var storm:=CheckButton.new();storm.text="StormMissile · 远程特效";storm.button_pressed=storm_enabled;column.add_child(storm)
 storm.toggled.connect(func(value):storm_enabled=value;save_presentation())
 var fill_row:=HBoxContainer.new();column.add_child(fill_row)
 var fill_label:=Label.new();fill_label.text="角色独立补光";fill_row.add_child(fill_label)
 var fill:=HSlider.new();fill.min_value=0;fill.max_value=.65;fill.step=.01;fill.value=character_fill;fill.custom_minimum_size.x=190;fill_row.add_child(fill)
 fill.value_changed.connect(func(value):character_fill=value;save_presentation())
 defense_draw=Node2D.new();defense_draw.z_index=190;arena.add_child(defense_draw);defense_draw.draw.connect(draw_defense)
 call_deferred("warm_defense")
func _ensure_event_preview():pass
func _sync_event_previews():pass
func warm_defense():
 crowd_atlas=SubViewport.new();crowd_atlas.size=Vector2i(1280,5120);crowd_atlas.transparent_bg=true;crowd_atlas.disable_3d=true;crowd_atlas.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(crowd_atlas)
 var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/motions/catalog.json"))
 var custom={"fall":"7_Jump_Landing_Seq","landing":"5_ARPG_Warrior_Anim_rig_Landing2","rise":"7_Getup_Seq","crawl":"3_Obstacle_Climb_Loop"}
 for kind in 5:
  for motion in MOTION_ROWS:
   var actor=preload("res://scripts/battle/enemy_actor.gd").new()
   actor.retarget=preload("res://scripts/defense/defense_retarget.gd").new()
   actor.model_scene=load("res://assets/characters3d/"+defense.config.enemies[kind].model)
   add_child(actor);actor.viewport.size=Vector2i(256,320)
   if custom.has(motion):
    for clip in catalog.clips:
     if clip.id==custom[motion]:actor.clips[motion]=clip;break
    actor.retarget.configure(actor.rig,catalog.bones)
   actor.play("walk" if motion.begins_with("walk") else "run" if motion.begins_with("run") else motion);sources[str(kind)+motion]=actor
   if motion in ["walk_left","walk_right","walk_left_soft","walk_right_soft"]:
    actor.body.rotation.y=(-1 if "left" in motion else 1)*(.3 if "soft" in motion else .65)
   if motion=="crawl":actor.body.rotation.x=PI*.5;actor.body.position.y=.3
   var cell:=TextureRect.new();cell.texture=actor.texture();cell.position=Vector2(kind*256,MOTION_ROWS.find(motion)*320);cell.size=Vector2(256,320);crowd_atlas.add_child(cell)
   await get_tree().process_frame
 if shared_atlas_enabled:
  if "--compare-atlas" in OS.get_cmdline_user_args():
   await RenderingServer.frame_post_draw
   crowd_atlas.get_texture().get_image().save_png("res://../tempassets/work/defense-atlas-before.png")
  shared_crowd=preload("res://scripts/defense/defense_shared_atlas.gd").new();shared_crowd.setup(self)
  var old_atlas=crowd_atlas;crowd_atlas=shared_crowd.viewport;old_atlas.queue_free()
  if "--compare-atlas" in OS.get_cmdline_user_args():
   for warm_frame in 3:await get_tree().process_frame
   await RenderingServer.frame_post_draw
   crowd_atlas.get_texture().get_image().save_png("res://../tempassets/work/defense-atlas-after.png")
 missiles=preload("res://scripts/defense/defense_missiles.gd").new();add_child(missiles);missiles.setup(self)
 near_actors=preload("res://scripts/defense/defense_near.gd").new();add_child(near_actors);await near_actors.setup(self)
 defense_ready=true;reset_defense(false)
 if "--stress" in OS.get_cmdline_user_args():reset_defense(true);defense.begin()
func reset_defense(stress:bool):
 if not defense_ready:return
 if missiles:missiles.clear()
 if near_actors:near_actors.reset()
 defense.reset(stress);defense.allies.clear();defense_fx.clear();defense_clock=0
 model.reset();model.enemy.clear();model.phase="prepare"
 arena.rebuild();arena.restore_after_victory() if arena.has_method("restore_after_victory") else null
 for actor in arena.equipped_actors.values():actor.trigger("revive")
 for i in model.player.size():
  var u:Dictionary=model.player[i]
  var leader:bool=arena.seer!=null and u.uid==arena.seer.uid
  if leader:u.maxHp=20;u.hp=20
  defense.allies.append({"id":i,"leader":leader,"pos":Vector3.ZERO,"hp":float(u.maxHp),"max_hp":float(u.maxHp),"range":3.0 if i<3 else 15.0,"attack":maxf(14,u.atk),"cooldown":maxf(.5,u.cd/1000.0),"next":0.0,"state":"idle","changed":0.0,"type":mini(i,4),"boss":false,"last_trigger":-1.0})
func _process(delta:float):
 if not arena:return
 model.phase="prepare"
 var lights=preload("res://scripts/battle/team_lighting.gd").profiles()
 if not stage_light_enabled:
  for state in lights:lights[state].road_energy=0.0
 arena.scenery.renderer.team_light_override=lights
 var profile_start:=Time.get_ticks_usec()
 super(delta)
 profile_mark("base_scene",profile_start)
 if not defense_ready:return
 defense_panel.position=Vector2(30,94)
 title_label.text="林间防线 · 持续来敌"
 var dt:=0.0 if paused else minf(delta,.1)*speed
 for i in defense.allies.size():
  var u=model.player[i];var a=defense.allies[i]
  if arena.world_slots.has(u.uid):
   var slot=arena.world_slots[u.uid]
   a.pos=Vector3(float(slot.x)/8,0,8.5-(float(slot.depth)-line_depth)/8)
 profile_start=Time.get_ticks_usec()
 defense_clock+=dt
 while defense_clock>=.05:
  defense_clock-=.05;defense.step(.05)
  for fx in defense.effects:
   if fx.ranged and storm_enabled:missiles.launch(fx)
   else:fx.age=0.0;defense_fx.append(fx.duplicate())
 profile_mark("simulation",profile_start)
 for i in defense.allies.size():
  var a=defense.allies[i];var u=model.player[i]
  if a.leader:a.hp=defense.life
  var actor=arena.equipped_actors.get(u.uid)
  if a.hp<=0 and u.status!="corpse":
   BattleRules.corpse(u)
   if actor:actor.trigger("death")
  else:u.hp=a.hp
  if actor and a.state=="attack" and a.last_trigger!=a.changed:
   actor.trigger("shot");a.last_trigger=a.changed
 profile_start=Time.get_ticks_usec()
 near_actors.update(dt)
 profile_mark("near",profile_start)
 profile_start=Time.get_ticks_usec()
 var used:Dictionary={}
 for e in defense.enemies:
  if defense.clock<float(e.get("activate_at",0)):continue
  if e.state=="leaked" or (e.hp<=0 and defense.clock-e.changed>3):continue
  var motion=motion_bucket(e)
  var key=str(e.type)+motion
  var near_view:Dictionary=near_actors.presentation(e)
  if near_view.is_empty():
   if not used.has(key):used[key]={"speed":0.0,"count":0}
   used[key].speed+=float(e.actual_speed)/float(e.get("body_scale",1.0));used[key].count+=1
  var source=sources[key];var tex=source.texture();var h:=38.0*float(e.get("body_scale",1.0))
  if motion in ["fall","landing","rise"]:source.elapsed=defense.clock-e.phase_started
  if motion=="death" and not e.get("death_started",false):source.elapsed=0;e.death_started=true
  var sprite:Dictionary={"actor":true,"born_at":-100.0,"hidden":false,"position":defense_world(e.get("previous_pos",e.pos).lerp(e.pos,clampf(defense_clock/.05,0,1))),"texture":tex,"w":h*.8,"h":h,"altitude":near_actors.render_position(e).y*20,"ground_anchor":Vector2(.5,source.ground_uv()),"flip":false,"kind":0,"id":900000+e.id,"region":arena.scenery.renderer.world.camera_region,"motion":"static","ecology_tint":Color(1,1,1,smoothstep(0,.7,defense.clock-e.get("born",0))),"edge_strength":0.0,"live_enemy":true,"crowd_slot":int(e.type)+5*MOTION_ROWS.find(motion),"crowd_atlas":crowd_atlas.get_texture()}
  if not near_view.is_empty():
   sprite.erase("crowd_slot");sprite.erase("crowd_atlas")
   sprite.near_slot=near_view.slot;sprite.near_atlas=near_actors.atlas.get_texture();sprite.texture=near_view.texture;sprite.ground_anchor=Vector2(.5,near_view.ground)
  arena.scenery.renderer.battle_actors.append(sprite)
 for key in sources:
  var source=sources[key]
  if shared_crowd:
   shared_crowd.set_active(key,used.has(key));source.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
  else:source.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if used.has(key) else SubViewport.UPDATE_DISABLED
  if not used.has(key) or paused:continue
  var type_scale:float=defense.config.enemies[int(str(key).left(1))].get("body_scale",1.0)
  var pace:=1.0/sqrt(type_scale)
  if source.state in ["walk","run","crawl"]:
   var measured:float=used[key].speed/maxi(1,used[key].count)
   pace=clampf(measured/(.95 if source.state=="crawl" else 1.35 if source.state=="walk" else 2.8),.15,3.5 if source.state=="crawl" else 1.65)
  source.elapsed+=dt*pace
  var clip=source.clips[source.state];var duration=float(clip.frames-1)/clip.fps
  source.retarget.apply(minf(source.elapsed,duration) if source.state in ["death","landing","rise"] else fmod(source.elapsed,duration))
 if shared_crowd:shared_crowd.finish_frame()
 profile_mark("crowd",profile_start)
 for fx in defense_fx:fx.age+=dt
 defense_fx=defense_fx.filter(func(fx):return fx.age<fx.duration+.15)
 profile_start=Time.get_ticks_usec()
 missiles.advance(dt)
 profile_mark("effects",profile_start)
 var batch=arena.scenery.renderer.forest_batch
 if batch:
  batch.material.set_shader_parameter("character_fill",character_fill)
  batch.material.set_shader_parameter("character_brightness_cap",.78)
 defense_draw.queue_redraw()
 defense_info.text="防线 %d / 20  ·  来敌 %d  ·  击败 %d  ·  漏过 %d  ·  %d FPS\n%s"%[defense.life,defense.active_count(),defense.killed,defense.leaked,Engine.get_frames_per_second(),{"prepare":"准备就绪：点击开始防守","battle":"持续来敌 · 普通怪越线扣 1 点","victory":"防守成功","defeat":"防线失守"}[defense.status]]
func save_presentation():
 var save:=ConfigFile.new();save.load("user://defense-presentation.cfg")
 save.set_value("view","stage_light",stage_light_enabled);save.set_value("view","storm",storm_enabled);save.set_value("view","character_fill",character_fill)
 save.save("user://defense-presentation.cfg")
func defense_world(p:Vector3)->Vector2:
 return arena.world_anchor+Vector2(cos(arena.world_facing),-sin(arena.world_facing))*p.x*8+Vector2(sin(arena.world_facing),cos(arena.world_facing))*(line_depth+(8.5-p.z)*8)
func defense_screen(p:Vector3)->Vector2:
 var r=arena.scenery.renderer;var w=defense_world(p)
 var local=ForestRoute.to_camera(w,r.camera_world,r.heading)
 var k=r.focal()/maxf(10,local.y)
 return Vector2(arena.size.x*.5+local.x*k,r.horizon_y()+(r.camera_height()-(ForestEcology.height_at(w)-ForestEcology.height_at(r.camera_world))-p.y*20)*k)
static func motion_bucket(e:Dictionary)->String:
 if e.hp<=0:return "death"
 if e.get("entry_phase","") in ["fall","landing","rise"]:return e.entry_phase
 if e.get("entry","")=="crawl":return "crawl"
 if e.state=="attack":return "attack"
 if e.state=="idle" or float(e.get("actual_speed",0))<.08:return "idle"
 var angle:float=e.get("heading",0)
 if e.get("entry","")=="forest" and absf(angle)>.16:
  return ("walk_left" if angle<0 else "walk_right")+("_soft" if absf(angle)<.46 else "")
 var velocity:float=e.actual_speed/float(e.get("body_scale",1.0))
 if e.get("running",false):return "run_fast" if velocity>2.9 else "run"
 return "walk_slow" if velocity<.9 else "walk_fast" if velocity>1.5 else "walk"
func draw_defense():
 if not defense_ready:return
 defense_draw.draw_line(defense_screen(Vector3(-6,0,8.5)),defense_screen(Vector3(6,0,8.5)),Color(.8,.65,.35,.5),2,true)
 for e in defense.enemies:
  if e.resolved or not e.get("health_revealed",false):continue
  var point=defense_screen(e.pos+Vector3(0,2*float(e.get("body_scale",1.0)),0))
  defense_draw.draw_line(point-Vector2(14,0),point+Vector2(14,0),Color("26332d"),3)
  defense_draw.draw_line(point-Vector2(14,0),point+Vector2(-14+28*e.hp/e.max_hp,0),Color("b68583"),3)
 for fx in defense_fx:
  var t=clampf(fx.age/maxf(.01,fx.duration),0,1)
  var p=defense_screen(fx.from.lerp(fx.to,t))
  defense_draw.draw_circle(p,3,Color("e1a294") if fx.enemy else Color("a1cdd7"))
