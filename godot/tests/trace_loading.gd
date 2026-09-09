extends SceneTree
func _initialize():call_deferred("run")
func run():
 var begin=Time.get_ticks_usec()
 var scene=load("res://scenes/endless_forest.tscn")
 print("LOAD scene_resource_ms ",(Time.get_ticks_usec()-begin)/1000.0)
 var app=scene.instantiate();root.add_child(app)
 print("LOAD ready_total_ms ",(Time.get_ticks_usec()-begin)/1000.0)
 await process_frame
 await RenderingServer.frame_post_draw
 print("LOAD first_frame_ms ",(Time.get_ticks_usec()-begin)/1000.0)
 quit()
