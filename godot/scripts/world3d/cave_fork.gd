extends RefCounted

# The open mine fork is a short sideways transfer into two parallel corridors.
# Its distance coordinate remains the original forward axis; no diagonal tail.
const HALF_SEPARATION := 265.0

static func lateral(s:float,junction:float,transfer:float,branch:int)->float:
 if branch not in [-1,1]:return 0.0
 var t:=clampf((s-junction)/transfer,0.0,1.0)
 return branch*HALF_SEPARATION*t*t*(3.0-2.0*t)

static func heading(s:float,junction:float,transfer:float,branch:int)->float:
 if branch not in [-1,1] or s<=junction or s>=junction+transfer:return 0.0
 var t:float=(s-junction)/transfer
 var slope:float=branch*HALF_SEPARATION*6.0*t*(1.0-t)/transfer
 return atan(slope)

static func lane_distance(p:Vector2,junction:float,transfer:float,end_s:float,exits:int)->float:
 var best:float=p.distance_to(Vector2(0,clampf(p.y,0.0,junction)))
 if exits==3:best=minf(best,absf(p.x))
 for branch in [-1,1]:
  var first:float=maxf(junction,p.y-transfer)
  var last:float=minf(junction+transfer,p.y+transfer)
  for i in 25:
   var at:float=lerpf(first,last,float(i)/24.0)
   best=minf(best,p.distance_to(Vector2(lateral(at,junction,transfer,branch),at)))
  var end_x:float=branch*HALF_SEPARATION
  best=minf(best,p.distance_to(Vector2(end_x,clampf(p.y,junction+transfer,end_s))))
 return best
