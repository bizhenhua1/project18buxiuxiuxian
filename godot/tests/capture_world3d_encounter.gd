extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 var app=load("res://scenes/world3d_stage.tscn").instantiate();root.add_child(app)
 while not app.ready_stage:await process_frame
 app.start_travel()
 while app.phase!="event":await process_frame
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/world3d-event-panel.png")
 print("WORLD3D_EVENT_PANEL_CAPTURE")
 quit()
