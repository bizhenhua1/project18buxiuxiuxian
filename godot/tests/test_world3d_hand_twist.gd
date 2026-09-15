extends SceneTree
func rotations(rig:Skeleton3D)->Array:
 var q:Array=[]
 for i in rig.get_bone_count():
  var p:=rig.get_bone_parent(i)
  q.append((q[p] if p>=0 else Quaternion.IDENTITY)*rig.get_bone_pose_rotation(i))
 return q
func _initialize():
 var a=load("res://scripts/world3d/allied_actor.gd").new();root.add_child(a);a.setup("gardener-kitty-dada.glb");a.refresh_equipment()
 var baseline=load("res://scripts/defense/defense_retarget.gd").new();baseline.configure(a.rig,a.library.bones)
 var moving:=false
 for clip in ["idle","walk","run","attack","attack","attack"]:
  if clip=="attack":a.trigger("attack")
  else:a.play(clip)
  baseline.load_clip(a.library.clips[clip])
  for frame in 121:
   var time:float=float(a.retarget.frames-1)/a.retarget.fps*frame/120.0
   # Reset helper poses before the reference, so the previous corrected frame cannot leak in.
   for group in a.retarget.twist_groups:
    for h in group[3]:a.rig.set_bone_pose_rotation(h[0],a.retarget.rest_q[h[0]])
   baseline.apply(time);var original:=rotations(a.rig)
   a.retarget.apply(time);var corrected:=rotations(a.rig)
   for name in ["手首.R","手首.L","ひじ.R","ひじ.L","人指１.R","人指１.L"]:
    var bone:int=a.rig.find_bone(name)
    assert(original[bone].angle_to(corrected[bone])<.002,"Twist distribution must preserve animated global joint rotation")
   var helper:int=a.rig.find_bone("手捩2.R")
   moving=moving or a.rig.get_bone_pose_rotation(helper).angle_to(a.retarget.rest_q[helper])>.01
 assert(moving,"Weighted twist helpers must receive animation")
 print("HAND_TWIST_PASS 726 samples including battle idle and all three attacks; wrist/elbow/finger global rotations preserved, weighted helpers animated")
 quit()

