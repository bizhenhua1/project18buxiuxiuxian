extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var plain:=LocalRouteSpec.profile({"route_profile":"short_battle"})
 var fork:=LocalRouteSpec.profile({"route_kind":"fork"})
 assert(fork.end==plain.end)
 for i in range(plain.events.size()):assert(fork.right[i].distance==plain.events[i].distance)
 set_meta("tour_biome","crystal");set_meta("tour_exits",3)
 var app=load("res://scenes/endless_forest.tscn").instantiate();root.add_child(app)
 app.set_process(false);app.arena.set_process(false)
 for i in range(4):await process_frame
 var renderer=app.arena.scenery.renderer
 var atlas_id:int=renderer.forest_batch.atlas.get_instance_id()
 var textures:int=renderer.forest_batch.image_keys.size()
 for i in range(100):
  app._process(.05);app.arena._process(.05)
  if app.phase=="choose":break
 assert(is_equal_approx(app.distance,100.0))
 app.choose(1)
 var elapsed:=0.0
 for i in range(120):
  app._process(.05);app.arena._process(.05);elapsed+=.05
  await process_frame
  await RenderingServer.frame_post_draw
  assert(absf(angle_difference(renderer.heading,renderer.forest_batch.order_angle))<.00011,"Stale turning order")
  assert(renderer.forest_batch.image_keys.size()==textures and renderer.forest_batch.atlas.get_instance_id()==atlas_id,"Atlas changed after choosing")
  if app.phase=="battle":break
 assert(app.phase=="battle" and elapsed<4.5)
 print("COMPACT_PASS 1100 route, events 340/850, choice-to-battle seconds=",elapsed,"; atlas unchanged and turning order current")
 quit()
