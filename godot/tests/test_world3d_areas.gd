extends SceneTree
const AREAS=preload("res://scripts/world3d/areas.gd")
func _initialize():call_deferred("run")
func hurt(unit:Dictionary,damage:float):unit.hp=maxf(0,unit.hp-damage)
func unit(id:int,p:Vector3)->Dictionary:return {"id":id,"pos":p,"hp":100.0,"activate_at":0.0}
func run():
 var areas=AREAS.new();var identity:Callable=func(p):return p
 var inside:=unit(1,Vector3.ZERO);var outside:=unit(2,Vector3(5,0,0));var airborne:=unit(3,Vector3(0,3,0));var pending:=unit(4,Vector3.ZERO);pending.activate_at=10
 areas.sync([inside,outside,airborne,pending],identity,0)
 assert(areas.burst(Vector3.ZERO,1,.5,10,hurt)==1)
 assert(inside.hp==90 and airborne.hp==100 and pending.hp==100)
 assert(areas.add_zone(Vector3.ZERO,1,.5,10,1,.25)>0)
 areas.advance(.24,hurt);assert(inside.hp==90)
 areas.advance(.01,hurt);assert(inside.hp==80)
 inside.pos=Vector3(5,0,0);outside.pos=Vector3.ZERO
 areas.sync([inside,outside,airborne,pending],identity,.25)
 areas.advance(.75,hurt)
 assert(inside.hp==80 and outside.hp==70 and areas.zones.is_empty(),"Entry/exit and exact lifetime tick count")
 var rotation:=Basis(Vector3.UP,.73);var origin:=Vector3(40,0,-65)
 var transform:Callable=func(p):return rotation*p+origin
 areas.sync([inside,outside],transform,1)
 assert(areas.corridor(origin,transform.call(Vector3(6,0,0)),.2,.5,15,hurt)==2,"Rotated battlefield uses world-space shape")
 var crowd:Array=[]
 for i in 1000:crowd.append(unit(i,Vector3((i%40)*3,0,(i/40)*3)))
 areas.sync(crowd,identity,1)
 var expected:=0
 for candidate in crowd:
  if Vector2(candidate.pos.x,candidate.pos.z).length()<=3.3:expected+=1
 assert(areas.burst(Vector3.ZERO,3,1,10,hurt)==expected)
 assert(areas.index.visited<50,"Small area should inspect local candidates only")
 areas.add_zone(Vector3.ZERO,3,1,100,1,.25);areas.advance(1,hurt)
 assert(crowd[0].hp==0,"Dead targets stop receiving subsequent periodic hits")
 areas.clear();assert(areas.zones.is_empty() and areas.targets.is_empty())
 var sloped:Array=[{"id":101,"hp":100.0,"pos":Vector3(1,1,0)}, {"id":102,"hp":100.0,"pos":Vector3(1,5,0)}]
 areas.sync(sloped,func(p):return p,0)
 var slope_hits:Array=[]
 areas.corridor(Vector3.ZERO,Vector3(10,10,0),.2,.2,1,func(unit,amount):slope_hits.append(unit.id))
 assert(slope_hits==[101],"Sloped corridor must use the local path height, not the midpoint height")
 slope_hits.clear()
 areas.corridor(Vector3(10,10,0),Vector3.ZERO,.2,.2,1,func(unit,amount):slope_hits.append(unit.id))
 assert(slope_hits==[101],"Reversing a corridor must preserve its volume")
 areas.sync([unit(201,Vector3(0,2,0)),unit(202,Vector3(0,6,0))],identity,0)
 slope_hits.clear()
 areas.corridor(Vector3.ZERO,Vector3(0,4,0),.2,.2,1,func(unit,amount):slope_hits.append(unit.id))
 assert(slope_hits==[201],"Vertical corridor must cover its full height interval")
 var standing:=unit(301,Vector3.ZERO)
 var crawler:=unit(302,Vector3.ZERO);crawler.entry="crawl";crawler.entry_phase="advance"
 var giant:=unit(303,Vector3.ZERO);giant.body_scale=2.0
 areas.sync([standing,crawler,giant],identity,0)
 assert(areas.burst(Vector3(0,1.4,0),.5,.1,10,hurt)==2,"A chest-height blast reaches standing and large bodies, not a crawler")
 assert(standing.hp==90 and giant.hp==90 and crawler.hp==100)
 assert(areas.corridor(Vector3(-2,2.8,0),Vector3(2,2.8,0),.2,.1,10,hurt)==1,"An elevated piercing volume reaches the giant's upper body")
 assert(giant.hp==80)
 assert(areas.burst(Vector3.ZERO,.5,.05,10,hurt)==3,"Ground-level areas include the feet of every grounded posture")
 assert(areas.burst(Vector3(0,-.5,0),.5,.1,10,hurt)==0,"Areas wholly below the floor do not reach grounded units")
 areas.sync([unit(401,Vector3.ZERO)],identity,0)
 assert(areas.corridor(Vector3(0,1.2,0),Vector3(0,4,0),.2,.05,10,hurt)==1,"A vertical ray can intersect the torso even when its start is above the feet")
 print("WORLD3D_AREAS_PASS height, activation, entry/exit, periodic lifetime, rotated world, 1000-unit spatial pruning, clear")
 quit()
