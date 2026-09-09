extends SceneTree
const CAMERA=preload("res://scripts/journey/journey_camera.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.size=Vector2i(1440,900)
 var walking=CAMERA.new()
 for i in range(120):walking.advance_walk(1,1.0/60,false)
 var offset:float=walking.walk_offset
 walking.advance_walk(0,.1,true);assert(walking.walk_offset==offset)
 assert(absf(walking.walk_offset)<=3.0)
 for steps in [30,60,144]:
  var c=CAMERA.new();c.reset(Vector2.ZERO,PI-.01,0)
  for i in range(steps):c.advance(Vector2(0,100),-PI+.01,1,1.0/steps)
  assert(c.position.distance_to(Vector2(0,100))<.001)
  assert(absf(angle_difference(c.angle,-PI+.01))<.001)
  var old:Vector2=c.position;c.advance(Vector2(500,500),0,0,.05,true);assert(c.position==old)
 var app=load("res://scenes/endless_forest.tscn").instantiate();root.add_child(app)
 await process_frame
 app.set_process(false);app.arena.set_process(false);app.choose(-1)
 var renderer=app.arena.scenery.renderer
 var material=app.arena.scenery.ground_material
 for rate in [.5,1.0,4.0]:
  app.speed=rate;app.phase="travel";app.paused=false
  for frame in range(90):
   var previous_pace:float=app.arena.seer.travel_speed()
   var calibrated:bool=app.arena.seer.world_scale_calibrated
   app._process(1.0/60)
   if calibrated:assert(is_equal_approx(previous_pace,app.arena.seer.travel_speed()))
   assert(not app.arena.is_processing())
   assert(renderer.camera_world.is_equal_approx(app.camera))
   assert(Vector2(material.get_shader_parameter("camera_world")).is_equal_approx(renderer.camera_world))
   if absf(float(material.get_shader_parameter("horizon"))-renderer.horizon_y()/app.arena.scenery.size.y)>.00001:
    print("MISMATCH ",frame," ground=",material.get_shader_parameter("horizon")," renderer=",renderer.horizon_y()," size=",app.arena.scenery.size," view=",renderer.view_size," ratio=",renderer.horizon_ratio)
    quit(1);return
   assert(absf(float(material.get_shader_parameter("camera_height"))-renderer.camera_height())<.00001)
  print("CAMERA_SNAPSHOT_PASS speed=",rate)
 var consumed:float=app.arena.seer.previous_distance
 app.arena.seer.sync(0,"travel",1,false,4,true,consumed+100)
 assert(app.arena.seer.previous_distance==consumed)
 app.paused=true;var position:Vector2=app.camera
 app._process(.05);app.arena._process(.05);assert(position==app.camera)
 print("JOURNEY_CAMERA_PASS");quit()
