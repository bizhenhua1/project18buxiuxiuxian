extends RefCounted
var skeleton:Skeleton3D
var data:=PackedFloat32Array()
var frames:=0
var fps:=30.0
var source_names:Array=[]
var rests:Array[Transform3D]=[]
var globals:Array[Transform3D]=[]
var mapping:Array[int]=[]
var hip_height:=1.0
var root_bone:=0
var in_place:=true
const CORE={"腰":"pelvis","下半身":"pelvis","上半身":"spine_01","上半身2":"spine_02","上半身3":"spine_03","首":"neck_01","頭":"head"}
func configure(rig:Skeleton3D,names:Array) -> void:
 skeleton=rig;source_names=names;rests.clear();globals.clear();mapping.clear()
 var map:=CORE.duplicate()
 for suffix in ["L","R"]:
  var side:String=suffix.to_lower()
  for pair in [["肩","clavicle"],["腕","upperarm"],["ひじ","lowerarm"],["手首","hand"],["足","thigh"],["ひざ","calf"],["足首","foot"],["足D","thigh"],["ひざD","calf"],["足首D","foot"],["足先EX","ball"],["つま先","ball"]]:map[pair[0]+"."+suffix]=pair[1]+"_"+side
  for finger in [["親指","thumb"],["人指","index"],["中指","middle"],["薬指","ring"],["小指","pinky"]]:
   for i in range(3):map[finger[0]+String.chr(0xff10+i+(0 if finger[1]=="thumb" else 1))+"."+suffix]=finger[1]+"_0"+str(i+1)+"_"+side
 for i in range(skeleton.get_bone_count()):
  rests.append(skeleton.get_bone_rest(i));globals.append(skeleton.get_bone_global_rest(i))
  var name:=skeleton.get_bone_name(i).replace("調整","")
  mapping.append(source_names.find(map.get(name,"")))
  if name=="下半身":hip_height=absf(globals[i].origin.y)
  if name=="全ての親":root_bone=i
 skeleton.reset_bone_poses()
func load_clip(clip:Dictionary) -> void:
 data=FileAccess.get_file_as_bytes(clip.file).to_float32_array();frames=int(clip.frames);fps=float(clip.fps)
 assert(data.size()==frames*(3+source_names.size()*4))
func apply(time:float) -> void:
 if data.is_empty():return
 var f:=clampf(time*fps,0,frames-1);var a:=int(f);var b:=mini(a+1,frames-1);var t:=f-a
 var stride:=3+source_names.size()*4
 var hip:=Vector3(data[a*stride],data[a*stride+1],data[a*stride+2]).lerp(Vector3(data[b*stride],data[b*stride+1],data[b*stride+2]),t)*hip_height
 if in_place:hip.x=0;hip.z=0
 var poses:Array[Transform3D]=[];poses.resize(rests.size())
 for i in range(rests.size()):
  var parent:=skeleton.get_bone_parent(i)
  var base:Transform3D=poses[parent]*rests[i] if parent>=0 else rests[i]
  if i==root_bone:base.origin+=hip
  var desired:=base.basis.get_rotation_quaternion()
  if mapping[i]>=0:
   var k:=a*stride+3+mapping[i]*4;var l:=b*stride+3+mapping[i]*4
   var qa:=Quaternion(data[k],data[k+1],data[k+2],data[k+3]).normalized()
   var qb:=Quaternion(data[l],data[l+1],data[l+2],data[l+3]).normalized()
   desired=qa.slerp(qb,t)*globals[i].basis.get_rotation_quaternion()
  var local:=poses[parent].basis.get_rotation_quaternion().inverse()*desired if parent>=0 else desired
  skeleton.set_bone_pose_rotation(i,local.normalized())
  skeleton.set_bone_pose_position(i,rests[i].origin+(hip if i==root_bone else Vector3.ZERO))
  poses[i]=Transform3D(Basis(desired),base.origin)

