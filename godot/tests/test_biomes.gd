extends SceneTree
const Catalog=preload("res://scripts/spaces/biome_catalog.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.size=Vector2i(1440,900)
 DirAccess.make_dir_recursive_absolute("res://captures/biomes")
 for key in Catalog.TITLES:
  set_meta("tour_biome",key)
  var app=load("res://scenes/endless_forest.tscn").instantiate();root.add_child(app)
  app.set_process(false);app.arena.set_process(false)
  assert(str(app.world.plan.regions[0].space.key)==key)
  assert(app.world.sprites.size()>400)
  app.distance=160;app.camera=ForestRoute.pose(app.distance,0).position
  for view in app.views:view.sync(app.camera,0,2,0,0,false,false,app.distance)
  app.arena._process(0)
  for i in range(8):await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://captures/biomes/%s-travel.png"%key)
  app.prepare_encounter();app.phase="encounter";app.start_battle()
  for i in range(70):app._process(1.0/60);app.arena._process(1.0/60)
  for i in range(4):await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://captures/biomes/%s-battle.png"%key)
  assert(app.phase=="battle")
  print("BIOME_PASS ",key," sprites=",app.world.sprites.size()," lights=",app.world.biome_lights.size())
  root.remove_child(app);app.queue_free();await process_frame
 remove_meta("tour_biome")
 quit()
