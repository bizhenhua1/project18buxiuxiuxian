extends RefCounted
# Rebase the crawling body's transform into root bones before blending. This
# preserves the first world-space pose without rotating an upright death clip.
const SECONDS:=.4
var source:Array[Transform3D]=[]
var target:Array[Transform3D]=[]
func begin(actor):
 source.clear();target.clear()
 var rig:Skeleton3D=actor.rig
 var before:Transform3D=rig.global_transform
 var hip:int=rig.find_bone("腰")
 var hip_before:Vector3=(before*rig.get_bone_global_pose(hip)).origin if hip>=0 else actor.global_position
 for i in rig.get_bone_count():source.append(rig.get_bone_pose(i))
 actor.body.rotation.x=0;actor.body.position.y=0
 var rebase:Transform3D=rig.global_transform.affine_inverse()*before
 for i in rig.get_bone_count():
  if rig.get_bone_parent(i)<0:source[i]=rebase*source[i]
 actor.play("prone_death")
 var clip:Dictionary=actor.library.clips.prone_death
 actor.retarget.apply(float(clip.frames-1)/clip.fps)
 var hip_after:Vector3=(rig.global_transform*rig.get_bone_global_pose(hip)).origin if hip>=0 else hip_before
 var correction:Vector3=rig.global_transform.basis.inverse()*Vector3(hip_before.x-hip_after.x,0,hip_before.z-hip_after.z)
 for i in rig.get_bone_count():target.append(rig.get_bone_pose(i))
 for i in rig.get_bone_count():
  if rig.get_bone_parent(i)<0:target[i].origin+=correction
 apply(rig,0)
func apply(rig:Skeleton3D,age:float):
 var weight:=smoothstep(0,1,age/SECONDS)
 for i in source.size():rig.set_bone_pose(i,source[i].interpolate_with(target[i],weight))
