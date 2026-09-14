extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 var session=root.get_node("Journey");session.set_process(false)
 session.SAVE="user://formal-travel-baseline-test.json";session.state=JourneyState.new();session.expedition_active=true
 session.state.pending=session.state.zones[0].id
 var zone:Dictionary=session.state.zones[0];zone.theme="forest";zone.route_kind="straight";zone.route_profile="short_battle"
 var app=load("res://scenes/expedition_route.tscn").instantiate();root.add_child(app)
 await process_frame
 app.set_process(false);app.arena.set_process(false);app.paused=false
 for i in 140:app._process(.01)
 assert(app.phase=="travel","Must capture actual travel before the event")
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/formal-travel-baseline.png")
 var renderer=app.arena.scenery.renderer;var hero=app.arena.seer
 var matches:Array=renderer.battle_actors.filter(func(a):return a.get("live_character",false))
 assert(matches.size()==1)
 var actor:Dictionary=matches[0]
 var relative:Vector2=ForestRoute.to_camera(actor.position,renderer.camera_world,renderer.heading)
 var ground:float=ForestEcology.height_at(actor.position)-ForestEcology.height_at(renderer.camera_world)
 var factor:float=renderer.focal()/relative.y
 var foot:=Vector2(renderer.view_size.x*.5+relative.x*factor,renderer.horizon_y()+(renderer.camera_height()-ground-actor.altitude)*factor)
 var dimensions:=Vector2(actor.w,actor.h)*factor
 var origin:Vector2=foot-actor.ground_anchor*dimensions
 var landmarks:Dictionary={}
 for name in ["頭","腰","足首.L","足首.R"]:
  var bone:int=hero.rig.find_bone(name)
  if bone<0:continue
  var uv:Vector2=hero.actor_camera.unproject_position(hero.rig.global_transform*hero.rig.get_bone_global_pose(bone).origin)/Vector2(hero.viewport.size)
  var point:Vector2=(origin+uv*dimensions)/renderer.view_size
  landmarks[name]=[point.x,point.y]
 var report:Dictionary={"phase":app.phase,"distance":app.distance,"camera":[renderer.camera_world.x,renderer.camera_world.y],"frame":app.live_template.current,"viewport":[renderer.view_size.x,renderer.view_size.y],"actor_position":[actor.position.x,actor.position.y],"depth":relative.y,"portrait_height":actor.h,"portrait_anchor":[actor.ground_anchor.x,actor.ground_anchor.y],"landmarks_uv":landmarks}
 report.route_zone=zone.duplicate(true);report.forest_settings=ForestSettings.values.duplicate(true)
 report.model=hero.model_key
 report.animation={"state":hero.state,"elapsed":hero.elapsed,"clip_id":hero.clips[hero.state].id,"blend_time":hero.blend_time,"body_yaw":hero.body.rotation.y}
 FileAccess.open("res://../tempassets/work/formal-travel-baseline.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("FORMAL_TRAVEL_BASELINE_READY ",JSON.stringify(report))
 quit()
