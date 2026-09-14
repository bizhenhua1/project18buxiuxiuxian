extends SceneTree
const SIM=preload("res://scripts/defense/defense_sim.gd")
func _initialize():
 var sim=SIM.new();sim.reset();sim.begin();sim.spawn_enemy()
 sim.next_spawn=999
 sim.enemies[0].pos.z=8.49
 sim.step(.1)
 assert(sim.life==19 and sim.leaked==1)
 sim.step(.1);assert(sim.life==19)
 sim.reset();sim.begin();sim.spawned=4;sim.spawn_enemy();sim.next_spawn=999
 var caster=sim.enemies[0];caster.pos=Vector3(0,0,-3);caster.entry_phase="advance";caster.activate_at=0
 for a in sim.allies:a.next=999
 var before:Vector3=caster.pos
 for i in 60:sim.step(.05)
 assert(caster.pos==before,"Ranged unit stops at range")
 assert(sim.allies[1].hp<sim.allies[1].max_hp,"Ranged projectile deals real HP damage")
 for a in sim.allies:sim.hurt(a,99999)
 sim.step(.1);assert(caster.pos.z>before.z,"Resumes advance when defenders die")
 sim.reset(true);sim.begin();assert(sim.active_count()==50 and sim.peak==50)
 var kinds:Dictionary={};var widths:Dictionary={};var speeds:Array=[]
 for e in sim.enemies:
  kinds[e.type]=true;widths[snappedf(e.pos.x,.1)]=true;speeds.append(e.speed_factor)
 assert(kinds.size()==5 and widths.size()>15,"Mixed crowd must not form five columns")
 speeds.sort();assert(speeds[-1]-speeds[0]>.4,"Individual pace variation")
 var snapshot=sim.enemies.duplicate(true)
 var crawlers=sim.enemies.filter(func(e):return e.entry=="crawl")
 var giants=sim.enemies.filter(func(e):return e.type==3)
 print("CROWD_MIX ",crawlers.size()," crawlers / ",giants.size()," giants")
 assert(crawlers.size()>=18 and giants.size()==3)
 for giant in giants:assert(giant.body_scale==1.8 and giant.entry=="road")
 assert(float(sim.config.crawl_speed_multiplier)>1.0)
 sim.reset(true);sim.begin();assert(snapshot==sim.enemies,"Reproducible crowd seed")
 for a in sim.allies:sim.hurt(a,99999)
 for i in 3000:
  sim.step(.05)
  if sim.status!="battle":break
 assert(sim.status=="defeat" and sim.life==0 and sim.leaked==20)
 sim.reset(true);sim.begin()
 for e in sim.enemies:e.activate_at=0;sim.hurt(e,99999)
 sim.step(.05);assert(sim.status=="victory" and sim.killed==50)
 sim.reset();sim.begin();sim.next_spawn=999;sim.spawn_enemy()
 var gait=sim.enemies[0]
 assert(not gait.health_revealed)
 sim.hurt(gait,0);assert(not gait.health_revealed)
 sim.hurt(gait,1);assert(gait.health_revealed and gait.hp==gait.max_hp-1)
 gait.type=1;gait.speed_factor=1.2
 sim.step(.05)
 assert(gait.running and gait.actual_speed>2.05)
 assert(sim.pulse())
 sim.step(.05)
 assert(not gait.running and gait.actual_speed<1.85,"Slow effect returns running enemy to walking")
 var presentation=load("res://scripts/defense/defense_route.gd")
 assert(presentation.motion_bucket(gait).begins_with("walk"))
 gait.actual_speed=3.2;gait.running=true
 assert(presentation.motion_bucket(gait)=="run_fast")
 for x in [-4.5,0.0,4.5]:
  sim.reset();sim.begin();sim.allies.clear();sim.next_spawn=999;sim.spawn_enemy()
  var mover=sim.enemies[0];mover.pos.x=x;mover.spawn_x=x;mover.road_x=x
  for frame in 1400:
   sim.step(.05)
   if mover.resolved:break
  assert(mover.resolved)
  if x==0:assert(absf(mover.pos.x)<.5,"Central approach stays central")
  else:assert(absf(mover.pos.x)>3.0 and absf(mover.pos.x)<4.2,"Outer approach curves inward without collapsing into center")
 sim.reset();sim.begin();sim.next_spawn=999;sim.spawned=4;sim.spawn_enemy();sim.allies.clear()
 var falling=sim.enemies[0]
 falling.activate_at=0;falling.phase_started=0
 assert(falling.entry_phase=="fall" and falling.pos.y==8)
 var landing_point=falling.pos
 for i in 19:sim.step(.05)
 assert(falling.pos.y==0 and falling.pos.z==landing_point.z)
 for i in 50:sim.step(.05)
 assert(falling.entry_phase=="advance" and falling.pos.z>landing_point.z)
 sim.reset(true);sim.begin()
 var arrival_times:Dictionary={}
 var sides:Dictionary={}
 for e in sim.enemies:
  if e.entry in ["forest","fall"]:
   assert(e.activate_at>0)
   var key=e.entry
   if arrival_times.has(key):assert(e.activate_at-arrival_times[key]>1.0)
   arrival_times[key]=e.activate_at
  if e.entry=="forest":sides[signf(e.pos.x)]=true;assert(e.pos.z>=-17 and e.pos.z<=-5)
 assert(sides.size()==2,"Both woodland edges are used")
 print("DEFENSE_PASS ranged attack, advance, leakage once, real ally HP, 50 cap, defeat and victory")
 quit()
