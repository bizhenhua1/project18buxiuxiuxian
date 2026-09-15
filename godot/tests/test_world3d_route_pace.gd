extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 var shell=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(shell)
 while not shell.stage or not shell.stage.ready_stage:await process_frame
 var stage=shell.stage;stage.set_process(false)
 var pace=load("res://scripts/journey/travel_pace.gd")
 var hero=stage.team[0]
 for gait in ["walk","run"]:
  hero.action=0;hero.dead=false;hero.play(gait);hero.clock=0
  var speed:float=(stage.walk_pace() if gait=="walk" else stage.run_pace())/20.0
  hero.advance(.05,Vector3(0,0,speed))
  assert(hero.clip==gait)
  assert(hero.clock/.05<=1.051,"Route movement must respect the model's natural cadence")
  print("WORLD3D_CADENCE ",gait," rate=",hero.clock/.05," speed_mps=",speed)
 for kind in ["first","linear","fork"]:
  stage.phase="prepare";stage.first_leg=kind=="first"
  stage.branch=1 if kind=="fork" else 0
  stage.distance=stage.route_segment.junction_s+stage.route_segment.turn_length+20 if kind=="fork" else 0
  stage.encounters.arrived=false;stage.encounters.resolved=false
  stage.team[0].position=stage.travel_destination(stage.distance)
  stage.camera_origin=stage.route_segment.point(stage.distance,stage.branch)
  stage.start_travel()
  var elapsed:=0.0;var walked:=0.0;var previous_speed:float=pace.RUN
  for i in 400:
   var speed:float=stage.route_locomotion_speed()
   assert(speed>=stage.walk_pace()-.0001 and speed<=stage.run_pace()+.0001)
   assert(speed<=previous_speed+.0001,"Braking must not accelerate the character again")
   previous_speed=speed
   if is_equal_approx(speed,stage.walk_pace()):walked+=.025
   stage._process(.025);elapsed+=.025
   if stage.phase not in ["travel","stopping"]:break
  assert(stage.phase=="event")
  if kind=="first":assert(elapsed<=3.05 and walked==0)
  else:assert(walked>.5 and elapsed<7,"Mixed legs need real walking without doubling travel duration")
  print("WORLD3D_ROUTE_PACE ",kind," seconds=",elapsed," walk_seconds=",walked)
 print("WORLD3D_ROUTE_PACE_PASS continuous speed through camera braking, bounded event timing")
 quit()
