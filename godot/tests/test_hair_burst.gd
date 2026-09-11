extends SceneTree
func _initialize():call_deferred("run")
func run():
 var app=load("res://scripts/spaces/character_library.gd").new();root.add_child(app);app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 await process_frame
 for index in [4,5,22,23,7,3]:
  app.select_model(index)
  print("HAIR ",index," bones=",app.burst.bones.size()," mats=",app.burst.materials.size())
  app.burst.trigger()
  for i in range(60):app._process(.016)
  assert(app.burst.strength>.9)
  if index==4:
   await create_timer(.7).timeout
   await RenderingServer.frame_post_draw
   app.viewport.get_texture().get_image().save_png("F:/GitHub/project18buxiuxiuxian/tempassets/work/hair-burst.png")
  for i in range(450):app._process(.016)
  assert(app.burst.strength==0)
 print("PASS burst activate/recover/model switch")
 quit()
