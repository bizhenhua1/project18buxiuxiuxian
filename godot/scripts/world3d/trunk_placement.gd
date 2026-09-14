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
var partial_resolution:=OS.get_cmdline_user_args().has("--partial-trunk-resolution")
func penetration(a:Dictionary,b:Dictionary)->float:
 var depth:=INF
 for axis in [a.right,a.forward,b.right,b.forward]:
  var radius:float=absf(axis.dot(a.right))*a.radius+absf(axis.dot(a.forward))*10.5+absf(axis.dot(b.right))*b.radius+absf(axis.dot(b.forward))*10.5
  depth=minf(depth,radius-absf(axis.dot(b.center-a.center)))
 return maxf(0,depth)
func contacts(e:Dictionary)->Dictionary:
 var result:Dictionary={};var seen:Dictionary={}
 for cell in cells(e):
  for other in buckets.get(cell,[]):
   if other.id==e.id or seen.has(other.id):continue
   seen[other.id]=true;checks+=1
   var depth:=penetration(e,other)
   if depth>0:result[other.id]=depth
 return result
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
   if cross_only and other.branch==e.branch and other.route==e.route:continue
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
 var state:=begin_place(sprite)
 while not state.done:step_place(state)
 return state.result
func begin_place(sprite:Dictionary)->Dictionary:
 var state:Dictionary={"done":true,"result":sprite,"attempt":0}
 if float(sprite.get("trunk_radius",0))<=0:return state
 # A queued source may outlive its reservation after route cancellation/retirement.
 if float(sprite.get("route_s",INF))<retired:return state
 var began:=Time.get_ticks_usec()
 if not sprite.has("native_trunk_id"):sprite=reserve(sprite)
 if not sprite.has("native_trunk_id") or not entries.has(sprite.native_trunk_id):return state
 var e:Dictionary=entries[sprite.native_trunk_id]
 var forward:Vector2=e.forward;var right:Vector2=e.right;var origin:Vector2=sprite.position
 # Remove the old cells before changing its center. All later trees are already
 # reserved, so a move cannot create a new overlap within the prepared batch.
 for cell in cells(e):
  buckets[cell]=buckets[cell].filter(func(other):return other.id!=e.id)
  if buckets[cell].is_empty():buckets.erase(cell)
 state.merge({"result":sprite,"sprite":sprite,"e":e,"origin":origin,"done":false},true)
 if not conflicts(e,true):finish_place(state)
 elif partial_resolution:
  state.original_contacts=contacts(e)
  state.best_score=0.0
  for depth in state.original_contacts.values():state.best_score+=float(depth)
  state.best_position=origin
 record_cost(began)
 return state
func step_place(state:Dictionary):
 if state.done:return
 var began:=Time.get_ticks_usec()
 var e:Dictionary=state.e;var origin:Vector2=state.origin;var sprite:Dictionary=state.sprite
 if not entries.has(e.id):state.done=true;record_cost(began);return
 var attempt:int=state.attempt;state.attempt+=1
 var radius:float=8.0*(1+attempt/8)
 var angle_offset:float=TAU*(attempt%8)/8.0
 var candidate:Vector2=origin+(e.right*cos(angle_offset)+e.forward*sin(angle_offset))*radius
 var distance:float=e.route.lane_distance(candidate) if e.route!=null else ForestRoute.road_distance(candidate,true)
 var local_s:float=sprite.route_s-e.route.start_s if e.route!=null else sprite.route_s
 if distance>=maxf(26,ForestEcology.half_width(local_s))+e.radius+8:
  e.center=candidate+e.forward*7.5
  var candidate_contacts:Dictionary=contacts(e) if partial_resolution else {}
  var clear:bool=candidate_contacts.is_empty() if partial_resolution else not conflicts(e,false)
  if clear:
   state.result=sprite.duplicate();state.result.position=candidate;state.result.native_original_position=origin
   moved+=1;finish_place(state)
  elif partial_resolution:
   var safe:=true;var score:=0.0
   for id in candidate_contacts:
    if not state.original_contacts.has(id) or candidate_contacts[id]>state.original_contacts[id]+0.00001:
     safe=false;break
    score+=float(candidate_contacts[id])
   if safe and score<state.best_score-0.001:
    state.best_score=score;state.best_position=candidate
 if not state.done and state.attempt>=24:
  var chosen:Vector2=state.get("best_position",origin)
  e.center=chosen+e.forward*7.5
  if chosen!=origin:
   state.result=sprite.duplicate();state.result.position=chosen;state.result.native_original_position=origin;moved+=1
  unresolved+=1;finish_place(state)
 record_cost(began)
func finish_place(state:Dictionary):
 var e:Dictionary=state.e
 for cell in cells(e):
  if not buckets.has(cell):buckets[cell]=[]
  buckets[cell].append(e)
 state.done=true
func record_cost(began:int):
 var elapsed:=Time.get_ticks_usec()-began
 solve_total_usec+=elapsed;solve_peak_usec=maxi(solve_peak_usec,elapsed)
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
