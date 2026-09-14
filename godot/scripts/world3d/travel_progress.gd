extends RefCounted
# A moving waypoint must not advance faster than the actor can physically reach.
# Startup convergence spends the same distance budget as forward travel.
static func step(position:Vector3,current:float,limit:float,budget:float,point_at:Callable)->Dictionary:
 var upper:float=minf(limit,current+budget*20.0)
 var target:Vector3=point_at.call(upper)
 if position.distance_to(target)<=budget:
  return {"distance":upper,"target":target}
 if position.distance_to(point_at.call(current))>budget:
  return {"distance":current,"target":target}
 var lower:=current
 for iteration in 10:
  var middle:float=(lower+upper)*.5
  if position.distance_to(point_at.call(middle))<=budget:lower=middle
  else:upper=middle
 return {"distance":lower,"target":point_at.call(lower)}
