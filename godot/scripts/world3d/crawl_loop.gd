extends RefCounted
# Remove accumulated climb root travel, then distribute the small residual
# rotation seam over the cycle. Source files and upright climb use stay intact.
static func close_cycle(source:PackedFloat32Array,bone_count:int)->PackedFloat32Array:
 var result:=source.duplicate();var stride:int=3+bone_count*4;var frames:int=source.size()/stride
 if frames<2:return result
 var end:int=(frames-1)*stride
 for frame in frames:
  var t:float=float(frame)/(frames-1);var offset:int=frame*stride
  for axis in 3:result[offset+axis]-=(source[end+axis]-source[axis])*t
  for bone in bone_count:
   var a:int=3+bone*4;var z:int=end+a;var p:int=offset+a
   var first:=Quaternion(source[a],source[a+1],source[a+2],source[a+3]).normalized()
   var last:=Quaternion(source[z],source[z+1],source[z+2],source[z+3]).normalized()
   var current:=Quaternion(source[p],source[p+1],source[p+2],source[p+3]).normalized()
   var adjusted:Quaternion=Quaternion.IDENTITY.slerp(first*last.inverse(),smoothstep(0,1,t))*current
   result[p]=adjusted.x;result[p+1]=adjusted.y;result[p+2]=adjusted.z;result[p+3]=adjusted.w
 return result
