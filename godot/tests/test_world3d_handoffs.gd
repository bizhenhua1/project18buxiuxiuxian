extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 var app=load("res://scenes/world3d_stage.tscn").instantiate();root.add_child(app)
 while not app.ready_stage:await process_frame
 app.set_process(false)
 var peak:=0
 for index in 6:
  app.distance=app.route_segment.junction_s;app.phase="fork"
  var branch:int=2 if app.world.plan.exits==3 and index%2==0 else -1 if index%2==0 else 1
  app.choose_branch(branch)
  assert(app.pending_world!=null and not app.pending_world.sprites.is_empty(),"Successor must have real preloaded props")
  while not app.scenery.upload_jobs.is_empty():app.scenery.process_uploads()
  peak=maxi(peak,app.scenery.chunks.size())
  var boundary:float=app.planned_successor.start_s
  var expected:Dictionary=app.route_segment.pose(boundary,branch)
  app.distance=boundary;var actor_before:Vector3=app.team[0].position;var camera_before:Vector2=app.camera_origin
  app.handoff_route_if_ready()
  assert(app.branch==0 and app.route_number==index+2)
  assert(app.team[0].position==actor_before and app.camera_origin==camera_before,"Handoff must not move actor or camera")
  assert(app.route_segment.point(boundary,0).distance_to(expected.position)<.001)
  assert(app.world.plan.at(boundary+50,0)!=null)
  assert(app.world.plan.at(app.route_segment.junction_s+100,-1)!=null)
  assert(app.world.plan.at(app.route_segment.junction_s+100,1)!=null)
  assert(app.world.plan.regions.size()<=4)
  await process_frame
 assert(peak<4000,"Repeated handoffs must not accumulate all old scenery")
 print("WORLD3D_HANDOFFS_PASS six live successor preloads/handoffs; peak_chunks=",peak," final_route=",app.route_number)
 if "--capture" in OS.get_cmdline_user_args():
  app.distance=app.route_segment.junction_s;app.branch=0;app.phase="fork"
  app.camera_origin=app.route_segment.point(app.distance,0);app.camera_heading=app.route_segment.heading
  app.frame=app.composition.frames.event.duplicate();app.preview.hide()
  for actor in app.team:actor.hide()
  app.team[0].show();app.team[0].position=app.position_on_route(app.distance+18,-10)
  app._process(0)
  for i in 3:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://../tempassets/work/world3d-repeated-fork.png")
 quit()
