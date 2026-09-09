extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1200,850)
 var model=IslandModel.new()
 model.cells.clear();model.lookup.clear();model.explored.clear();model.blocked.clear()
 for i in range(4):
  var cell={"c":i,"r":0,"h":1 if i==2 else 0,"base":"assets/cave/ground-tile.png","feat":null,"layer":"land"}
  model.cells.append(cell);model.lookup[Vector2i(i,0)]=cell;model.remember(Vector2i(i,0))
 model.player=Vector2i.ZERO;model.pivot=Vector2(.75,.75);model.preview_all=true;model.zoom=2;model.zoom_goal=2
 var view=IslandView3D.new();root.add_child(view);view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 view.setup(model,IslandAssets.new());await process_frame
 view.set_process(false)
 assert(model.go_to(Vector2i(3,0)))
 var step=IslandModel.STEP_SECONDS/12.0
 var previous=model.avatar()
 for i in range(12):
  model.advance(step);view._process(step)
  var current=model.avatar()
  assert(is_equal_approx(current.x-previous.x,step/IslandModel.STEP_SECONDS),"Flat movement must be constant speed")
  previous=current
 assert(model.walking and model.has_height_step(),"Continue directly into the height transition")
 model.walk_t=.30
 assert(not model.is_jumping() and is_equal_approx(model.avatar().y,0),"Walk to the lip before taking off")
 model.walk_t=.50;view._process(.28)
 assert(model.avatar().y>1,"Clear the upper ledge")
 assert(view.hero.was_jumping)
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../art/3d/seer/world-hero-jump.png")
 model.advance(model.step_seconds()*.5+.001);view._process(.01)
 assert(model.has_height_step())
 model.walk_t=.40
 assert(not model.is_jumping() and is_equal_approx(model.avatar().y,1),"Downward step stays on upper surface until lip")
 model.walk_t=.50
 assert(model.is_jumping() and model.avatar().y<1.11,"Downward hop has only a small lift")
 model.walk_t=.75
 assert(model.avatar().y<1,"Descend beyond the edge")
 for i in range(70):model.advance(.03);view._process(.03)
 assert(not model.walking and model.player==Vector2i(3,0))
 assert(is_equal_approx(view.hero.body.position.y,0),"Feet must land on the actual tile surface")
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../art/3d/seer/world-hero-idle.png")
 for i in range(7):
  view.hero.select_model(i);view._process(.05)
  assert(view.hero.body!=null)
 model.lookup[model.player].layer="water"
 model.lookup[model.player].base="assets/world/forest/base/water_1.png"
 for i in range(15):view._process(.03)
 assert(view.hero.body.position.y<-.05 and view.hero.ripple.visible)
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../art/3d/seer/world-water.png")
 var pulse=view.hero.ripples.filter(func(p):return p.age<1.0)[0]
 var position_before=pulse.mesh.position
 var grid_before=pulse.grid
 model.player=Vector2i(2,0);view._process(.05)
 assert(pulse.grid==grid_before and pulse.mesh.position.is_equal_approx(position_before),"Ripples must remain at the footfall, not follow the hero")
 print("WORLD_HERO_PASS continuous path, uphill/downhill jump, grounded landing");quit()
