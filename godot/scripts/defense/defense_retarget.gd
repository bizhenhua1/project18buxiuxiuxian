extends "res://scripts/spaces/preview_retarget.gd"
# Same global-rotation retargeting; invariant rest transforms are prepared once.
var parents:PackedInt32Array
var rest_q:Array[Quaternion]=[]
var global_q:Array[Quaternion]=[]
var pose_q:Array[Quaternion]=[]
var evaluation_bones:=PackedInt32Array()
# Diagnostic isolation only: production always submits every evaluated pose.
var submit_pose:=true
func configure(rig:Skeleton3D,names:Array)->void:
 super(rig,names)
 parents.resize(rests.size());rest_q.clear();global_q.clear();pose_q.clear()
 for i in rests.size():
  parents[i]=rig.get_bone_parent(i)
  rest_q.append(rests[i].basis.get_rotation_quaternion())
  global_q.append(globals[i].basis.get_rotation_quaternion())
  pose_q.append(Quaternion.IDENTITY)
  rig.set_bone_pose_rotation(i,rest_q[i]);rig.set_bone_pose_position(i,rests[i].origin)
 # Unmapped accessory chains retain their rest poses. Only ancestors of animated
 # bones participate in the global-to-local rotation calculation.
 var required:Dictionary={}
 for i in mapping.size():
  if mapping[i]<0:continue
  var cursor:int=i
  while cursor>=0 and not required.has(cursor):
   required[cursor]=true;cursor=parents[cursor]
 evaluation_bones.clear()
 for i in rests.size():
  if required.has(i):evaluation_bones.append(i)
func apply(time:float)->void:
 if data.is_empty():return
 var f:=clampf(time*fps,0,frames-1);var a:=int(f);var b:=mini(a+1,frames-1);var t:=f-a
 var stride:=3+source_names.size()*4
 var hip:=Vector3(data[a*stride],data[a*stride+1],data[a*stride+2]).lerp(Vector3(data[b*stride],data[b*stride+1],data[b*stride+2]),t)*hip_height
 if in_place:hip.x=0;hip.z=0
 if submit_pose:skeleton.set_bone_pose_position(root_bone,rests[root_bone].origin+hip)
 for i in evaluation_bones:
  var parent:int=parents[i]
  if mapping[i]<0:
   pose_q[i]=pose_q[parent]*rest_q[i] if parent>=0 else rest_q[i]
   continue
  var k:=a*stride+3+mapping[i]*4;var l:=b*stride+3+mapping[i]*4
  var qa:=Quaternion(data[k],data[k+1],data[k+2],data[k+3]).normalized()
  var qb:=Quaternion(data[l],data[l+1],data[l+2],data[l+3]).normalized()
  var desired:=qa.slerp(qb,t)*global_q[i]
  var local:=pose_q[parent].inverse()*desired if parent>=0 else desired
  if submit_pose:skeleton.set_bone_pose_rotation(i,local.normalized())
  pose_q[i]=desired
