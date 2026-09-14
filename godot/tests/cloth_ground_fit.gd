extends RefCounted
# Offline feasibility study only. Native runtime does not call this solver.
static func apply(rig:Skeleton3D)->int:
 var changed:=0
 for child in rig.get_bone_count():
  var parent:int=rig.get_bone_parent(child)
  if parent<0 or not rig.get_bone_name(parent).begins_with("sk_"):continue
  var child_pose:Transform3D=rig.global_transform*rig.get_bone_global_pose(child)
  var parent_pose:Transform3D=rig.global_transform*rig.get_bone_global_pose(parent)
  var from:Vector3=child_pose.origin-parent_pose.origin
  var length:float=from.length()
  if child_pose.origin.y>=.035 or parent_pose.origin.y<.035 or length<.00001:continue
  var required_y:float=clampf(.035-parent_pose.origin.y,-length,length)
  var horizontal:=Vector2(from.x,from.z).normalized()
  if horizontal.length_squared()<.5:horizontal=Vector2.RIGHT
  var radius:float=sqrt(maxf(0,length*length-required_y*required_y))
  var target:=Vector3(horizontal.x*radius,required_y,horizontal.y*radius)
  var correction:=Quaternion(from.normalized(),target.normalized())
  var desired:Quaternion=correction*parent_pose.basis.get_rotation_quaternion()
  var grand:int=rig.get_bone_parent(parent)
  var grand_basis:Basis=rig.global_transform.basis
  if grand>=0:grand_basis*=rig.get_bone_global_pose(grand).basis
  rig.set_bone_pose_rotation(parent,(grand_basis.get_rotation_quaternion().inverse()*desired).normalized())
  changed+=1
 return changed
