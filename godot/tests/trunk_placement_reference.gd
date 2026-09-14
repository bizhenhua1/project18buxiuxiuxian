extends RefCounted
# Generation-time bounded relocation. Preserve source dictionaries and art size.
const CELL=64.0
var buckets:Dictionary={}
var entries:Dictionary={}
var serial:=0
var moved:=0
var unresolved:=0
var checks:=0
var retired:=-INF
var solve_peak_usec:=0
var solve_total_usec:=0
var reserve_peak_usec:=0
func cells(e:Dictionary)->Array[Vector2i]:
 var extent:Vector2=e.right.abs()*e.radius+e.forward.abs()*10.5
 var lo:Vector2i=((e.center-extent)/CELL).floor();var hi:Vector2i=((e.center+extent)/CELL).floor()
 var result:Array[Vector2i]=[]
 for x in range(lo.x,hi.x+1):
  for y in range(lo.y,hi.y+1):result.append(Vector2i(x,y))
 return result
func overlap(a:Dictionary,b:Dictionary)->bool:
 checks+=1
 for axis in [a.right,a.forward,b.right,b.forward]:
  var radius:float=absf(axis.dot(a.right))*a.radius+absf(axis.dot(a.forward))*10.5+absf(axis.dot(b.right))*b.radius+absf(axis.dot(b.forward))*10.5
  if absf(axis.dot(b.center-a.center))>=radius:return false
 return true
func conflicts(e:Dictionary,cross_only:bool)->bool:
 var seen:Dictionary={}
 for cell in cells(e):
  for other in buckets.get(cell,[]):
   if other.id==e.id:continue
   if seen.has(other.id):continue
   seen[other.id]=true
   if cross_only and other.branch==e.branch:continue
   if overlap(e,other):return true
 return false
func reserve(sprite:Dictionary,route=null)->Dictionary:
 if float(sprite.get("trunk_radius",0))<=0:return sprite
 if float(sprite.get("route_s",INF))<retired:return sprite
 var began:=Time.get_ticks_usec()
 var pose:Dictionary=route.pose(sprite.route_s,sprite.route_branch) if route!=null else ForestRoute.pose(sprite.route_s,sprite.route_branch)
 var angle:float=float(sprite.get("plane_heading",pose.heading))
 var forward:=Vector2(sin(angle),cos(angle));var right:=Vector2(cos(angle),-sin(angle))
 var origin:Vector2=sprite.position
 var e:Dictionary={"id":serial,"center":origin+forward*7.5,"right":right,"forward":forward,"radius":float(sprite.trunk_radius),"branch":sprite.route_branch,"route_s":sprite.route_s}
 e.route=route
 serial+=1
 entries[e.id]=e
 for cell in cells(e):
  if not buckets.has(cell):buckets[cell]=[]
  buckets[cell].append(e)
 var reserved:=sprite.duplicate();reserved.native_trunk_id=e.id
 reserve_peak_usec=maxi(reserve_peak_usec,Time.get_ticks_usec()-began)
 return reserved
func prepare(sprites:Array,route=null)->Array:
 var result:Array=[]
 for sprite in sprites:result.append(reserve(sprite,route))
 return result
func place(sprite:Dictionary)->Dictionary:
 if float(sprite.get("trunk_radius",0))<=0:return sprite
 var began:=Time.get_ticks_usec()
 if not sprite.has("native_trunk_id"):sprite=reserve(sprite)
 var e:Dictionary=entries[sprite.native_trunk_id]
 var forward:Vector2=e.forward;var right:Vector2=e.right;var origin:Vector2=sprite.position
 # Remove the old cells before changing its center. All later trees are already
 # reserved, so a move cannot create a new overlap within the prepared batch.
 for cell in cells(e):
  buckets[cell]=buckets[cell].filter(func(other):return other.id!=e.id)
  if buckets[cell].is_empty():buckets.erase(cell)
 var result:Dictionary=sprite
 if conflicts(e,true):
  var found:=false
  # Three radii, eight directions: at most 24 attempts, maximum 1.2 metres.
  for radius in [8.0,16.0,24.0]:
   for direction in 8:
    var angle_offset:float=TAU*direction/8.0
    var candidate:Vector2=origin+(right*cos(angle_offset)+forward*sin(angle_offset))*radius
    var road_distance:float=e.route.lane_distance(candidate) if e.route!=null else ForestRoute.road_distance(candidate,true)
    var local_s:float=sprite.route_s-e.route.start_s if e.route!=null else sprite.route_s
    if road_distance<maxf(26,ForestEcology.half_width(local_s))+e.radius+8:continue
    e.center=candidate+forward*7.5
    if conflicts(e,false):continue
    result=sprite.duplicate();result.position=candidate
    result.native_original_position=origin
    found=true;moved+=1;break
   if found:break
  if not found:e.center=origin+forward*7.5;unresolved+=1
 for cell in cells(e):
  if not buckets.has(cell):buckets[cell]=[]
  buckets[cell].append(e)
 var elapsed:=Time.get_ticks_usec()-began
 solve_total_usec+=elapsed;solve_peak_usec=maxi(solve_peak_usec,elapsed)
 return result
func retire_before(distance:float):
 if distance<retired+240:return
 retired=distance
 for cell in buckets.keys():
  buckets[cell]=buckets[cell].filter(func(e):return e.route_s>=distance)
  if buckets[cell].is_empty():buckets.erase(cell)
 for id in entries.keys():
  if entries[id].route_s<distance:entries.erase(id)
func trim_after(distance:float):
 for cell in buckets.keys():
  buckets[cell]=buckets[cell].filter(func(e):return e.route_s<distance)
  if buckets[cell].is_empty():buckets.erase(cell)
 for id in entries.keys():
  if entries[id].route_s>=distance:entries.erase(id)
