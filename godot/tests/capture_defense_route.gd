extends SceneTree
var app
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 app=load("res://scenes/defense_route.tscn").instantiate();root.add_child(app)
 while not app.defense_ready:await process_frame
 await create_timer(1).timeout
 app.reset_defense(true);app.defense.begin()
 await create_timer(8).timeout
 var slots:Dictionary={}
 for actor in app.arena.scenery.renderer.battle_actors:
  if actor.has("near_slot"):
   assert(actor.near_slot>=0 and actor.near_slot<15)
   slots[int(actor.near_slot)/3]=true
  if actor.has("crowd_slot"):
   assert(actor.crowd_slot>=0 and actor.crowd_slot<80)
   slots[int(actor.crowd_slot)%5]=true
 assert(slots.size()==5,"All five crowd model regions remain bound")
 var live_atlas:Image=app.crowd_atlas.get_texture().get_image()
 for actor in app.arena.scenery.renderer.battle_actors:
  if actor.has("crowd_slot"):
   var slot:int=actor.crowd_slot
   assert(live_atlas.get_region(Rect2i((slot%5)*256,(slot/5)*320,256,320)).get_used_rect().has_area(),"Every referenced crowd cell must contain a rendered model")
 print("DEFENSE_ACTIVE_CELLS_PASS")
 # Shared atlas clears inactive cells; inspect a deliberately enabled walk row.
 var saved_visibility:Dictionary={}
 if app.shared_crowd:
  for key in app.sources:
   saved_visibility[key]=app.shared_crowd.groups[key].visible
   app.shared_crowd.set_active(key,str(key).substr(1)=="walk")
  app.shared_crowd.finish_frame()
  app.set_process(false)
  for warm_frame in 3:await process_frame
  await RenderingServer.frame_post_draw
 var atlas:Image=app.crowd_atlas.get_texture().get_image()
 var signatures:Dictionary={}
 for i in 5:signatures[hash(atlas.get_region(Rect2i(i*256,320,256,320)).get_data())]=true
 assert(signatures.size()==5,"Five live model textures must be distinct")
 atlas.get_region(Rect2i(0,320,1280,320)).save_png("res://../tempassets/work/defense-shared-lit-row.png")
 if app.shared_crowd:
  for key in saved_visibility:app.shared_crowd.set_active(key,saved_visibility[key])
  app.set_process(true)
  for settle_frame in 3:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/defense-route.png")
 print("NEAR_INDEPENDENT ",app.near_actors.bindings.size()," calibrated strides ",app.near_actors.speed_cache)
 print("DEFENSE_ROUTE_CAPTURE fps=",Engine.get_frames_per_second()," alive=",app.defense.active_count()," peak=",app.defense.peak)
 app.stage_light_enabled=false
 await create_timer(.2).timeout
 assert(app.arena.scenery.renderer.team_light().road_energy==0)
 assert(app.arena.scenery.renderer.forest_batch.material.get_shader_parameter("character_fill")>0)
 app.storm_enabled=false
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/defense-independent-fill.png")
 app.paused=true;app.missiles.clear()
 app.missiles.launch({"from":Vector3(0,1,4),"to":Vector3(0,1,0),"duration":.2})
 app.missiles.advance(.21)
 assert(app.missiles.flights.is_empty() and app.missiles.bursts.size()==1)
 assert(not app.arena.scenery.renderer.combat_lights.is_empty(),"Impact light survives flight while stage light is off")
 print("DEFENSE_STORM_PASS stage switch, projectile, independent impact light")
 app.missiles.clear();app.defense_fx.clear();app.defense.status="battle"
 var kept:Dictionary={}
 for e in app.defense.enemies:
  if kept.has(e.type):e.resolved=true;e.state="leaked";continue
  kept[e.type]=true;e.resolved=false;e.hp=e.max_hp;e.state="walk";e.entry="road";e.entry_phase="advance";e.activate_at=0
  e.pos=Vector3((e.type-2)*1.9,0,5.0 if e.type==3 else 6.5);e.previous_pos=e.pos;e.heading=.25;e.actual_speed=1.0
 await create_timer(.2).timeout
 await RenderingServer.frame_post_draw
 assert(app.near_actors.bindings.size()==5)
 for slot in app.near_actors.slots:
  if slot.id>=0:
   assert(slot.actor.viewport.size==Vector2i(640,800))
   assert(slot.actor.actor_camera.projection==Camera3D.PROJECTION_PERSPECTIVE)
 root.get_texture().get_image().save_png("res://../tempassets/work/defense-near-close.png")
 print("NEAR_CLOSE_PASS five independent perspective actors, including 1.8x giant")
 quit()
