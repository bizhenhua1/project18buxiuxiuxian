extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.size=Vector2i(1440,900)
 StyleLibrary.active=true
 var session=root.get_node("Journey")
 session.SAVE="user://choreography-isolated.json";session.state=JourneyState.new();session.expedition_active=true
 var zone=session.state.zones[0];zone.route_kind="straight";zone.route_profile="short_battle";zone.theme="forest";zone.battle_choice=true
 session.state.pending=zone.id
 var app=load("res://scenes/expedition_route.tscn").instantiate();root.add_child(app)
 await process_frame;app.set_process(false);app.arena.scene_mode=true;app.choose(-1)
 while app.is_social():app.encounter_step+=1
 app.distance=app.stops()[app.encounter_step];app.fork_transit_time=app.FORK_TRANSIT_SECONDS
 app.prepare_encounter();app.phase="travel";app.paused=true
 var hero:Dictionary=app.model.player.filter(func(u):return u.cardId=="daotong")[0]
 app.arena._process(0)
 var motion=app.arena.formation_motion
 var initial:Vector2=motion.units[hero.uid].position
 var eye:float=app.arena.scenery.renderer.travel_eye_offset
 # Reordering cannot move the default travel rig or protagonist.
 app.model.player.erase(hero);app.model.player.push_back(hero);app.arena.rebuild();app.arena._process(0)
 assert(initial.distance_to(motion.units[hero.uid].position)<.001)
 assert(is_equal_approx(eye,app.arena.scenery.renderer.travel_eye_offset))
 app.phase="encounter";app.paused=false
 for i in range(30):
  app._process(.05);await process_frame
 assert(initial.distance_to(motion.units[hero.uid].position)<.001)
 app.start_battle()
 var last:Vector2=motion.units[hero.uid].position
 var elapsed:=0.0
 while app.phase=="entering" and elapsed<6:
  app._process(.025);await process_frame;elapsed+=.025
  var now:Vector2=motion.units[hero.uid].position
  assert(last.distance_to(now)<=TravelPace.RUN*.025+.001,"Actor teleported or exceeded running speed")
  last=now
 assert(app.phase=="battle","Formation did not settle")
 print("ENTRY_SETTLED ",elapsed)
 # Entry readiness permits a small remaining spring error; test revival from a settled pose.
 for settle in range(80):app._process(.025);await process_frame
 app.paused=true;app.arena._process(0)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/choreography-battle.png")
 var battle:Vector2=motion.units[hero.uid].position
 var camera:Vector2=app.presentation_camera.position
 app.phase="defeat";hero.hp=0;app.arena.seer.trigger("death")
 app.start_battle();assert(app.phase=="reviving")
 assert(hero.hp>0)
 app.paused=false
 for i in range(28):app._process(.025);await process_frame
 assert(app.phase=="battle")
 assert(battle.distance_to(motion.units[hero.uid].position)<.01,"Revival moved the party")
 assert(camera.distance_to(app.presentation_camera.position)<.1,"Revival moved the camera")
 app.finish_battle("victory")
 last=motion.units[hero.uid].position
 for i in range(70):
  app._process(.025);await process_frame
  var now:Vector2=motion.units[hero.uid].position
  assert(last.distance_to(now)<=TravelPace.RUN*.025+.001,"Exit handoff teleported")
  last=now
 app.paused=true
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/choreography-travel.png")
 print("ENCOUNTER_CHOREOGRAPHY_PASS travel reorder, conversation, entry, stationary revival, continuous departure")
 quit()
