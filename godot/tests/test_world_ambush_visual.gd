extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1200,800)
 var model:=IslandModel.new()
 var start:=model.player
 var target:=start
 for offset in IslandModel.NBS:
  if model.lookup.has(start+offset):target=start+offset;break
 model.blocked[target]={"art":"assets/style2/hound.png"}
 model.explored.erase(target)
 var view:=IslandView3D.new();root.add_child(view);view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);view.setup(model,IslandAssets.new());view.set_process(false)
 for i in range(4):await process_frame
 view._process(0)
 assert(model.zoom==2.4)
 assert(model.go_to(target))
 for i in range(160):
  model.advance(.01);view._process(.01)
  await process_frame
  if model.rebounding and model.ambush_elapsed>.48 and model.ambush_elapsed<.5:
   assert(view.hero.clip=="hit")
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("F:/GitHub/project18buxiuxiuxian/tempassets/work/world-ambush.png")
 assert(not model.walking and model.player==start)
 await create_timer(1.5).timeout
 for tile in view.tiles.values():
  for child in tile.root.get_children():assert(not child is CPUParticles3D)
 print("WORLD_AMBUSH_VISUAL_PASS hit clip, return position, nearest zoom, particles released")
 quit()
