extends RefCounted
const BODY=preload("res://scripts/world3d/combat_body.gd")
# Skill shapes are world-metre volumes. Damage dispatch uses stable IDs, never render slots.
var index=preload("res://scripts/world3d/spatial_index.gd").new()
var targets:Dictionary={}
var zones:Array=[]
var next_id:=0
var hits:=0
func clear():
 zones.clear();targets.clear();index.rebuild([]);next_id=0;hits=0
func sync(units:Array,to_world:Callable,clock:float):
 targets.clear();var proxies:Array=[]
 for unit in units:
  if unit.hp<=0 or unit.get("resolved",false) or clock<float(unit.get("activate_at",0)):continue
  targets[unit.id]=unit
  proxies.append({"id":unit.id,"pos":to_world.call(unit.pos),"hp":unit.hp,"radius":.3*float(unit.get("body_scale",1))})
 index.rebuild(proxies)
func apply_ids(ids:Array,center:Vector3,half_height:float,amount:float,hurt:Callable,path_end:Vector3=Vector3.INF)->int:
 var count:=0
 var along:=Vector2.ZERO
 var length_squared:=0.0
 if path_end.is_finite():
  along=Vector2(path_end.x-center.x,path_end.z-center.z);length_squared=along.length_squared()
 for id in ids:
  var unit:Dictionary=targets[id]
  if unit.hp<=0 or unit.get("resolved",false):continue
  # Ground effects do not reach airborne units above their configured vertical volume.
  var position:Vector3=index.positions[id];var height:=center.y
  var low:float=center.y-half_height;var high:float=center.y+half_height
  if path_end.is_finite():
   if length_squared>.000001:
    var t:=clampf(Vector2(position.x-center.x,position.z-center.z).dot(along)/length_squared,0,1)
    height=lerpf(center.y,path_end.y,t)
    low=height-half_height;high=height+half_height
   else:
    low=minf(center.y,path_end.y)-half_height;high=maxf(center.y,path_end.y)+half_height
  if position.y>high or position.y+BODY.height(unit)<low:continue
  hurt.call(unit,amount);count+=1
 hits+=count;return count
func burst(center:Vector3,radius:float,half_height:float,damage:float,hurt:Callable)->int:
 return apply_ids(index.circle(center,radius),center,half_height,damage,hurt)
func corridor(from:Vector3,to:Vector3,radius:float,half_height:float,damage:float,hurt:Callable)->int:
 return apply_ids(index.sweep(from,to,radius),from,half_height,damage,hurt,to)
func add_zone(center:Vector3,radius:float,half_height:float,damage:float,duration:float,interval:float)->int:
 if duration<=0 or interval<=0 or radius<0 or zones.size()>=64:return -1
 next_id+=1
 zones.append({"id":next_id,"center":center,"radius":radius,"height":half_height,"damage":damage,"duration":duration,"interval":interval,"age":0.0,"next_tick":interval})
 return next_id
func needs_targets(dt:float)->bool:
 for zone in zones:
  if zone.next_tick<=minf(zone.age+maxf(0,dt),zone.duration)+.000001:return true
 return false
func advance(dt:float,hurt:Callable):
 for i in range(zones.size()-1,-1,-1):
  var zone:Dictionary=zones[i];zone.age+=maxf(0,dt)
  while zone.next_tick<=minf(zone.age,zone.duration)+.000001:
   burst(zone.center,zone.radius,zone.height,zone.damage,hurt)
   zone.next_tick+=zone.interval
  if zone.age>=zone.duration:zones.remove_at(i)
