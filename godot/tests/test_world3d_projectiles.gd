extends SceneTree
const PROJECTILES=preload("res://scripts/world3d/projectiles.gd")
const COMBAT=preload("res://scripts/world3d/combat_sim.gd")
func unit(id:int,p:Vector3)->Dictionary:
 return {"query_id":id,"query_enemy":true,"pos":p,"previous_pos":p,"hp":100.0}
func _initialize():call_deferred("run")
func damage(target:Dictionary,amount:float):target.hp-=amount
func run():
 var system=PROJECTILES.new()
 var near:=unit(8,Vector3(0,0,3));var far:=unit(2,Vector3(0,0,7))
 system.launch(Vector3.UP,Vector3.BACK,200,10,false)
 system.step(.05,[far,near],damage)
 assert(near.hp==90 and far.hp==100,"Fast bullet must hit the first spatial target, not the first ID")
 system.clear();near.hp=100
 system.launch(Vector3.UP,Vector3.BACK,200,10,false,5)
 system.step(.02,[far,near],damage);system.step(.02,[far,near],damage)
 assert(near.hp==90 and far.hp==90,"Pierce hits each target once across ticks")
 system.clear();var crossing:=unit(3,Vector3(5,0,5));crossing.previous_pos=Vector3(-5,0,5)
 system.launch(Vector3.UP,Vector3.BACK,200,10,false);system.step(.05,[crossing],damage)
 assert(crossing.hp==90,"Swept relative motion must catch a target crossing between ticks")
 system.clear();var aerial:=unit(4,Vector3(0,5,5))
 system.launch(Vector3.UP,Vector3.BACK,200,10,false);system.step(.05,[aerial],damage)
 assert(aerial.hp==100,"XZ broad phase must not hit a target above the projectile")
 system.clear();var giant:=unit(5,Vector3(0,0,5));giant.body_scale=2.0
 system.launch(Vector3(0,3,0),Vector3.BACK,200,10,false);system.step(.05,[giant],damage)
 assert(giant.hp==90,"A shot through the enlarged upper body must hit its scaled centre")
 system.clear();giant.hp=100
 system.launch(Vector3(0,-.5,0),Vector3.BACK,200,10,false);system.step(.05,[giant],damage)
 assert(giant.hp==100,"Scaling a body must not extend its collider below the ground")
 system.clear();var crawler:=unit(6,Vector3(0,0,5));crawler.entry="crawl";crawler.entry_phase="advance"
 system.launch(Vector3.UP,Vector3.BACK,200,10,false);system.step(.05,[crawler],damage)
 assert(crawler.hp==100,"A standing chest-height shot passes above a crawling body")
 system.clear()
 system.launch(Vector3(0,.35,0),Vector3.BACK,200,10,false);system.step(.05,[crawler],damage)
 assert(crawler.hp==90,"A low shot hits the crawling body")
 system.clear();crawler.entry_phase="rise"
 system.launch(Vector3.UP,Vector3.BACK,200,10,false);system.step(.05,[crawler],damage)
 assert(crawler.hp==80,"Non-prone entry phases restore the upright proxy")
 system.clear();near=unit(8,Vector3(0,0,3));far=unit(2,Vector3(0,0,7));near.hp=5
 system.launch(Vector3.UP,Vector3.BACK,200,10,false)
 system.launch(Vector3.UP,Vector3.BACK,200,10,false)
 system.step(.05,[near,far],damage)
 assert(near.hp==-5 and far.hp==90,"A later shot must pass a target killed earlier in the same step")
 var combat=COMBAT.new()
 combat.config={"enemies":[{"behavior":"ranged","attack":10}]}
 var source:Dictionary={"id":1,"type":0,"boss":false,"pos":Vector3.ZERO,"body_scale":2.0}
 giant.pos=Vector3(0,0,8)
 combat.fire(source,giant,true)
 var shot:Dictionary=combat.projectiles.active[0]
 assert(shot.origin==Vector3(0,2,0),"Fallback muzzle height scales with the source")
 assert(shot.velocity.normalized().is_equal_approx(Vector3.BACK),"Ranged attack aims at the same scaled centre used by collision")
 combat.emission_origin=func(_unit,_enemy):return Vector3(1,3,0)
 combat.fire(source,giant,true)
 shot=combat.projectiles.active[1]
 assert(shot.origin==Vector3(1,3,0),"A real weapon socket must retain its supplied position")
 assert(shot.velocity.normalized().is_equal_approx((Vector3(0,2,8)-shot.origin).normalized()))
 crawler.entry_phase="advance"
 combat.fire(source,crawler,true)
 shot=combat.projectiles.active[2]
 assert(shot.velocity.normalized().is_equal_approx((Vector3(0,.35,5)-shot.origin).normalized()),"Crawlers must be aimed at their low body centre")
 print("WORLD3D_PROJECTILES_PASS nearest time of impact, pierce deduplication, moving target sweep, height rejection")
 quit()
