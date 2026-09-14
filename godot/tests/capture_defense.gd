extends SceneTree
var app
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 app=load("res://scenes/defense_sample.tscn").instantiate();root.add_child(app)
 while not app.ready_sample:await process_frame
 app.restart(true);app.sim.begin()
 await create_timer(12).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/defense-50.png")
 print("DEFENSE_CAPTURE mean_ms=",app.average_ms()," alive=",app.sim.active_count())
 quit()
