extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var actor=load("res://scripts/battle/seer_actor.gd").new();root.add_child(actor)
 actor.world_units_per_meter=30.0
 var poses:=[]
 for steps in [60,144,237]:
  actor.previous_distance=0;actor.walk_mix=1;actor.clip=""
  actor.play("EM_Walk");actor.player.seek(0,true);actor.player.advance(0)
  var distance:=0.0
  for i in range(steps):
   distance=actor.WALK_STRIDE_METERS*30*2.5*(i+1)/steps
   actor.sync(1.0/steps,"travel",1,false,1,true,distance)
  poses.append(actor.player.current_animation_position)
  assert(absf(actor.player.current_animation_position-actor.WALK_DURATION*.5)<.001)
 var stopped:float=actor.player.current_animation_position
 actor.sync(.02,"travel",1,true,2,true,actor.previous_distance)
 assert(is_equal_approx(stopped,actor.player.current_animation_position))
 actor.sync(.02,"travel",1,false,2,true,actor.previous_distance)
 assert(is_equal_approx(stopped,actor.player.current_animation_position))
 var walk:Animation=actor.player.get_animation("EM_Walk")
 for t in range(walk.get_track_count()):
  if walk.track_get_type(t)!=Animation.TYPE_POSITION_3D or not str(walk.track_get_path(t)).ends_with("全ての親"):continue
  var first:=walk.position_track_interpolate(t,0)
  var last:=walk.position_track_interpolate(t,walk.length)
  assert(first.distance_to(last)<.00001)
 print("SEER_LOCOMOTION_PASS distance-driven poses=",poses," pace=",actor.travel_speed())
 quit()
