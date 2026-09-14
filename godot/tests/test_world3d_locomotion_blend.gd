extends SceneTree
const ACTOR=preload("res://scripts/world3d/allied_actor.gd")
func _initialize():call_deferred("run")
func run():
 var actors:Array=[]
 for i in 2:
  var actor=ACTOR.new();root.add_child(actor);actor.setup("gardener-kitty-dada.glb")
  actor.locomotion_blend_enabled=i==0;actors.append(actor)
 var comparisons:=0
 for velocity in [Vector3(0,0,3),Vector3.ZERO,Vector3(0,0,1),Vector3(0,0,3)]:
  for actor in actors:actor.retarget.apply(actor.clock)
  var before:Array[Quaternion]=[]
  for bone in actors[0].retarget.evaluation_bones:before.append(actors[0].rig.get_bone_pose_rotation(bone))
  for actor in actors:actor.advance(.01,velocity)
  var blended_delta:=0.0;var direct_delta:=0.0
  for i in before.size():
   var bone:int=actors[0].retarget.evaluation_bones[i]
   blended_delta+=before[i].angle_to(actors[0].rig.get_bone_pose_rotation(bone))
   direct_delta+=before[i].angle_to(actors[1].rig.get_bone_pose_rotation(bone))
  assert(direct_delta>.01,"Fixture must exercise an actual pose transition")
  assert(blended_delta<direct_delta*.2,"First transition frame still snaps")
  for frame in 20:
   for actor in actors:actor.advance(.01,velocity)
  assert(actors[0].clock==actors[1].clock,"Blend must not retime animation")
  for bone in actors[0].retarget.evaluation_bones:
   assert(actors[0].rig.get_bone_pose_position(bone).is_equal_approx(actors[1].rig.get_bone_pose_position(bone)))
   assert(actors[0].rig.get_bone_pose_rotation(bone).is_equal_approx(actors[1].rig.get_bone_pose_rotation(bone)))
  assert(actors[0].position==Vector3.ZERO and actors[1].position==Vector3.ZERO,"Pose blending must not move world anchors")
  comparisons+=1
 # Death interrupts a pending walk transition immediately and keeps original timing.
 for actor in actors:actor.advance(.01,Vector3.ZERO);actor.trigger("death");actor.advance(.01,Vector3.ZERO)
 for bone in actors[0].retarget.evaluation_bones:
  assert(actors[0].rig.get_bone_pose_rotation(bone).is_equal_approx(actors[1].rig.get_bone_pose_rotation(bone)))
 print("WORLD3D_LOCOMOTION_BLEND_PASS transitions=",comparisons," original timing and death preserved")
 quit()
