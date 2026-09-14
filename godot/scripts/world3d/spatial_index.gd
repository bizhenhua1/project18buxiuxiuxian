extends RefCounted
# Combat broad phase. All shapes operate on the same world-metre XZ plane.
var cell_size:=2.0
var buckets:Dictionary={}
var positions:Dictionary={}
var radii:Dictionary={}
var max_radius:=0.0
var visited:=0
func rebuild(units:Array):
 buckets.clear();positions.clear();radii.clear();max_radius=0
 for unit in units:
  if float(unit.get("hp",1))<=0 or unit.get("resolved",false):continue
  var p:Vector3=unit.pos;var cell:=Vector2i(floor(p.x/cell_size),floor(p.z/cell_size))
  if not buckets.has(cell):buckets[cell]=[]
  buckets[cell].append(unit.id);positions[unit.id]=p;radii[unit.id]=float(unit.get("radius",.3));max_radius=maxf(max_radius,radii[unit.id])
func candidates(a:Vector2,b:Vector2)->Array:
 visited=0;var result:Array=[]
 var lo:=Vector2i(floor(a.x/cell_size),floor(a.y/cell_size));var hi:=Vector2i(floor(b.x/cell_size),floor(b.y/cell_size))
 for x in range(lo.x,hi.x+1):
  for z in range(lo.y,hi.y+1):
   for id in buckets.get(Vector2i(x,z),[]):result.append(id);visited+=1
 return result
func circle(center:Vector3,radius:float)->Array:
 var result:Array=[];var p:=Vector2(center.x,center.z);var reach:=radius+max_radius
 for id in candidates(p-Vector2.ONE*reach,p+Vector2.ONE*reach):
  var q:Vector3=positions[id]
  if p.distance_squared_to(Vector2(q.x,q.z))<=pow(radius+float(radii[id]),2):result.append(id)
 result.sort();return result
func nearest(center:Vector3,radius:float,count:int=1)->Array:
 var result:=circle(center,radius)
 result.sort_custom(func(a,b):
  var da:float=center.distance_squared_to(positions[a]);var db:float=center.distance_squared_to(positions[b])
  return a<b if is_equal_approx(da,db) else da<db)
 return result.slice(0,maxi(0,count))
func sweep(from:Vector3,to:Vector3,radius:float)->Array:
 var a:=Vector2(from.x,from.z);var b:=Vector2(to.x,to.z);var d:=b-a;var result:Array=[]
 var reach:=Vector2.ONE*(radius+max_radius)
 for id in candidates(a.min(b)-reach,a.max(b)+reach):
  var q:Vector3=positions[id];var p:=Vector2(q.x,q.z)
  var t:=clampf((p-a).dot(d)/maxf(.000001,d.length_squared()),0,1)
  if p.distance_squared_to(a+d*t)<=pow(radius+float(radii[id]),2):result.append(id)
 result.sort();return result
