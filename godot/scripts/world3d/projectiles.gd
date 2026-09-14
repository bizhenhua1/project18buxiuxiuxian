extends RefCounted
# Positions use the caller's common combat coordinate system, never screen coordinates.
const INDEX=preload("res://scripts/world3d/spatial_index.gd")
const BODY=preload("res://scripts/world3d/combat_body.gd")
var active:Array=[]
var events:Array=[]
var next_id:=0
var broad=INDEX.new()
func clear():active.clear();events.clear();next_id=0;broad.rebuild([])
func launch(origin:Vector3,direction:Vector3,speed:float,damage:float,enemy:bool,pierce:int=1,source_id:int=-1)->int:
 var id:=next_id;next_id+=1
 active.append({"id":id,"pos":origin,"previous":origin,"origin":origin,"source_id":source_id,"velocity":direction.normalized()*speed,"damage":damage,"enemy":enemy,"remaining":maxi(1,pierce),"hit":{},"life":5.0,"radius":.15})
 return id
static func intersection(a:Vector3,b:Vector3,radius:float)->float:
 var d:=b-a;var c:=a.length_squared()-radius*radius
 if c<=0:return 0
 var length:=d.length_squared()
 if length<.000001:return INF
 var along:=a.dot(d);var discriminant:=along*along-length*c
 if discriminant<0:return INF
 var t:=(-along-sqrt(discriminant))/length
 return t if t>=0 and t<=1 else INF
func step(dt:float,targets:Array,damage_callback:Callable):
 events.clear()
 if active.is_empty():
  if not broad.positions.is_empty():broad.rebuild([])
  return
 var lookup:Dictionary={};var bounds:Array=[]
 for target in targets:
  if target.hp<=0 or target.get("resolved",false):continue
  var prior:Vector3=target.get("previous_pos",target.pos)+BODY.center_offset(target)
  var current:Vector3=BODY.center(target)
  var radius:float=.65*float(target.get("body_scale",1))
  lookup[target.query_id]={"unit":target,"prior":prior,"current":current,"radius":radius,"vertical_radius":BODY.vertical_radius(target)}
  bounds.append({"id":target.query_id,"pos":(prior+current)*.5,"radius":radius+prior.distance_to(current)*.5})
 broad.rebuild(bounds)
 for i in range(active.size()-1,-1,-1):
  var shot:Dictionary=active[i];shot.previous=shot.pos;shot.pos+=shot.velocity*dt;shot.life-=dt
  var hits:Array=[]
  for id in broad.sweep(shot.previous,shot.pos,shot.radius):
   var entry:Dictionary=lookup[id];var unit:Dictionary=entry.unit
   # Broad phase is shared by the whole step. Earlier shots may already have
   # killed a candidate; its corpse must not consume another projectile.
   if unit.hp<=0 or unit.get("resolved",false):continue
   if shot.hit.has(id) or bool(unit.query_enemy)==bool(shot.enemy):continue
   # Posture-aware ellipsoid proxy. Transform only the relative segment, so
   # the resulting time of impact still maps to the original projectile path.
   var stretch:float=(shot.radius+entry.radius)/(shot.radius+entry.vertical_radius)
   var a:Vector3=shot.previous-entry.prior;var b:Vector3=shot.pos-entry.current
   a.y*=stretch;b.y*=stretch
   var t:=intersection(a,b,shot.radius+entry.radius)
   if t!=INF:hits.append({"id":id,"t":t})
  hits.sort_custom(func(a,b):return a.id<b.id if is_equal_approx(a.t,b.t) else a.t<b.t)
  for hit in hits:
   if lookup[hit.id].unit.hp<=0 or lookup[hit.id].unit.get("resolved",false):continue
   shot.hit[hit.id]=true;shot.remaining-=1
   damage_callback.call(lookup[hit.id].unit,shot.damage)
   events.append({"shot":shot.id,"position":shot.previous.lerp(shot.pos,hit.t),"target":hit.id})
   if shot.remaining<=0:break
  if shot.remaining<=0 or shot.life<=0:active.remove_at(i)
