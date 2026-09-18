extends RefCounted
static func center(origin:Vector3,spec:Dictionary)->Vector3:
 return origin+Vector3(0,0,-float(spec.get("length",0))) if spec.shape=="blast" else origin
static func contains(origin:Vector3,point:Vector3,spec:Dictionary)->bool:
 var d:Vector3=point-center(origin,spec);d.y=0
 if spec.shape=="line":return d.z<=0 and (spec.get("infinite",false) or -d.z<=float(spec.length)) and absf(d.x)<=float(spec.width)*.5
 return d.length_squared()<=pow(float(spec.radius),2)
static func boundary(origin:Vector3,spec:Dictionary)->PackedVector3Array:
 var result:=PackedVector3Array();var c:=center(origin,spec)
 if spec.shape=="line":
  var w:float=spec.width*.5;var length:float=spec.length
  for p in [Vector3(-w,0,0),Vector3(w,0,0),Vector3(w,0,-length),Vector3(-w,0,-length),Vector3(-w,0,0)]:result.append(c+p)
 else:
  for i in 49:result.append(c+Vector3(cos(i*TAU/48),0,sin(i*TAU/48))*float(spec.radius))
 return result
