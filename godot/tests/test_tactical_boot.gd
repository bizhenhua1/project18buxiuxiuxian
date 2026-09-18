extends SceneTree
func _initialize():call_deferred("run")
func run():
 var shell=load("res://scenes/tactical_presentation.tscn").instantiate();root.add_child(shell)
 while not shell.stage or not shell.stage.ready_stage:await process_frame
 await process_frame
 shell.stage.begin_tactical()
 for i in 30:await process_frame
 print("TACTICAL_BOOT_PASS")
 quit()
