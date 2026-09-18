extends SceneTree
func _initialize():call_deferred("run")
func run():
 var shell=load("res://scenes/tactical_presentation.tscn").instantiate();root.add_child(shell)
 while not shell.stage or not shell.stage.ready_stage:await process_frame
 var s=shell.stage;s.set_process(false);s.begin_tactical();s._process(0)
 for z in [0,-2,-4,-6,-8,-10,-12,-16]:
  var p:Vector2=s.camera.unproject_position(s.world_point(Vector3(0,0,z)))
  print("BOUNDARY ",z," y=",p.y/s.get_viewport().get_visible_rect().size.y)
 quit()
