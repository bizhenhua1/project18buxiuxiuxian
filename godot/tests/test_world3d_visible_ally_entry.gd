extends SceneTree
func _initialize():call_deferred("run")
func run():
 var shell=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(shell)
 while not shell.stage or not shell.stage.ready_stage:await process_frame
 var stage=shell.stage;stage.set_process(false)
 assert(stage.team.size()>1)
 var actor=stage.team[1]
 var target:Vector3=stage.slot_position(1)
 actor.position=target+Vector3(1,0,1);actor.set_opacity(1)
 stage.start_battle()
 var previous:Vector3=actor.position
 stage._process(.05)
 assert(actor.position.distance_to(previous)<=TravelPace.RUN/20*.05+.00001,"Visible ally cannot teleport to its slot")
 assert(actor.position.distance_to(target)<previous.distance_to(target))
 for i in 200:
  if stage.phase=="battle":break
  previous=actor.position;stage._process(.05)
  assert(actor.position.distance_to(previous)<=TravelPace.RUN/20*.05+.00001)
 assert(stage.phase=="battle" and actor.position.distance_to(target)<.03)
 print("WORLD3D_VISIBLE_ALLY_ENTRY_PASS bounded world movement and actual arrival before combat")
 quit()
