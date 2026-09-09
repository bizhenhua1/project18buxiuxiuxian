extends SceneTree
func _initialize():call_deferred("run")
func run():
 var app=load("res://scenes/endless_forest.tscn").instantiate();root.add_child(app)
 for i in range(12):await process_frame
 await RenderingServer.frame_post_draw
 assert(not app.camera_trace.rows.is_empty())
 # Exercise the real save path without overwriting a user's capture.
 var trace=app.camera_trace
 for i in range(7210):trace.sample(app)
 assert(trace.rows.size()==trace.CAPACITY)
 print("CAMERA_TRACE_PASS");quit()
