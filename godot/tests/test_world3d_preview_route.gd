extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 var shell=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(shell)
 while not shell.stage or not shell.stage.ready_stage:await process_frame
 var stage=shell.stage;stage.set_process(false)
 var pace=load("res://scripts/journey/travel_pace.gd")
 for direction in [-1,1]:
  stage.phase="prepare";stage.branch=direction;stage.first_leg=false
  stage.distance=stage.route_segment.junction_s-300
  stage.encounters.arrived=false;stage.encounters.resolved=false
  stage.start_travel()
  var deployed_route=stage.preview_route
  # Player route handoff must not change an already deployed monster's path.
  stage.route_segment=deployed_route.successor(direction,1842,1)
  for i in 160:
   var before:Vector3=stage.preview.position;var station:float=stage.preview_station
   stage.advance_preview(.025)
   assert(stage.preview.position.distance_to(before)<=pace.MONSTER_WALK_SPEED/20*.025+.00001)
   assert(stage.preview_station<=station and stage.preview_station>=stage.preview_stop_station)
   assert(stage.preview.position.distance_to(stage.preview_path_at(-stage.preview_station))<.001,"Monster must follow the road, not its chord")
   var delta:Vector3=stage.preview.position-before
   if delta.length()>.001:
    var forward:=Vector3(sin(stage.preview.rotation.y),0,cos(stage.preview.rotation.y))
    assert(forward.dot(delta.normalized())>.95,"Monster must face its motion")
  assert(stage.preview.position.distance_to(stage.preview_target)<.001)
  assert(stage.preview.clip=="idle" and stage.preview.opacity==1)
  stage.route_segment=deployed_route
 print("WORLD3D_PREVIEW_ROUTE_PASS both curves, bounded speed, facing, stable deployment across handoff, stop idle")
 quit()
