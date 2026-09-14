extends SceneTree
func _initialize():call_deferred("run")
func run():
 var shell=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(shell)
 while not shell.stage or not shell.stage.ready_stage:await process_frame
 shell.stage.set_process(false)
 for actor in shell.stage.team:
  for factor in [1.0,1.8]:
   var original:Vector3=actor.scale;actor.scale=original*factor
   for move_speed in [1.0,3.0]:
    actor.trigger("revive");actor.advance(.05,Vector3(0,0,move_speed))
    var stride:float=actor.strides[actor.model_key][actor.clip]*actor.scale.x
    assert(absf(actor.clock*stride-move_speed*.05)<.00001,"Animation distance must match travel distance at both sizes")
   actor.trigger("death");actor.advance(.05,Vector3.ZERO)
   assert(is_equal_approx(actor.clock,.05),"Death must retain real-time playback")
   actor.trigger("revive");actor.scale=original
 print("WORLD3D_PARTY_STRIDE_PASS actual party walk/run at two scales; death timing retained")
 quit()
