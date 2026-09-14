extends SceneTree
const FRAME=preload("res://scripts/world3d/character_framing.gd")
func _initialize():call_deferred("run")
func run():
 var original=load("res://scripts/battle/enemy_actor.gd").new();original.ally=true;root.add_child(original)
 await process_frame
 var cam:Camera3D=original.actor_camera
 var foot:Vector2=cam.unproject_position(Vector3.ZERO)
 var one_metre:Vector2=cam.unproject_position(Vector3.UP)
 var fraction:float=(foot.y-one_metre.y)/original.viewport.size.y
 for slot_height in [20.0,38.0,50.0]:
  var expected:float=slot_height*original.frame_scale()*fraction/20.0
  assert(is_equal_approx(FRAME.scale_for_slot(slot_height),expected),"Native scale must match actual original portrait camera projection")
 print("WORLD3D_CHARACTER_FRAME_PASS actual original camera fraction_per_metre=",fraction," old_scale_ratio=",52.0/36.0)
 original.queue_free();await process_frame
 quit()
