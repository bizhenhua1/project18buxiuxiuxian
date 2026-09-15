extends SceneTree
func _initialize():
 var a=load("res://scripts/world3d/allied_actor.gd").new();root.add_child(a);a.setup("cheerleader-melody.glb");a.refresh_equipment()
 for clip in ["idle","walk","run","attack"]:
  if clip=="attack":a.trigger("attack")
  else:a.play(clip)
  var duration:float=(a.retarget.frames-1)/a.retarget.fps
  for name in ["手首.R","人指１.R","人指２.R","手首.L","人指１.L","手捩2.R","腕捩2.R"]:
   var idx:int=a.rig.find_bone(name);var prev:=Quaternion.IDENTITY;var peak:=0.0;var max_rest:=0.0
   for frame in 121:
    a.retarget.apply(duration*frame/120)
    var q:Quaternion=a.rig.get_bone_pose_rotation(idx)
    if frame>0:peak=maxf(peak,rad_to_deg(prev.angle_to(q)))
    max_rest=maxf(max_rest,rad_to_deg(q.angle_to(a.rig.get_bone_rest(idx).basis.get_rotation_quaternion())))
    prev=q
   print(clip," ",name," step=",peak," restangle=",max_rest)
 quit()


