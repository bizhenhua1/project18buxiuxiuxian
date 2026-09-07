extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var app=load("res://scenes/endless_forest.tscn").instantiate();root.add_child(app)
 app.set_process(false);app.arena.set_process(false)
 var battle_seen:=false
 for i in range(24000):
  app._process(.05);app.arena._process(.05)
  if app.phase=="battle":battle_seen=true
  if app.lap>=3:break
 assert(battle_seen and app.lap>=3,"Infinite loop did not resume")
 assert(not root.get_node("Journey").state.pending.is_empty())
 var lap=app.lap
 app.phase="defeat"
 for i in range(12):app._process(.05)
 assert(app.lap==lap+1,"Defeat did not resume")
 print("ENDLESS_PASS two automatic laps and defeat restart; isolated save")
 quit()
