extends SceneTree
var app
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 var presentation:bool="--presentation" in OS.get_cmdline_user_args()
 var entry=load("res://scenes/world3d_presentation.tscn" if presentation else "res://scenes/world3d_stage.tscn").instantiate();root.add_child(entry)
 app=entry.stage if presentation else entry
 while not app.ready_stage:await process_frame
 await process_frame
 var culls:int=app.scenery.cull_updates
 for i in 3:await process_frame
 assert(app.scenery.cull_updates==culls,"Fixed camera must reuse chunk visibility")
 app.camera_origin.x+=1
 await process_frame
 assert(app.scenery.cull_updates>culls,"Moving camera must invalidate visibility")
 app.camera_origin.x-=1
 app.start_travel()
 var previous:Vector3=app.team[0].position;var worst:=0.0;var began:=Time.get_ticks_msec()
 while app.phase not in ["event","fork"] and Time.get_ticks_msec()-began<10000:
  await process_frame
  var hero=app.team[0]
  assert(-app.camera.to_local(hero.global_position).z>.5,"Travel camera must not overtake the hero")
  worst=maxf(worst,previous.distance_to(app.team[0].position));previous=app.team[0].position
 assert(app.phase=="event","First event reached without dialogue before arrival")
 assert(worst<.3,"No frame teleport")
 print("WORLD3D_FIRST_EVENT seconds=",(Time.get_ticks_msec()-began)/1000.0," max step=",worst)
 var camera_before:Vector3=app.camera.position
 app.reset_battle()
 await process_frame
 assert(app.camera.position.distance_to(camera_before)<.001,"Restart keeps camera fixed")
 app.phase="battle";app.sim.status="victory"
 app.sim.projectiles.launch(Vector3.UP,Vector3.FORWARD,14,10,false)
 app.projectile_view.lighting.impact(Vector3.ZERO)
 await process_frame
 assert(app.sim.projectiles.active.is_empty(),"Victory must stop frozen live projectiles")
 assert(not app.projectile_view.lighting.bursts.is_empty(),"Victory must preserve the independent explosion tail")
 app.distance=ForestRoute.JUNCTION;app.phase="fork"
 # The synthetic fork fixture must place the traveler at the reached fork too.
 # Route progress can no longer outrun a hero left hundreds of units behind.
 app.team[0].position=app.travel_destination(app.distance)
 app.camera_origin=app.route_segment.point(app.distance,app.branch)
 app.choose_branch(-1)
 assert(app.phase=="travel" and app.branch==-1,"Fork selection begins real curved travel")
 for i in 10:await process_frame
 assert(ForestRoute.pose(app.distance,app.branch).heading<0,"Branch has an actual world-space turn")
 print("WORLD3D_FLOW_PASS event arrival, restart camera, curved branch")
 quit()
