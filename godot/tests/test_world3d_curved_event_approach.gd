extends SceneTree
func _initialize():call_deferred("run")
func run():
 var shell=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(shell)
 while not shell.stage or not shell.stage.ready_stage:await process_frame
 var stage=shell.stage;stage.set_process(false)
 var pace=load("res://scripts/journey/travel_pace.gd")
 for direction in [-1,1]:
  stage.branch=direction;stage.distance=stage.route_segment.junction_s+10
  stage.next_event=stage.distance+100
  stage.team[0].position=stage.travel_destination(stage.distance)
  stage.preview.hide();stage.phase="stopping";stage.transition=0
  stage.transition_start=stage.route_segment.point(stage.distance,direction)
  stage.transition_velocity=Vector2.ZERO
  stage.transition_frame=stage.composition.frames.travel.duplicate()
  stage.encounter_anchor=stage.route_segment.point(stage.next_event,direction)
  stage.camera_brake.configure(stage.transition_start,stage.encounter_anchor,Vector2.ZERO,stage.STOP_CAMERA_SECONDS)
  var progressed:=false
  for i in 300:
   var before:Vector3=stage.team[0].position;var station:float=stage.distance
   stage._process(.025)
   assert(stage.team[0].position.distance_to(before)<=pace.RUN/20*.025+.00001,"Approach must obey locomotion budget")
   assert(stage.distance>=station,"Station must advance monotonically during camera braking")
   if stage.phase=="stopping":
    assert(stage.team[0].position.distance_to(stage.travel_destination(stage.distance))<.001,"Actor must stay on the curved route during braking")
    progressed=progressed or stage.distance>station
   else:break
  assert(progressed and stage.phase=="event","Both fork directions must reach their event")
  assert(stage.camera_origin.distance_to(stage.encounter_anchor)<.001,"Camera must finish at the planned event anchor")
 print("WORLD3D_CURVED_APPROACH_PASS both forks, route tracking, bounded speed, camera stop, event arrival")
 quit()
