extends SceneTree
func _initialize():call_deferred("run")
func run():
 var session=root.get_node("Journey")
 session.SAVE="user://pacing-isolated.json"
 for fork in [false,true]:
  session.state=JourneyState.new();session.expedition_active=true
  var zone=session.state.zones[0];zone.route_kind="fork" if fork else "straight";zone.route_profile="short_battle";zone.theme="crystal" if fork else "forest";zone.event_placement="after"
  session.state.pending=zone.id
  var app=load("res://scenes/expedition_route.tscn").instantiate();root.add_child(app)
  await process_frame;app.set_process(false)
  var duration:=0.0
  while app.phase not in ["sighting","encounter","choose"] and duration<6:
   app._process(.10);duration+=.10
  assert(duration>=2.8 and duration<=5,"Normal game event pacing must honor real frame duration")
  print("normal fork=",fork," first event seconds=",duration)
  if fork:
   app.choose(1);duration=0
   while app.phase=="travel" and duration<6:
    app._process(.10);duration+=.10
   assert(duration>=2.8 and duration<=5)
   assert(app.distance>=app.route_spec.junction+app.route_spec.fork_clearance)
   print("normal fork selected seconds=",duration)
  # A later event is spaced from walking speed; destination changes cannot accelerate gait.
  app.encounter_step=1;app.prepared_step=-1;app.phase="travel"
  app.distance=app.stops()[0];app.moving_envelope=0;app.fork_transit_time=app.FORK_TRANSIT_SECONDS
  assert(is_equal_approx(app.route_travel_speed(),TravelPace.WALK))
  var seconds:=0.0
  while app.phase=="travel" and seconds<6:
   var before_distance=app.distance
   app._process(.05);seconds+=.05
   assert(app.distance-before_distance<=TravelPace.WALK*.05+.021,"Never speed up to reach an event deadline")
  assert(seconds>=3 and seconds<=5)
  print("walking event seconds=",seconds)
  app.queue_free();await process_frame
 print("GAME_EVENT_PACING_PASS");quit()
