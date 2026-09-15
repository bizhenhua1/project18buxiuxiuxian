extends "res://scripts/defense/defense_retarget.gd"
# MMD twist helpers carry skin weights but have no corresponding motion tracks.
# Distribute the animated joint's axial rotation, preserving its global pose.
var twist_groups:Array=[]
func configure(rig:Skeleton3D,names:Array)->void:
 super(rig,names)
 twist_groups.clear()
 for side in [".R",".L"]:
  for chain in [["腕","腕捩","ひじ"],["ひじ","手捩","手首"]]:
   var start:int=rig.find_bone(chain[0]+side);var end:int=rig.find_bone(chain[2]+side)
   if start<0 or end<0:continue
   var axis:Vector3=(globals[start].basis.inverse()*(globals[end].origin-globals[start].origin)).normalized()
   var helpers:Array=[]
   for suffix in ["","1","2","3"]:
    var index:int=rig.find_bone(chain[1]+suffix+side)
    if index>=0:
     helpers.append([index,1.0 if suffix.is_empty() else float(suffix)/4.0])
     # Include skin helpers in the actor's walk/run transition blending too.
     if not evaluation_bones.has(index):evaluation_bones.append(index)
   if not helpers.is_empty():twist_groups.append([start,end,axis,helpers])
 evaluation_bones.sort()
func apply(time:float)->void:
 # Clear last frame's helper rotations before evaluating the source hierarchy.
 for group in twist_groups:
  for helper in group[3]:
   if submit_pose:skeleton.set_bone_pose_rotation(helper[0],rest_q[helper[0]])
 super(time)
 if not submit_pose or data.is_empty():return

 for group in twist_groups:
  var start:int=group[0];var end:int=group[1];var axis:Vector3=group[2]
  var start_pose:Quaternion=pose_q[start]
  var end_pose:Quaternion=pose_q[end]
  var delta:Quaternion=(start_pose.inverse()*end_pose*global_q[end].inverse()*global_q[start]).normalized()
  var projection:Vector3=axis*Vector3(delta.x,delta.y,delta.z).dot(axis)
  var twist:=Quaternion(projection.x,projection.y,projection.z,delta.w)
  if twist.length_squared()<.000001:continue
  twist=twist.normalized()
  for helper in group[3]:
   var index:int=helper[0]
   var desired:Quaternion=start_pose*Quaternion.IDENTITY.slerp(twist,helper[1])*global_q[start].inverse()*global_q[index]
   var parent_pose:Quaternion=pose_q[parents[index]]
   skeleton.set_bone_pose_rotation(index,(parent_pose.inverse()*desired).normalized())
   pose_q[index]=desired
 
  var end_parent:Quaternion=pose_q[parents[end]]
  skeleton.set_bone_pose_rotation(end,(end_parent.inverse()*end_pose).normalized())
 


