extends RefCounted
static func build(rig:Skeleton3D,side:int,amount:float=1.0)->Dictionary:
 var result:Dictionary={};var suffix:String=".R" if side==0 else ".L"
 var wrist:int=rig.find_bone("手首"+suffix)
 if wrist<0:return result
 var grip:Transform3D=rig.get_bone_global_rest(wrist)*preload("res://scripts/spaces/weapon_preview.gd").palm_mount(rig,wrist,side)
 var inward:Vector3=grip.basis.z*(-1.0 if side==0 else 1.0)
 for finger in ["人指","中指","薬指","小指","親指"]:
  for joint in 3:
   var index:int=rig.find_bone(finger+String.chr(0xff10+joint+(0 if finger=="親指" else 1))+suffix)
   if index<0:continue
   var rest:Transform3D=rig.get_bone_global_rest(index)
   var children:=rig.get_bone_children(index);var along:Vector3=rest.basis.y
   if not children.is_empty():along=(rig.get_bone_global_rest(children[0]).origin-rest.origin).normalized()
   var axis:=along.cross(inward).normalized()
   if axis.length_squared()<.1:continue
   var angle:float=([.25,.5,.65] if finger=="親指" else [.85,1.15,.8])[joint]
   result[index]=rig.get_bone_rest(index).basis.get_rotation_quaternion()*Quaternion((rest.basis.inverse()*axis).normalized(),angle*amount)
 return result
