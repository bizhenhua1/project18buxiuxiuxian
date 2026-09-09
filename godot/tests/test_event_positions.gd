extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 for placement in ["before","after"]:
  var zone:Dictionary={"route_kind":"fork","event_placement":placement}
  var baseline:Dictionary=LocalRouteSpec.profile(zone)
  for branch in [-1,2,1]:
   var entries:=LocalRouteSpec.entries(zone,branch)
   for entry in entries:
    if entry.branch!=0:assert(entry.distance>=baseline.junction+360.0)
   entries[0].distance=-100
   assert(LocalRouteSpec.entries(zone,branch)[0].distance>0,"Event data leaked between calls")
 for placement in ["before","after"]:
  set_meta("tour_biome","crystal");set_meta("tour_exits",3);set_meta("tour_event_placement",placement)
  var app=load("res://scenes/endless_forest.tscn").instantiate();root.add_child(app)
  app.set_process(false);app.arena.set_process(false)
  var common_seen:=false
  for i in range(500):
   app._process(.05);app.arena._process(.05)
   if app.phase=="battle":
    assert(placement=="before" and app.branch==0)
    assert(app.scene_actor.route_branch==0 and app.scene_actor.route_s<ForestRoute.JUNCTION)
    common_seen=true;app.finish_battle("victory")
   if app.phase=="choose":break
  assert(app.phase=="choose")
  assert(common_seen==(placement=="before"))
  var step:int=app.encounter_step
  var chosen_at:float=app.distance
  app.choose(2)
  assert(app.phase=="travel" and app.encounter_step==step)
  for i in range(10):app._process(.05);app.arena._process(.05)
  assert(app.phase=="travel" and app.encounter_step==step,"Choice triggered immediate event")
  for i in range(150):
   app._process(.05);app.arena._process(.05)
   if app.phase=="battle":break
  assert(app.phase=="battle")
  assert(app.distance-chosen_at>=320.0)
  assert(app.distance>=ForestRoute.JUNCTION+ForestRoute.TURN_LENGTH+240.0)
  assert(app.scene_actor.route_branch==2)
  print("EVENT_POSITION_PASS ",placement," movement after choice=",app.distance-chosen_at)
  root.remove_child(app);app.queue_free();await process_frame
 for key in ["tour_biome","tour_exits","tour_event_placement"]:remove_meta(key)
 quit()
