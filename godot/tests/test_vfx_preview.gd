extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1280,800)
 var app=load("res://scenes/vfx_preview.tscn").instantiate();root.add_child(app)
 await process_frame
 app.looping=false
 for i in range(8):
  app.chosen=i;app.play()
  for f in range(12):await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://../art/3d/seer/vfx-%d.png"%i)
  assert(app.effects.get_child_count()==1)
  app.effects.get_child(0).advance(2.0)
  await process_frame
  assert(app.effects.get_child_count()==0)
 print("VFX_PREVIEW_PASS effects=8");quit()
