extends SceneTree
var app
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 app=load("res://scenes/world3d_stage.tscn").instantiate();root.add_child(app)
 while not app.ready_stage:await process_frame
 await create_timer(.5).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/world3d-prepare.png")
 app.start_battle()
 await create_timer(7).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/world3d-battle.png")
 app.cast_test(false);app.cast_test(true)
 print("WORLD3D_CAPTURE phase=",app.phase," model bindings=",app.pool_ids.size()," fps=",Engine.get_frames_per_second())
 quit()
