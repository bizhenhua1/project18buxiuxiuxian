extends SceneTree
func _initialize():call_deferred("run")
func run():
 var app=load("res://scenes/endless_forest.tscn").instantiate();root.add_child(app)
 app.set_process(false);app.phase="choose";app.world.plan.exits=3
 for i in 8:app._update_ui();await process_frame
 app._process(0.0)
 await create_timer(.3).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/event-ui.png")
 assert(app.center_exit.visible)
 assert(app.event_box.get_global_rect().end.y<app.size.y-70)
 print("EVENT_UI_PASS");quit()
