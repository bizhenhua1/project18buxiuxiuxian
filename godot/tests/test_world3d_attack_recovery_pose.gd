extends SceneTree
func _initialize():call_deferred("run")
func run():
 var shell=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(shell)
 var app=shell.stage
 while not app.ready_stage:await process_frame
 app.set_process(false);app._process(0)
 var actor=app.team[0]
 assert(not actor.attacks.is_empty())
 actor.attack_seconds=.7;actor.trigger("attack")
 actor.advance(.71,Vector3.ZERO)
 assert(actor.clip=="idle")
 var positions:Array=[];var rotations:Array=[]
 for bone in actor.retarget.evaluation_bones:
  positions.append(actor.rig.get_bone_pose_position(bone))
  rotations.append(actor.rig.get_bone_pose_rotation(bone))
 actor.advance(0,Vector3.ZERO)
 for i in actor.retarget.evaluation_bones.size():
  var bone:int=actor.retarget.evaluation_bones[i]
  assert(positions[i].distance_to(actor.rig.get_bone_pose_position(bone))<.00001,"No pose jump at attack/idle boundary")
  assert(rotations[i].angle_to(actor.rig.get_bone_pose_rotation(bone))<.001,"No rotation jump at attack/idle boundary")
 for i in 12:actor.advance(1.0/60,Vector3.ZERO)
 assert(actor.locomotion_blend_age>=actor.LOCOMOTION_BLEND_SECONDS)
 var position:Vector3=actor.position
 actor.trigger("attack");actor.advance(.1,Vector3.ZERO)
 assert(actor.clip=="attack" and actor.position==position,"Recovery must not delay another strike or move root")
 print("WORLD3D_ATTACK_RECOVERY_PASS terminal continuity, bounded blend, next strike, fixed root")
 quit()
