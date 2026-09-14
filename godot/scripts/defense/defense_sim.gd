extends RefCounted
var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/defense_sample.json"))
var enemies:Array=[]
var allies:Array=[]
var shots:Array=[]
var effects:Array=[]
var life:=20
var spawned:=0
var killed:=0
var leaked:=0
var clock:=0.0
var next_spawn:=0.0
var status:="prepare"
var stress:=false
var slow_until:=0.0
var spell_ready:=0.0
var peak:=0
var entry_clocks:Dictionary={}
var rng:=RandomNumberGenerator.new()
func reset(load_test:=false):
 rng.seed=86731;entry_clocks.clear()
 enemies.clear();allies.clear();shots.clear();effects.clear()
 life=int(config.life);spawned=0;killed=0;leaked=0;clock=0;next_spawn=0;peak=0
 status="prepare";stress=load_test;slow_until=0;spell_ready=0
 for i in 5:
  var front=i<3
  allies.append({"id":i,"pos":Vector3((i-1)*4 if front else (i-3)*5-2.5,0,2.5 if front else 5.8),"hp":550.0 if front else 260.0,"max_hp":550.0 if front else 260.0,"range":2.6 if front else 17.0,"attack":28.0 if front else 24.0,"cooldown":1.1 if front else .8,"next":0.0,"state":"idle","changed":0.0,"type":i,"boss":false})
func begin():
 if status!="prepare":return
 status="battle"
 if stress:
  for i in 50:spawn_enemy(true)
func spawn_enemy(spread:=false):
 var kind=int(config.spawn_cycle[spawned%config.spawn_cycle.size()])
 var spec:Dictionary=config.enemies[kind]
 var entry="fall" if spawned%11==4 else "forest" if spawned%4==1 else "crawl" if float(spawned%10) in config.crawl_slots else "road"
 if float(spec.get("body_scale",1.0))>1.0:entry="road"
 var boss=not stress and spawned==int(config.total)-1
 var p=Vector3(rng.randf_range(-4.5,4.5),0,float(config.spawn_z)+rng.randf_range(-12,8) if spread else float(config.spawn_z)+rng.randf_range(-2.5,2.5))
 for attempt in 12:
  if not enemies.any(func(e):return e.pos.distance_to(p)<.8):break
  p.x=rng.randf_range(-4.5,4.5);p.z-=.7
 var road_x=p.x
 if entry=="forest":
  p.x=(-1 if rng.randf()<.5 else 1)*rng.randf_range(6.5,8)
  p.z=rng.randf_range(-17,-5)
  road_x=signf(p.x)*rng.randf_range(2.2,4.0)
 if entry=="fall":p.y=8;p.z=maxf(p.z,-19)
 var reveal_at:=clock
 if entry in ["forest","fall"]:
  reveal_at=maxf(clock,float(entry_clocks.get(entry,clock)))+rng.randf_range(.4,1.2)
  entry_clocks[entry]=reveal_at+rng.randf_range(1.1,2.6)
 enemies.append({"body_scale":float(spec.get("body_scale",1.0))*(1.5 if boss else 1.0),"activate_at":reveal_at,"heading":0.0,"entry":entry,"road_x":road_x,"entry_phase":entry if entry=="fall" else "advance","phase_started":reveal_at,"id":spawned,"type":kind,"pos":p,"previous_pos":p,"spawn_x":p.x,"spawn_z":p.z,"actual_speed":0.0,"travelled":0.0,"running":false,"health_revealed":false,"speed_factor":rng.randf_range(.78,1.38),"drift":rng.randf_range(-.6,.6),"phase":rng.randf_range(0,TAU),"born":reveal_at,"hp":1200.0 if boss else float(spec.hp),"max_hp":1200.0 if boss else float(spec.hp),"state":"walk","changed":clock,"next":clock+.5,"boss":boss,"resolved":false})
 spawned+=1
 peak=maxi(peak,active_count())
func active_count()->int:
 var count:=0
 for e in enemies:
  if e.hp>0 and not e.resolved:count+=1
 return count
func pulse()->bool:
 if status!="battle" or clock<spell_ready:return false
 slow_until=clock+4;spell_ready=clock+16
 return true
func hurt(unit:Dictionary,damage:float):
 if unit.hp<=0 or unit.get("resolved",false) or clock<float(unit.get("activate_at",0)):return
 var before:float=unit.hp
 unit.hp=maxf(0,unit.hp-maxf(0,damage))
 if unit.hp<before:unit.health_revealed=true
 if unit.hp<=0:
  unit.state="death";unit.changed=clock
  if unit.has("resolved"):killed+=1;unit.resolved=true
func fire(source:Dictionary,target:Dictionary,enemy:bool):
 source.state="attack";source.changed=clock
 var ranged=source.type>=3 if not enemy else config.enemies[source.type].behavior=="ranged"
 var damage=float(config.enemies[source.type].attack) if enemy else source.attack
 if enemy and source.boss:damage*=1.6
 var origin:Vector3=source.pos+Vector3.UP
 var destination:Vector3=target.pos+Vector3.UP
 shots.append({"target":target,"damage":damage,"due":clock+(origin.distance_to(destination)/14 if ranged else .25)})
 effects.append({"from":origin,"to":destination,"ranged":ranged,"enemy":enemy,"duration":origin.distance_to(destination)/14 if ranged else .25})
func step(dt:float):
 effects.clear()
 if status!="battle":return
 clock+=dt
 for e in enemies:e.previous_pos=e.pos;e.actual_speed=0.0
 if not stress and spawned<int(config.total) and clock>=next_spawn and active_count()<int(config.cap):
  spawn_enemy();next_spawn=clock+float(config.interval)*rng.randf_range(.25,.60) if spawned%9<6 else clock+rng.randf_range(.8,1.7)
 for i in range(shots.size()-1,-1,-1):
  if shots[i].due<=clock:
   hurt(shots[i].target,shots[i].damage);shots.remove_at(i)
 for a in allies:
  if a.hp<=0:continue
  if a.state=="attack" and clock-a.changed>.7:a.state="idle";a.changed=clock
  if clock<a.next:continue
  var target:Dictionary={};var priority:=-INF
  for e in enemies:
   if e.hp<=0 or e.resolved or clock<e.activate_at:continue
   if a.pos.distance_to(e.pos)<=a.range and e.pos.z>priority:target=e;priority=e.pos.z
  if not target.is_empty():fire(a,target,false);a.next=clock+a.cooldown
 var moving:=enemies.duplicate()
 moving.sort_custom(func(a,b):return a.pos.z>b.pos.z)
 for e in moving:
  if e.resolved or clock<e.activate_at:continue
  var spec:Dictionary=config.enemies[e.type]
  if e.entry_phase in ["fall","landing","rise"]:
   var age:float=clock-e.phase_started
   if e.entry_phase=="fall":
    e.pos.y=maxf(0,8-8*pow(age/.9,2))
    if age>=.9:e.pos.y=0;e.entry_phase="landing";e.phase_started=clock
   elif e.entry_phase=="landing" and age>=.48:e.entry_phase="rise";e.phase_started=clock
   elif e.entry_phase=="rise" and age>=1.85:e.entry_phase="advance";e.phase_started=clock
   continue
  var target:Dictionary={};var best:float=spec.range
  if spec.behavior!="runner":
   for a in allies:
    if a.hp<=0 or a.get("leader",false):continue
    var d:float=e.pos.distance_to(a.pos)
    if d<best:best=d;target=a
  if not target.is_empty():
   if clock>=e.next:fire(e,target,true);e.next=clock+float(spec.cooldown)
   elif e.state=="walk":e.state="idle";e.changed=clock
  else:
   if e.state!="walk":e.state="walk";e.changed=clock
   var pace:float=float(spec.speed)*e.speed_factor*(float(config.crawl_speed_multiplier) if e.entry=="crawl" else 1.0)
   var path_progress:=smoothstep(float(e.spawn_z),float(config.line_z),float(e.pos.z))
   var outer:=smoothstep(1.4,3.6,absf(e.spawn_x))
   var target_x:float=e.road_x*(1.0-.22*outer*minf(path_progress/.55,1.0))
   if e.entry=="forest":target_x=lerpf(e.spawn_x,e.road_x,smoothstep(0,8.0,float(e.pos.z-e.spawn_z)))
   var lateral:=clampf((target_x-e.pos.x)*1.2,-.8,.8)
   var steering:=Vector3(lateral+sin(clock*.8+e.phase)*.08,0,1.0)
   for other in moving:
    if other.id==e.id or other.resolved or clock<other.activate_at:continue
    var gap:Vector3=e.pos-other.pos;gap.y=0
    var separation:float=gap.length()
    if separation>.001 and separation<(float(e.body_scale)+float(other.body_scale))*.5:
     steering+=gap/separation*(1-separation/((float(e.body_scale)+float(other.body_scale))*.5))*2.2
   steering.z=maxf(.3,steering.z)
   e.pos+=steering.normalized()*pace*dt*(.4 if clock<slow_until else 1.0)
   e.pos.x=clampf(e.pos.x,-9.0 if e.entry=="forest" else -5.2,9.0 if e.entry=="forest" else 5.2)
   var movement:Vector3=e.pos-e.previous_pos
   e.heading=lerp_angle(float(e.heading),atan2(movement.x,maxf(.001,movement.z)),1-exp(-6*dt))
   e.travelled+=movement.length()
   e.actual_speed=movement.length()/maxf(.001,dt)
   if e.actual_speed/e.body_scale>2.05:e.running=true
   elif e.actual_speed/e.body_scale<1.85:e.running=false
   if e.pos.z>=float(config.line_z):
    e.resolved=true;e.state="leaked";e.changed=clock
    life=maxi(0,life-1);leaked+=1
    if life==0:break
 if life<=0:status="defeat"
 elif spawned>=(50 if stress else int(config.total)) and active_count()==0:status="victory"
