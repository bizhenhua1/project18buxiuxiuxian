extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 StyleLibrary.active=true
 var session=root.get_node("Journey");session.SAVE="user://mist-test.json";session.state=JourneyState.new()
 session.state.pending=session.state.zones[0].id
 var app=load("res://scenes/expedition_route.tscn").instantiate();root.add_child(app);app.set_process(false)
 for i in range(3):await process_frame
 var renderer=app.arena.scenery.renderer
 var before=renderer.forest_batch.world_mist(renderer)
 var positions:Dictionary={}
 for patch in before:positions[patch.id]=patch.position
 renderer.camera_world+=Vector2(0,50);renderer.world.camera_s+=50
 var after=renderer.forest_batch.world_mist(renderer)
 var shared:=0
 for patch in after:
  if positions.has(patch.id):
   shared+=1;assert(patch.position.distance_to(positions[patch.id])<.001,"Fog followed the camera")
 assert(shared>4)
 assert(app.arena.scenery.get_child_count()==2,"Screen-space overlay remains")
 print("WORLD_MIST_PASS fixed path anchors across camera motion; overlay removed")
 quit()
