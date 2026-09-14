extends SceneTree
func _initialize():call_deferred("run")
func run():
 var actor=load("res://scripts/world3d/allied_actor.gd").new();root.add_child(actor);actor.setup("mary-kuromi.glb")
 for key in ["walk","run"]:
  actor.play(key)
  var duration:float=(actor.library.clips[key].frames-1)/actor.library.clips[key].fps
  var points:Array=[];var low:=INF;var high:=-INF
  var foot:int=actor.rig.find_bone("足首.L")
  for i in 121:
   actor.retarget.apply(duration*i/120.0)
   var p:Vector3=actor.body.transform*actor.rig.get_bone_global_pose(foot).origin
   points.append(p);low=minf(low,p.y);high=maxf(high,p.y)
  var velocities:Array=[];var min_z:=INF;var max_z:=-INF
  for p in points:min_z=minf(min_z,p.z);max_z=maxf(max_z,p.z)
  for i in 120:
   if maxf(points[i].y,points[i+1].y)<low+(high-low)*.3:
    var backward:float=(points[i].z-points[i+1].z)/(duration/120)
    if backward>.05:velocities.append(backward)
  velocities.sort()
  var old:float=(max_z-min_z)*2/duration
  var current:float=actor.strides[actor.model_key][key]
  var old_error:=0.0;var new_error:=0.0
  for velocity in velocities:
   old_error+=absf(velocity-old);new_error+=absf(velocity-current)
  assert(new_error<=old_error,"Planted-foot calibration must reduce support-phase velocity error")
  print("FOOT_SPEED ",key," old=",old," new=",current," support_error_before=",old_error/velocities.size()," after=",new_error/velocities.size())
 quit()

