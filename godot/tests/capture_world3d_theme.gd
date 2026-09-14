extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 var shell=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(shell)
 while not shell.stage or not shell.stage.ready_stage:await process_frame
 var app=shell.stage;app.set_process(false);app.start_battle()
 for i in 120:
  app._process(1.0/60);await process_frame
 await RenderingServer.frame_post_draw
 assert(app.phase=="battle" and app.pool_ids.size()>0)
 var path:String="res://../tempassets/work/world3d-theme-"+app.theme_key+".png"
 root.get_texture().get_image().save_png(path)
 print("WORLD3D_THEME_CAPTURE ",app.theme_key," phase=",app.phase," models=",app.pool_ids.size()," chunks=",app.scenery.visible_chunks)
 quit()
