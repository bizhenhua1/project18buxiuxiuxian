extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1100,800)
 var model:=IslandModel.new()
 var view:=IslandView3D.new();root.add_child(view);view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 view.setup(model,IslandAssets.new())
 for theme in range(6):
  model.load_map(theme);model.preview_all=true;model.zoom=1.5;model.zoom_goal=1.5
  for cell in model.cells:
   assert("world-six/" in cell.base)
   assert(ResourceLoader.exists("res://"+cell.base))
   assert(ResourceLoader.exists("res://"+cell.cliff))
   if cell.feat!=null:assert(ResourceLoader.exists("res://"+cell.feat.src))
  for frame in range(8):await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://../tempassets/work/world-six-%d.png"%theme)
 print("WORLD_SIX_PASS six themes loaded, rendered, assets resolved")
 quit()
