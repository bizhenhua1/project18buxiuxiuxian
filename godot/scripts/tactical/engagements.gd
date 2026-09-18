extends RefCounted
# A reservation consumes capacity before contact, preventing crowd-wide pulls.
static func can_block(sim,a:Dictionary)->bool:
 return sim.alive(a) and a.order!="move" and a.state!="rising"
static func column(sim,x:float)->int:
 var best:=INF;var result:=0
 for i in sim.columns.size():
  var distance:float=absf(sim.columns[i]-x)
  if distance<best:best=distance;result=i
 return result
static func update(sim,live:Array):
 for a in sim.allies:a.blocked.clear();a.taunting=[]
 for e in live:
  var owner:int=e.get("blocked_by",-1)
  if owner>=0:
   var a:Dictionary=sim.allies[owner]
   if e.get("push_left",0)<=0 and can_block(sim,a) and e.pos.distance_to(a.pos)<=3 and a.blocked.size()<a.block:a.blocked.append(e.id)
   else:e.blocked_by=-1
 # Contact has priority over requests from neighbouring columns.
 for e in live:
  if e.get("blocked_by",-1)>=0 or e.entry_phase!="advance" or e.get("push_left",0)>0:continue
  var nearest:=1.7;var owner:=-1
  for a in sim.allies:
   var distance:float=e.pos.distance_to(a.pos)
   if can_block(sim,a) and a.blocked.size()<a.block and distance<nearest:owner=a.id;nearest=distance
  if owner>=0:e.blocked_by=owner;sim.allies[owner].blocked.append(e.id)
 # Preserve existing requests, so equally close tanks cannot tug enemies back
 # and forth. Death, swapping, loss of range, and capacity shrink release them.
 for e in live:
  var owner:int=e.get("taunted_by",-1);e.taunted_by=-1
  if owner<0 or e.get("blocked_by",-1)>=0 or e.entry_phase!="advance" or e.get("push_left",0)>0:continue
  var a:Dictionary=sim.allies[owner]
  if can_block(sim,a) and a.taunt and a.blocked.size()+a.taunting.size()<a.block and e.pos.distance_to(a.pos)<=sim.settings.taunt_radius*1.2:
   e.taunted_by=owner;a.taunting.append(e.id)
 var requests:Array=[]
 for a in sim.allies:
  if not can_block(sim,a) or not a.taunt or a.blocked.size()+a.taunting.size()>=a.block:continue
  for id in sim.grid.circle(a.pos,sim.settings.taunt_radius):
   var e:Dictionary=sim.enemies[id]
   if e.get("blocked_by",-1)>=0 or e.get("taunted_by",-1)>=0 or e.entry_phase!="advance" or e.get("push_left",0)>0:continue
   if abs(column(sim,e.pos.x)-column(sim,a.pos.x))!=1 or e.pos.z>a.pos.z+.5:continue
   var distance:float=e.pos.distance_squared_to(a.pos)
   if distance<=sim.settings.taunt_radius*sim.settings.taunt_radius:requests.append({"ally":a.id,"enemy":id,"distance":distance})
 requests.sort_custom(func(a,b):return a.distance<b.distance if not is_equal_approx(a.distance,b.distance) else (a.ally<b.ally if a.ally!=b.ally else a.enemy<b.enemy))
 for request in requests:
  var a:Dictionary=sim.allies[request.ally];var e:Dictionary=sim.enemies[request.enemy]
  if e.get("taunted_by",-1)>=0 or a.blocked.size()+a.taunting.size()>=a.block:continue
  e.taunted_by=a.id;a.taunting.append(e.id)
