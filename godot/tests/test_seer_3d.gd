extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.size=Vector2i(1440,1000)
 var app=load("res://scenes/seer_3d_lab.tscn").instantiate();root.add_child(app)
 for clip in app.labels:
  assert(app.player.has_animation(clip),clip)
  app.play_clip(clip);app.player.play(clip,0);app.player.advance(0)
  app.player.seek(app.player.get_animation(clip).length*.4,true);app.player.advance(0);app.player.pause()
  for i in range(4):await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://../art/3d/seer/%s.png"%clip)
  print(clip," ",app.player.get_animation(clip).length)
 app.play_clip("EM_Idle");app.player.play("EM_Idle",0);app.player.advance(0);app.player.pause();app.yaw=PI+.4
 for i in range(4):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../art/3d/seer/rear.png")
 print("SEER_PREVIEW_PASS")
 quit()
