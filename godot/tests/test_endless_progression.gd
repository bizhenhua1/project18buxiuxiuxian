extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 for key in ["tour_party","tour_stones","tour_lap","tour_exits","tour_event_placement"]:
  if has_meta(key):remove_meta(key)
 var app=load("res://scenes/endless_forest.tscn").instantiate();app.set_process(false);root.add_child(app);current_scene=app
 var choices:=0;var events:=0
 var scene_id:int=app.get_instance_id();var arena_id:int=app.arena.get_instance_id()
 var last_distance:float=app.distance;var last_elapsed:float=app.elapsed
 var leg_time:=0.0
 var measured:=false
 var timings:Array=[]
 for i in range(14000):
  app=current_scene;app.set_process(false)
  if app.lap>=12:break
  app.paused=false
  match app.phase:
   "choose":app.choose(-1);choices+=1;leg_time=0;measured=true
   "encounter":
    assert(not app.is_social(),"Unwanted social event in endless demo")
    if measured:
     timings.append(snappedf(leg_time,.01));assert(leg_time>=2.99 and leg_time<=7.0,"Event travel outside 3-7 seconds: %f" % leg_time);measured=false
    if app.is_social():app.resolve("supplies");events+=1
    else:app.start_battle()
   "battle":app.finish_battle("victory");events+=1
  var previous_lap:int=app.lap
  var previous_phase:String=app.phase
  if measured and app.phase=="travel":leg_time+=.05
  app._process(.05)
  if previous_phase=="clearing" and app.phase=="travel":leg_time=0;measured=true
  assert(app.get_instance_id()==scene_id and app.arena.get_instance_id()==arena_id,"Continuing recreated scene or actors")
  assert(app.distance>=last_distance and app.elapsed>=last_elapsed,"Continuing reset progress")
  last_distance=app.distance;last_elapsed=app.elapsed
  if app.lap!=previous_lap:
   assert(not app.opening_leg,"Continuing restarted opening leg")
   assert(app.modulate.a==1.0,"Continuing faded scene")
  if i%20==0 or app.changing_leg:await process_frame
 assert(current_scene.lap>=12,"Progression stopped before eleven completed routes")
 assert(choices>=11 and events>=22)
 assert(app.distance>ForestRoute.END_AT,"Test did not pass the original finite route length")
 print("EVENT_TRAVEL_SECONDS ",timings)
 print("ENDLESS_PROGRESSION_PASS same scene, monotonic distance/time, no opening run or black fade; choices=",choices," events=",events)
 quit()
