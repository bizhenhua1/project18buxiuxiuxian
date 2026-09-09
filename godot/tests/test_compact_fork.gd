extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 set_meta("tour_biome","crystal");set_meta("tour_exits",3)
 var app=load("res://scenes/endless_forest.tscn").instantiate();root.add_child(app)
 app.set_process(false);app.arena.set_process(false)
 for i in range(4):await process_frame
 var renderer=app.arena.scenery.renderer
 for sprite in app.world.sprites:
  if sprite.get("shell",false):
   assert(is_equal_approx(sprite.w/sprite.h,sprite.texture.get_width()/float(sprite.texture.get_height())),"Arch aspect ratio changed")
   assert(absf(sprite.plane_heading)<=ForestRoute.TURN_ANGLE+.001)
 var contact=renderer.forest_batch.contact_profile(app.world.sprites.filter(func(s):return s.get("shell",false))[0].texture.get_image())
 for foot in contact:assert(foot>.75 and foot<1.0)
 var atlas_id:int=renderer.forest_batch.atlas.get_instance_id()
 var textures:int=renderer.forest_batch.image_keys.size()
 for i in range(100):
  app._process(.05);app.arena._process(.05)
  if app.phase=="choose":break
 assert(is_equal_approx(app.distance,ForestRoute.JUNCTION-100.0))
 app.choose(1)
 var elapsed:=0.0
 var previous:float=app.distance
 for i in range(120):
  app._process(.05);app.arena._process(.05);elapsed+=.05
  assert(app.distance>=previous,"Transit moved backwards")
  assert(app.distance-previous<40.0,"Transit teleported")
  previous=app.distance
  await process_frame
  await RenderingServer.frame_post_draw
  assert(absf(angle_difference(renderer.heading,renderer.forest_batch.order_angle))<.00011,"Stale turning order")
  assert(renderer.forest_batch.image_keys.size()==textures and renderer.forest_batch.atlas.get_instance_id()==atlas_id,"Atlas changed after choosing")
  if app.phase=="battle":break
 assert(app.phase=="battle" and elapsed<5.5)
 assert(app.distance>=ForestRoute.JUNCTION+app.route_spec.fork_clearance)
 print("COMPACT_PASS natural arch ratios, earlier choice, continuous transit; choice-to-battle seconds=",elapsed,"; atlas unchanged and turning order current")
 quit()
