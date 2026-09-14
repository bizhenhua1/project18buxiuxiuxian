extends SceneTree
var app
var records:Array=[]
var motion_records:Array=[]
var previous:Dictionary={}
var peaks:Dictionary={}
var previous_camera:=Vector2.ZERO
var previous_camera_speed:=-1.0
var previous_phase:=""
var stop_entry:Dictionary={}
var motion_failed:=false
func measure_motion():
 var sample:Dictionary={"time":app.clock,"phase":app.phase,"actors":[]}
 var camera_speed:float=app.camera_origin.distance_to(previous_camera)/.01
 sample.camera_origin=[app.camera_origin.x,app.camera_origin.y];sample.camera_speed=camera_speed
 if previous_phase=="stopping" and app.phase=="stopping" and stop_entry.is_empty():
  stop_entry={"incoming_speed":previous_camera_speed,"first_braking_speed":camera_speed}
  if camera_speed<=previous_camera_speed*.8:
   motion_failed=true;push_error("Camera loses incoming velocity at braking entry")
 if previous_phase=="stopping" and app.phase=="stopping":
  if camera_speed>previous_camera_speed+.05:
   if not motion_failed:push_error("Straight approach camera accelerates while stopping")
   motion_failed=true
 previous_camera=app.camera_origin;previous_camera_speed=camera_speed;previous_phase=app.phase
 var current:Dictionary={}
 for actor in app.team:
  if not actor.visible or actor.opacity<.01:continue
  var bounds:=Rect2();var initialized:=false
  var landmarks:Dictionary={}
  for bone in actor.rig.get_bone_count():
   var world:Vector3=actor.rig.global_transform*actor.rig.get_bone_global_pose(bone).origin
   var projected:Vector3=actor.portrait_presenter.presented_attachment(world,app.camera)
   var uv:Vector2=app.camera.unproject_position(projected)/app.bridge.view_size
   assert(uv.is_finite(),"Non-finite animated projection")
   if not initialized:bounds=Rect2(uv,Vector2.ZERO);initialized=true
   else:bounds=bounds.expand(uv)
   if actor.rig.get_bone_name(bone) in ["頭","腰","足首.L","足首.R"]:
    landmarks[actor.rig.get_bone_name(bone)]=[uv.x,uv.y]
  var anchor:Vector2=app.camera.unproject_position(actor.global_position)/app.bridge.view_size
  var key:=str(actor.get_instance_id())
  var item:Dictionary={"model":actor.model_key,"opacity":actor.opacity,"skeletal_bounds_uv":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],"anchor_uv":[anchor.x,anchor.y],"landmarks_uv":landmarks}
  if previous.has(key):
   var prior:Dictionary=previous[key]
   var changes:Dictionary={"anchor_delta":anchor.distance_to(prior.anchor),"bounds_height_delta":absf(bounds.size.y-prior.bounds.size.y),"bounds_center_delta":bounds.get_center().distance_to(prior.bounds.get_center())}
   for metric in changes:
    if changes[metric]>float(peaks.get(metric,{}).get("value",-1)):
     peaks[metric]={"value":changes[metric],"time":app.clock,"phase":app.phase,"previous_phase":prior.phase,"model":actor.model_key}
    if actor==app.team[0] and changes[metric]>float(peaks.get("hero_"+metric,{}).get("value",-1)):
     peaks["hero_"+metric]={"value":changes[metric],"time":app.clock,"phase":app.phase,"previous_phase":prior.phase,"model":actor.model_key}
  current[key]={"anchor":anchor,"bounds":bounds,"phase":app.phase}
  sample.actors.append(item)
 previous=current;motion_records.append(sample)
func _initialize():call_deferred("run")
func capture(label:String):
 if label=="departing" and "--inspect-roots" in OS.get_cmdline_user_args():
  var roots:Array=[]
  for chunk in app.scenery.chunks:
   var mm:MultiMesh=chunk.multimesh
   var material=mm.mesh.surface_get_material(0)
   for i in mm.instance_count:
    var transform:Transform3D=mm.get_instance_transform(i)
    if app.camera.is_position_behind(transform.origin):continue
    var screen:Vector2=app.camera.unproject_position(transform.origin)
    if screen.x<0 or screen.x>350 or screen.y<450 or screen.y>750:continue
    var custom:Color=mm.get_instance_custom_data(i)
    if absf(custom.b)<6 or absf(custom.b)>=32:continue
    roots.append({"source":material.get_meta("source_asset",""),"screen":str(screen),"position":str(transform.origin),"scale":str(transform.basis.get_scale()),"anchor":str(custom)})
  FileAccess.open("res://../tempassets/work/world3d-departure-roots.json",FileAccess.WRITE).store_string(JSON.stringify(roots,"  "))
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/world3d-flow-"+label+".png")
 var hero=app.team[0]
 var bone:int=hero.rig.find_bone("頭")
 var head:Vector3=hero.rig.global_transform*hero.rig.get_bone_global_pose(bone).origin
 var projected:Vector3=hero.portrait_presenter.projected_attachment(head,hero.global_position,app.camera,hero.portrait_presenter.vertical_offset)
 var screen:Vector2=app.camera.unproject_position(projected)/app.bridge.view_size
 records.append({"label":label,"phase":app.phase,"time":app.clock,"head_uv":[screen.x,screen.y],"depth":-app.camera.to_local(hero.global_position).z,"frame":app.frame.duplicate(true)})
 assert(screen.x>-.1 and screen.x<1.1 and screen.y>-.1 and screen.y<1,"Hero head must remain in the composition")
func advance(seconds:float):
 for i in int(round(seconds/.01)):app._process(.01);measure_motion()
func assert_travel_frame():
 for key in ["height","lens","horizon","forward","lateral","yaw"]:
  assert(is_equal_approx(float(app.frame[key]),float(app.composition.frames.travel[key])),"Travel frame must fully reach saved value: "+key)
func run():
 root.size=Vector2i(1440,900)
 var shell=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(shell);app=shell.stage
 while not app.ready_stage:await process_frame
 app.set_inspection_expanded(false)
 app.set_process(false);app._process(0)
 await capture("prepare")
 app.start_travel();advance(1.4)
 assert_travel_frame()
 assert(app.camera_origin.distance_to(app.route_segment.point(app.distance,app.branch))<.01,"Stable travel camera must not retain a speed-dependent lag")
 await capture("travel")
 for i in 500:
  app._process(.01);measure_motion()
  if app.phase=="event":break
 assert(app.phase=="event")
 assert(app.camera_origin.distance_to(app.encounter_anchor)<.001,"Braking must reach planned event camera position")
 await capture("event")
 app.start_battle();advance(.01)
 for i in range(1,app.team.size()):
  assert(app.team[i].clip=="idle","Hidden ally placement must not cause a run animation")
 advance(.29);await capture("entering")
 advance(.8);await capture("battle")
 # Inject the simulation result, but let production process the battle exit.
 # Assigning the presentation phase directly bypassed projectile cleanup and
 # party recovery, producing misleading departure screenshots.
 app.sim.status="victory";advance(.01)
 assert(app.phase=="victory" and app.encounters.resolved)
 assert(app.sim.projectiles.active.is_empty(),"Battle exit must stop live projectiles")
 app.start_travel();assert(app.phase=="travel")
 advance(.3);await capture("departing")
 advance(1.1);assert_travel_frame();await capture("travel-again")
 FileAccess.open("res://../tempassets/work/world3d-flow-framing.json",FileAccess.WRITE).store_string(JSON.stringify(records,"  "))
 FileAccess.open("res://../tempassets/work/world3d-flow-motion.json",FileAccess.WRITE).store_string(JSON.stringify({"sample_step":.01,"scope":"Animated bone bounds, not mesh silhouette; injected victory; no independent formal transition parity yet","stop_entry":stop_entry,"peaks":peaks,"frames":motion_records},"  "))
 print("WORLD3D_STOP_ENTRY ",JSON.stringify(stop_entry))
 print("WORLD3D_FLOW_MOTION ",JSON.stringify(peaks))
 print("WORLD3D_PRESENTATION_FLOW_CAPTURE seven composition checkpoints including independent prepare; simulated victory isolates departure, not a full combat clear")
 quit(1 if motion_failed else 0)
