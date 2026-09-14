extends SceneTree
var capture_fork:bool="--capture-fork" in OS.get_cmdline_user_args()
func capture(label:String):
 for frame in 3:await process_frame
 await RenderingServer.frame_post_draw
 var suffix:String="-relocated" if "--resolve-trunk-contacts" in OS.get_cmdline_user_args() else "-baseline"
 if "--partial-trunk-resolution" in OS.get_cmdline_user_args():suffix+="-partial"
 if "--visible-route-handoff" in OS.get_cmdline_user_args():suffix+="-near-handoff"
 if "--stream-spatial-blocks" in OS.get_cmdline_user_args():suffix+="-streamed"
 if "--shared-shell-chambers" in OS.get_cmdline_user_args():suffix+="-chambers"
 root.get_texture().get_image().save_png("res://../tempassets/work/world3d-fork-"+label+suffix+".png")
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 var shell=load("res://scenes/world3d_presentation.tscn" if capture_fork else "res://scenes/world3d_stage.tscn").instantiate();root.add_child(shell)
 var app=shell.stage if capture_fork else shell
 while not app.ready_stage:await process_frame
 app.set_process(false);app._process(0);app.start_travel()
 var events:=0;var forks:=0;var leg_time:=0.0;var max_leg:=0.0;var max_step:=0.0
 var right_first:bool="--right-first" in OS.get_cmdline_user_args()
 var long_stream:bool="--long-stream" in OS.get_cmdline_user_args()
 var required_events:int=64 if long_stream else 16
 var required_routes:int=4 if long_stream else 2
 var braking:Array=[];var current_braking:Dictionary={}
 var fork_age:=-1.0;var turn_captured:=false
 var stream_samples:Array=[]
 var straight_choices:=0
 var entrance_captures:=0
 for frame in (32000 if long_stream else 8000):
  var before:Vector3=app.team[0].position
  var old_phase:String=app.phase
  var old_route:int=app.route_number
  var camera_before:Vector2=app.camera_origin
  var heading_before:float=app.camera_heading
  app._process(.05)
  if capture_fork and "--shared-shell-chambers" in OS.get_cmdline_user_args() and app.route_number==1 and forks>0:
   if entrance_captures==0 and app.distance>=1060:
    await capture("entrance-before");entrance_captures=1
   elif entrance_captures==1 and app.distance>=1100:
    await capture("entrance-after");entrance_captures=2
  assert(app.world.camera_region!=null,"Continuous camera lost its environment at a route boundary")
  if capture_fork and fork_age>=0 and not turn_captured:
   fork_age+=.05
   if fork_age>=1.5:await capture("turn");turn_captured=true
  if old_phase=="travel" and app.phase=="stopping":
   current_braking={"route":app.route_number,"branch":app.branch,"arc_length_braking":app.camera_brake.feasible,"incoming_speed":app.transition_velocity.length(),"peak_speed":0.0,"max_heading_step":0.0,"backwards_steps":0,"samples":[]}
  elif old_phase=="stopping":
   var movement:Vector2=app.camera_origin-camera_before
   var speed:float=movement.length()/.05
   current_braking.peak_speed=maxf(current_braking.peak_speed,speed)
   current_braking.max_heading_step=maxf(current_braking.max_heading_step,absf(angle_difference(heading_before,app.camera_heading)))
   if movement.dot(app.encounter_anchor-camera_before)<-.0001:current_braking.backwards_steps+=1
   current_braking.samples.append({"speed":speed,"remaining":app.camera_origin.distance_to(app.encounter_anchor)})
   assert(app.camera_origin.is_finite())
   if app.phase in ["event","fork"]:
    current_braking.endpoint_error=app.camera_origin.distance_to(app.encounter_anchor)
    assert(current_braking.endpoint_error<.001,"Curved approach misses planned stop")
    braking.append(current_braking)
  max_step=maxf(max_step,before.distance_to(app.team[0].position))
  if old_phase in ["travel","stopping"]:
   leg_time+=.05
   assert(before.distance_to(app.team[0].position)<=TravelPace.RUN/20*.05+.0001,"Travel must respect speed even across a handoff")
   assert(leg_time<8,"Route progress must not stall or stretch an ordinary leg indefinitely")
  if app.route_number!=old_route:
   print("CONTINUOUS_HANDOFF route=",app.route_number," event=",events," pending_jobs=",app.scenery.upload_jobs.size())
   if "--visible-route-handoff" in OS.get_cmdline_user_args():
    assert(app.scenery.route_nearby_ready(app.route_segment,app.route_segment.point(app.distance,0)),"Handoff left near scenery incomplete")
  if app.phase=="fork":
   if capture_fork and forks==0:await capture("stop");fork_age=0
   forks+=1;max_leg=maxf(max_leg,leg_time);leg_time=0
   var direction:int=(1 if forks%2 else -1) if right_first else (-1 if forks%2 else 1)
   if "--straight-first" in OS.get_cmdline_user_args() and app.route_segment.exits==3:direction=2;straight_choices+=1
   assert(app.fork_buttons[direction].visible and not app.fork_buttons[direction].disabled,"Actual route choice must be reachable through the UI")
   app.fork_buttons[direction].pressed.emit()
   if app.preview.visible:
    var approach:Vector3=app.preview_path_at(-app.preview_station+.1)-app.preview.position
    assert(absf(angle_difference(app.preview.rotation.y,atan2(approach.x,approach.z)))<.0001,"Branch preview inherits a stale battle heading")
    assert(is_zero_approx(app.preview.opacity),"Reused encounter actor must start a fresh fade-in")
  elif app.phase=="event":
   events+=1;max_leg=maxf(max_leg,leg_time);leg_time=0
   if app.encounters.current().kind=="social":assert(app.encounters.choose("supplies"))
   else:
    app.start_battle()
    for tick in 200:
     app._process(.01)
     if app.phase=="battle":break
    assert(app.phase=="battle")
    # Resolve combat explicitly: this tests travel/entry/exit, not combat balance.
    app.sim.status="victory";app._process(.01)
    assert(app.encounters.resolved)
   app.start_travel();assert(app.phase=="travel")
   if app.preview.visible:
    var approach:Vector3=app.preview_path_at(-app.preview_station+.1)-app.preview.position
    assert(absf(angle_difference(app.preview.rotation.y,atan2(approach.x,approach.z)))<.0001,"Next encounter must face its new approach before appearing")
    assert(is_zero_approx(app.preview.opacity))
   if events%4==0:
    print("CONTINUOUS_EVENTS ",events," max leg=",max_leg)
    var sample:Dictionary={"events":events,"route":app.route_number,"chunks":app.scenery.chunks.size(),"pending_uploads":app.scenery.upload_jobs.size()}
    if app.scenery.trunk_placement!=null:
     sample.entries=app.scenery.trunk_placement.entries.size();sample.cells=app.scenery.trunk_placement.buckets.size()
    stream_samples.append(sample)
  if events>=required_events and app.route_number>=required_routes:break
  if frame%100==0:await process_frame
 assert(events>=required_events and forks>=1 and app.route_number>=required_routes,"Must traverse real events, forks, and successor boundaries")
 if "--straight-first" in OS.get_cmdline_user_args():assert(straight_choices>0,"Fixture must traverse a real three-way straight exit")
 if long_stream:FileAccess.open("res://../tempassets/work/world3d-long-stream-"+app.theme_key+("-relocated" if app.scenery.trunk_placement!=null else "-baseline")+".json",FileAccess.WRITE).store_string(JSON.stringify(stream_samples,"  "))
 FileAccess.open("res://../tempassets/work/world3d-curved-braking-"+("right" if right_first else "left")+".json",FileAccess.WRITE).store_string(JSON.stringify(braking,"  "))
 var max_ratio:=0.0;var backwards:=0;var heading_peak:=0.0
 for sample in braking:
  max_ratio=maxf(max_ratio,sample.peak_speed/maxf(.01,sample.incoming_speed));backwards+=sample.backwards_steps;heading_peak=maxf(heading_peak,sample.max_heading_step)
 assert(max_ratio<1.002,"Route camera accelerates above incoming speed while braking")
 assert(backwards==0,"Route camera pulls backwards away from planned stop")
 print("CURVED_BRAKING ","right" if right_first else "left"," samples=",braking.size()," peak_speed_ratio=",max_ratio," backwards=",backwards," heading_step=",heading_peak)
 print("WORLD3D_CONTINUOUS_TRAVEL_PASS events=",events," forks=",forks," routes=",app.route_number," max_leg=",max_leg," max_world_step=",max_step)
 print("FORK_UI_CHOICES straight=",straight_choices)
 if app.scenery.trunk_placement!=null:
  var placement=app.scenery.trunk_placement
  print("TRUNK_GENERATION_COST total_solve_ms=",placement.solve_total_usec/1000.0," peak_solve_ms=",placement.solve_peak_usec/1000.0," peak_reserve_ms=",placement.reserve_peak_usec/1000.0," live_entries=",placement.entries.size()," moved=",placement.moved," unresolved=",placement.unresolved)
 quit()
