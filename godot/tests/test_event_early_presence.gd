extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 StyleLibrary.active=true
 var session=root.get_node("Journey");session.set_process(false);session.SAVE="user://early-event-test.json";session.state=JourneyState.new();session.expedition_active=true
 var zone=session.state.zones[0];zone.route_kind="straight";zone.route_profile="short_battle";zone.theme="forest";zone.battle_choice=true;session.state.pending=zone.id
 var app=load("res://scenes/expedition_route.tscn").instantiate();app.set_process(false);root.add_child(app)
 assert(app.prepared_step==0 and app.event_previews.size()==1)
 var first:Dictionary=app.scene_actor
 var position:Vector2=first.position
 assert(position.distance_to(app.camera)>250)
 assert(first.edge_strength==0 and not first.hidden)
 assert(not app.event_previews.has("0:1"),"Future event activated before predecessor completion")
 app.paused=false
 for i in range(35):app._process(.025)
 assert(first.position!=position and first.route_s>first.wait_s and app.phase=="travel", "Monster did not approach its fixed waiting point")
 app.phase="battle"
 app.finish_battle("victory")
 assert(app.event_previews.has("0:1"),"Next event did not activate synchronously at completion")
 var future:Dictionary=app.event_previews["0:1"]
 assert(first.hidden and not future.hidden and future.edge_strength==0)
 assert(is_equal_approx(future.born_at,app.elapsed),"New event did not start its own fade")
 var birth:float=future.born_at
 for i in range(20):app._process(.025)
 assert(future.born_at==birth,"Repeated activation restarted fade")
 for frame in range(4):await process_frame
 var mesh:=MultiMesh.new();mesh.transform_format=MultiMesh.TRANSFORM_2D;mesh.use_colors=true;mesh.use_custom_data=true;mesh.instance_count=1
 app.arena.scenery.renderer.forest_batch.write_instance(0,app.arena.scenery.renderer,{"sprite":future},mesh)
 assert(mesh.get_instance_color(0).a>.99)
 app.queue_free();await process_frame
 # Unselected branches have no event bodies and approach has no choices.
 set_meta("tour_exits",3);set_meta("tour_event_placement","after")
 app=load("res://scenes/endless_forest.tscn").instantiate();app.set_process(false);root.add_child(app)
 assert(app.phase=="approach" and not app.event_panel.visible)
 assert(app.event_previews.is_empty())
 app.choose(1);assert(app.branch==0,"Accepted route selection before reaching junction")
 for i in range(300):
  app._process(.025)
  if app.phase=="choose":break
  assert(not app.event_panel.visible and app.event_previews.is_empty())
 assert(app.phase=="choose" and app.event_panel.visible)
 assert(app.event_previews.is_empty(),"Three branch events appeared at junction")
 app.choose(1)
 assert(app.event_previews.size()==1)
 var actor:Dictionary=app.event_previews.values()[0]
 assert(actor.route_branch==1 and actor.edge_strength==0 and not actor.hidden)
 assert(app.distance<app.stops()[0],"Branch event triggered immediately at choice")
 assert(app.stops()[0]>ForestRoute.JUNCTION+ForestRoute.TURN_LENGTH+TravelPace.RUN*3,"Event remained in junction")
 var fixed_wait:float=actor.wait_s
 var last_s:float=actor.route_s
 var start:float=app.elapsed
 for i in range(140):
  app._process(.025)
  assert(actor.route_s<=last_s+.001 and actor.route_s>=fixed_wait-.001)
  last_s=actor.route_s
 assert(is_equal_approx(actor.route_s,fixed_wait) and app.discovery_actor.state=="idle")
 assert(app.phase=="travel", "Encounter fired before the approach walk")
 var position_at_stop:Vector2=actor.position
 for i in range(150):
  app._process(.025)
  assert(actor.position.distance_to(position_at_stop)<.001,"Waiting monster chased the camera")
  if app.phase=="encounter":break
 assert(app.phase=="encounter")
 assert(app.elapsed-start>=5.5 and app.elapsed-start<=7.0)
 for frame in range(4):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/fork-deep-encounter.png")
 print("FORK_APPROACH_SECONDS ",app.elapsed-start)
 print("EVENT_ACTIVATION_PASS no early popup, single selected-path event, immediate successor activation, one fade, no outline")
 quit()
