extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.size=Vector2i(1600,1043)
 StyleLibrary.active=true
 var session=root.get_node("Journey");session.set_process(false)
 for pace in [.5,1.0,2.0,4.0]:
  session.SAVE="user://travel-reference-test.json";session.state=JourneyState.new();session.expedition_active=true
  var zone=session.state.zones[0];zone.route_kind="straight";zone.route_profile="short_battle";zone.theme="forest";zone.battle_choice=true;session.state.pending=zone.id
  var app=load("res://scenes/expedition_route.tscn").instantiate();app.set_process(false);root.add_child(app)
  app.paused=true;app._process(0)
  var hero:Dictionary=app.model.player.filter(func(u):return u.cardId=="investigator")[0]
  var initial_origin:Vector2=ForestRoute.pose(app.distance,app.branch).position
  var offset:Vector2=app.arena.formation_motion.units[hero.uid].position-initial_origin
  assert(absf(offset.y-32)<.001,"Invalid initial travel anchor")
  assert(absf(app.camera.y-initial_origin.y-app.live_template.current.forward)<.001,"First frame used legacy camera")
  app.speed=pace;app.paused=false
  var frames:=0
  # Compare the moving rig with its own static/editor keyframe, before event anticipation.
  while frames<300:
   var dt:float=[1.0/30,1.0/60,1.0/120][frames%3]
   if app.stops()[0]-app.distance<app.route_travel_speed()*.8:break
   app._process(dt);frames+=1
   var origin:Vector2=ForestRoute.pose(app.distance,app.branch).position
   var actual:Vector2=app.arena.formation_motion.units[hero.uid].position-origin
   assert(actual.distance_to(offset)<.01,"Running actor fell behind route anchor")
   assert(absf(app.camera.y-origin.y-app.live_template.current.forward)<.01,"Camera acquired speed-dependent lag")
   assert(app.arena.formation_motion.units[hero.uid].position.y-app.camera.y>15,"Camera overtook actor")
  print("TRAVEL_REFERENCE pace=",pace," frames=",frames," actor_depth=",app.arena.formation_motion.units[hero.uid].position.y-app.camera.y)
  if pace==1:
   await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://../tempassets/work/travel-reference-fixed.png")
  app.queue_free();await process_frame
 print("TRAVEL_REFERENCE_PASS initial keyframe, moving reference, 0.5/1/2/4 speed, variable timestep")
 quit()
