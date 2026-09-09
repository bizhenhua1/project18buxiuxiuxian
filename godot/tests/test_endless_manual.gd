extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.size=Vector2i(1440,900)
 var app=load("res://scenes/endless_forest.tscn").instantiate();app.set_process(false);root.add_child(app);current_scene=app
 app.phase="choose";app.distance=ForestRoute.PAUSE_AT;app.paused=false
 for i in range(50):app._process(.05)
 assert(app.phase=="choose" and app.branch==0)
 app.choose(-1);app.encounter_step=0;app.distance=app.stops()[0];app.phase="encounter"
 for i in range(50):app._process(.05)
 assert(app.phase=="encounter" and app.encounter_step==0)
 app.phase="defeat"
 for i in range(30):app._process(.05)
 assert(app.phase=="defeat" and current_scene==app)
 app.phase="travel";app.distance=app.route_spec.end-1
 app.paused=true;app._process(0)
 var camera:Vector2=app.camera;var time:float=app.elapsed;var progress:float=app.distance
 var actor_id:int=app.arena.seer.get_instance_id()
 root.get_node("Journey").state.stones=123
 var pose:Dictionary=ForestRoute.pose(app.distance,app.branch)
 app.append_leg()
 assert(current_scene==app and app.arena.seer.get_instance_id()==actor_id)
 assert(app.camera==camera and app.distance==progress and app.elapsed==time)
 assert(ForestRoute.pose(progress,0).position.distance_to(pose.position)<.001)
 assert(absf(ForestRoute.pose(progress,0).heading-pose.heading)<.001)
 assert(root.get_node("Journey").state.stones==123)
 app.restart_from_beginning();await process_frame;await process_frame
 assert(current_scene!=app and current_scene.lap==1 and current_scene.distance<progress)
 current_scene.set_process(false)
 print("ENDLESS_MANUAL_PASS manual choices, stationary death, in-place extension, explicit restart only")
 quit()
