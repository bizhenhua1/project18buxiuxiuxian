extends RefCounted
# Stable composition destination; edited camera lens must not move the actor.
const DEPTH:=32.0
static func offset(width:float,reference_focal:float)->Vector2:
 return Vector2(-.18*width*DEPTH/maxf(1,reference_focal),DEPTH)
static func reference_focal(size:Vector2)->float:
 return maxf(size.x*.15,minf(size.y*.86,size.x*.72))*float(ForestSettings.values.get("camera_lens",1.0))
