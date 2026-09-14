extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 var shell=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(shell)
 while not shell.stage or not shell.stage.ready_stage:await process_frame
 var stage=shell.stage;stage.set_process(false)
 var pace=load("res://scripts/journey/travel_pace.gd")
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
   assert(speed>=pace.WALK and speed<=pace.RUN)
   assert(speed<=previous_speed+.0001,"Braking must not accelerate the character again")
   previous_speed=speed
   if is_equal_approx(speed,pace.WALK):walked+=.025
   stage._process(.025);elapsed+=.025
   if stage.phase not in ["travel","stopping"]:break
  assert(stage.phase=="event")
  if kind=="first":assert(elapsed<=3.05 and walked==0)
  else:assert(walked>.5 and elapsed<7,"Mixed legs need real walking without doubling travel duration")
  print("WORLD3D_ROUTE_PACE ",kind," seconds=",elapsed," walk_seconds=",walked)
 print("WORLD3D_ROUTE_PACE_PASS continuous speed through camera braking, bounded event timing")
 quit()
