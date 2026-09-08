extends SceneTree
var test_biome:="sewer"
func _initialize() -> void:call_deferred("run")
func run() -> void:
 set_meta("tour_biome",test_biome);set_meta("tour_lap",1)
 var app=load("res://scenes/endless_forest.tscn").instantiate();root.add_child(app);current_scene=app
 app.set_process(false);app.arena.set_process(false)
 var battles:=0;var last_phase:="";var loops:=0
 for i in range(24000):
  app._process(.05);app.arena._process(.05)
  if app.phase=="battle" and last_phase!="battle":battles+=1
  last_phase=app.phase
  if app.between>=.5:
   for frame in range(3):await process_frame
   app=current_scene;assert(app!=null)
   app.set_process(false);app.arena.set_process(false)
   loops+=1
   assert(app.world.plan.exits==(2 if app.lap%2 else 3))
   if loops>=2:break
 assert(battles>=2 and loops>=2,"Infinite fork loop did not resume")
 var lap=app.lap
 app.phase="defeat"
 for i in range(10):app._process(.05)
 if app.between<.5:app._process(.05)
 for frame in range(3):await process_frame
 assert(current_scene.lap==lap+1,"Defeat did not resume")
 print("ENDLESS_PASS automatic two/three exits, battles and defeat restart")
 quit()
