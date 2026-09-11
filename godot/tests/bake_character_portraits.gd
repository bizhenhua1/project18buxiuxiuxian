extends SceneTree
func _initialize():call_deferred("run")
func run():
 var app=load("res://scenes/character_library.tscn").instantiate();root.add_child(app);app.playing=false
 for i in app.MODELS.size():
  app.select_model(i);app.playing=false;app.yaw=.1;app.distance=3.3
  for frame in 3:await process_frame
  await RenderingServer.frame_post_draw
  var im:Image=app.viewport.get_texture().get_image();im.resize(180,210,Image.INTERPOLATE_LANCZOS)
  im.save_png("res://assets/character-portraits/"+app.MODELS[i].file.get_basename()+".png")
 print("PORTRAITS_DONE");quit()
