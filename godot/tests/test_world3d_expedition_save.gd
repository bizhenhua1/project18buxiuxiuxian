extends SceneTree
var session
var app
func _initialize():call_deferred("run")
func open_route():
 app=load("res://scenes/expedition_route.tscn").instantiate();root.add_child(app);current_scene=app;app.set_process(false)
func run():
 root.size=Vector2i(1440,900);StyleLibrary.active=true;set_meta("native_route_view",true)
 session=root.get_node("Journey");session.SAVE="user://native-route-integration-test.json"
 session.state=JourneyState.new();session.expedition_active=true
 var zone:Dictionary=session.state.zones[0];session.state.pending=zone.id
 session.state.world.input_locked=true
 var expected:int=zone.reward
 for entry in LocalRouteSpec.entries(zone,0):expected+=int(entry.get("reward",0))+int(zone.tier)
 # Exercise the same entry action used by the actual world encounter panel.
 remove_meta("native_route_view")
 assert(session.enter_battle())
 await scene_changed
 app=current_scene;app.set_process(false)
 assert(app.scene_file_path=="res://scenes/expedition_route.tscn" and get_meta("native_route_view",false))
 var reloaded:=false;var victories:=0
 for frame in 12000:
  app.paused=false
  if app.phase=="encounter":
   assert(not app.is_social());app.start_battle()
  if app.phase=="defeat":push_error("Original default formation lost the formal route");quit(1);return
  var before_phase:String=app.phase
  app._process(.05)
  if before_phase=="battle" and app.phase=="clearing":
   victories+=1
   var earned:int=session.state.stones
   app.finish_battle("victory")
   assert(session.state.stones==earned,"Duplicate finish awarded twice")
   if not reloaded:
    var done:int=app.encounter_step
    assert(session.save());app.free();app=null
    session.state=null;session.resume()
    assert(session.state.stones==earned and int(session.state.local_steps[zone.id])==done)
    open_route();assert(app.encounter_step==done)
    reloaded=true
    print("FORMAL_ROUTE_RELOAD_PASS step=",done," reward=",earned)
  if app.route_complete:break
  await process_frame
 assert(app.route_complete and reloaded and victories>0,"Formal route did not finish naturally")
 assert(session.state.stones==expected,"Incorrect combined encounter and route rewards")
 assert(session.state.cleared.has(zone.id) and session.state.pending.is_empty())
 assert(not session.state.world.input_locked)
 var earned:int=session.state.stones
 assert(not session.state.finish_local() and session.state.stones==earned)
 app.leave_button.pressed.emit()
 for frame in 4:await process_frame
 assert(current_scene.scene_file_path=="res://scenes/journey.tscn")
 var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(session.SAVE))
 assert(int(saved.stones)==expected)
 DirAccess.remove_absolute(session.SAVE)
 print("FORMAL_3D_EXPEDITION_PASS natural combat, partial reload, no duplicate reward, world return; reward=",expected)
 quit()
