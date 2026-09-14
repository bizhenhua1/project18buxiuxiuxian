extends SceneTree
func _initialize():call_deferred("run")
func run():
 var app=load("res://scenes/world3d_stage.tscn").instantiate();root.add_child(app)
 while not app.ready_stage:await process_frame
 app.set_process(false)
 for size in [Vector2i(1440,900),Vector2i(1920,1080),Vector2i(900,1200)]:
  root.size=size
  await process_frame
  for branch in [-1,0,1]:
   app.branch=branch
   for distance in [0.0,ForestRoute.JUNCTION+110.0]:
    var pose:Dictionary=app.route_segment.pose(distance,branch)
    # Frozen formal SceneFormation expression, independent of shared helper.
    var focal:float=maxf(size.x*.15,minf(size.y*.86,size.x*.72))*float(ForestSettings.values.get("camera_lens",1))
    var offset:float=-.18*size.x*32/focal
    var expected:Vector2=pose.position+Vector2(cos(pose.heading),-sin(pose.heading))*offset+Vector2(sin(pose.heading),cos(pose.heading))*32
    var actual:Vector3=app.travel_destination(distance)
    assert(Vector2(actual.x,-actual.z).distance_to(expected/20)<.0001)
    app.frame.lens=.6;app.frame.lateral=4
    assert(app.travel_destination(distance)==actual,"Camera edits must not move travel destination")
 print("WORLD3D_TRAVEL_RIG_PASS formal world destination across three aspect ratios and curved routes; independent of edited lens")
 quit()
