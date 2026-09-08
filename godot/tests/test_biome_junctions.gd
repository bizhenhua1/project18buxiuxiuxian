extends SceneTree
const Catalog=preload("res://scripts/spaces/biome_catalog.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.size=Vector2i(1440,900)
 DirAccess.make_dir_recursive_absolute("res://captures/junctions")
 for key in Catalog.TITLES:
  for exits in [2,3]:
   set_meta("tour_biome",key);set_meta("tour_exits",exits);set_meta("tour_lap",1)
   var app=load("res://scenes/endless_forest.tscn").instantiate();root.add_child(app)
   app.set_process(false);app.arena.set_process(false)
   assert(app.world.plan.validate().is_empty())
   assert(app.world.plan.regions.size()==exits+1)
   app.phase="choose";app.distance=ForestRoute.PAUSE_AT;app.phase_time=2
   app._process(0)
   for i in range(5):await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://captures/junctions/%s-%d.png"%[key,exits])
   app.choose(2 if exits==3 else -1)
   assert(app.branch==(2 if exits==3 else -1))
   app.distance=ForestRoute.JUNCTION+180;app._process(.01)
   assert(app.world.camera_region!=null)
   assert(app.world.camera_region.branch==app.branch)
   for i in range(3):await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://captures/junctions/%s-%d-exit.png"%[key,exits])
   print("JUNCTION_PASS ",key," exits=",exits)
   root.remove_child(app);app.queue_free();await process_frame
 for key in ["tour_biome","tour_exits","tour_lap"]:remove_meta(key)
 quit()
