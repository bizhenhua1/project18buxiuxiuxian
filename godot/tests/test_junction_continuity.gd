extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.size=Vector2i(1440,900)
 set_meta("tour_biome","crystal");set_meta("tour_exits",3)
 var app=load("res://scenes/endless_forest.tscn").instantiate();root.add_child(app)
 app.set_process(false);app.arena.set_process(false)
 for i in range(4):await process_frame
 var renderer=app.arena.scenery.renderer
 var batch=renderer.forest_batch
 renderer.world.camera_s=680;renderer.world.camera_branch=0
 renderer.camera_world=Vector2(0,680);renderer.heading=0
 var before:Dictionary={}
 for patch in batch.world_mist(renderer):before[patch.id]=patch.position
 # Crossing the junction changes the selected branch, not the existing mist anchors.
 renderer.world.camera_s=720;renderer.world.camera_branch=-1
 renderer.camera_world=ForestRoute.point_at(720,-1)
 var shared:=0
 for patch in batch.world_mist(renderer):
  if before.has(patch.id):
   assert(patch.position.distance_to(before[patch.id])<.001,"Effect moved to a different branch")
   shared+=1
 assert(shared>12)
 var original:Dictionary={}
 for sprite in app.world.sprites:original[sprite.id]=sprite.position
 app.phase="choose";app.choose(-1)
 for distance in [650.0,850.0,1050.0,1250.0]:
  var pose:=ForestRoute.pose(distance,-1)
  app.distance=distance;app.camera=pose.position;app.heading=pose.heading
  for view in app.views:view.sync(pose.position,pose.heading,4,0,-1,false,false,distance)
  for i in range(5):await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://captures/junctions/crystal-continuity-%d.png"%distance)
 for sprite in app.world.sprites:assert(sprite.position==original[sprite.id])
 print("CONTINUITY_PASS fixed decoration and effect anchors across fork; captured four turn positions")
 quit()
