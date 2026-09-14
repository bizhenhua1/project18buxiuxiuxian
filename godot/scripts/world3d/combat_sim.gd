extends "res://scripts/defense/defense_sim.gd"
const BODY=preload("res://scripts/world3d/combat_body.gd")
# Simulation units are 0.4 world metres. Attack movement participates in targeting.
var impact_events:Array=[]
var windups:Array=[]
var projectiles=preload("res://scripts/world3d/projectiles.gd").new()
var areas=preload("res://scripts/world3d/areas.gd").new()
var skill_world:Callable=func(p:Vector3)->Vector3:return Vector3(p.x*.4,p.y,p.z*.4)
var emission_origin:Callable
func seed_encounter(world_seed:int,route_index:int,branch:int,station:float,event_index:int):
 # Independent from visual randomness; retrying the same encounter reproduces
 # arrivals, while another route/event gets its own deterministic sequence.
 rng.seed=("%d:%d:%d:%d:%d"%[world_seed,route_index,branch,roundi(station*1000),event_index]).hash()
func attack_origin(source:Dictionary,enemy:bool)->Vector3:
 return emission_origin.call(source,enemy) if emission_origin.is_valid() else BODY.center(source)
func reset(load_test:=false):
 super(load_test);windups.clear();projectiles.clear();impact_events.clear();areas.clear()
func fire(source:Dictionary,target:Dictionary,enemy:bool):
 if enemy:
  if config.enemies[source.type].behavior!="ranged":super(source,target,true);return
  source.state="attack";source.changed=clock
  var origin:=attack_origin(source,true)
  projectiles.launch(origin,BODY.center(target)-origin,14,float(config.enemies[source.type].attack)*(1.6 if source.boss else 1.0),true,1,source.id)
  return
 source.state="attack";source.changed=clock
 var duration:float=maxf(.3,float(source.cooldown)*.9)
 source.attack_duration=duration
 source.attack_target=target
 source.attack_origin=source.pos
 var delta:Vector3=target.pos-source.pos;delta.y=0
 var forward:=Vector3(delta.x,0,minf(-.01,delta.z)).normalized()
 # Never chase through the crowd: stop short of the target and cap excursion at 1.2 m.
 var reach:float=minf(3.0,maxf(0,delta.length()-.9)) if source.get("melee",false) else 0.0
 source.attack_tip=source.pos+forward*reach
 source.attack_hit=duration*.42
 windups.append({"source":source,"target":target,"stamp":clock,"due":clock+source.attack_hit,"damage":source.attack})
func step(dt:float):
 if status!="battle":return
 for unit in allies:
  unit.previous_pos=unit.pos
  if unit.hp>0 and unit.state=="death":
   unit.return_target=unit.get("return_target",unit.get("attack_origin",unit.pos))
   for key in ["attack_origin","attack_tip","attack_target","attack_duration","attack_hit"]:unit.erase(key)
   for i in range(windups.size()-1,-1,-1):
    if windups[i].source==unit:windups.remove_at(i)
   unit.state="rising" if float(unit.get("revive_duration",0))>0 else "returning";unit.changed=clock
  if unit.hp>0 and unit.state=="rising":
   unit.next=maxf(float(unit.next),clock+dt+.05)
   if clock-float(unit.changed)>=float(unit.revive_duration):unit.state="returning";unit.changed=clock
   continue
  if unit.hp>0 and unit.state=="returning":
   # Fixed 1.2 m/s recovery, never a distance-dependent teleport or dash.
   unit.pos=unit.pos.move_toward(unit.return_target,3.0*dt)
   unit.next=maxf(float(unit.next),clock+dt+.05)
   if unit.pos.distance_squared_to(unit.return_target)<.000001:
    unit.pos=unit.return_target;unit.erase("return_target");unit.state="idle";unit.changed=clock
   continue
  if unit.hp<=0 or not unit.has("attack_origin"):continue
  var t:float=clampf((clock+dt-float(unit.changed))/float(unit.attack_duration),0,1)
  var weight:=smoothstep(0,.42,t) if t<.42 else 1-smoothstep(.55,1,t)
  unit.pos=unit.attack_origin.lerp(unit.attack_tip,weight)
  # Preserve the attack stamp while base simulation evaluates cooldown and targets.
  if t>=1:unit.erase("attack_origin")
 for i in range(windups.size()-1,-1,-1):
  var hit:Dictionary=windups[i]
  if hit.source.hp<=0:windups.remove_at(i);continue
  if hit.due>clock+dt:continue
  if hit.target.hp>0 and not hit.target.get("resolved",false):
   if hit.source.get("melee",false):
    if hit.source.pos.distance_to(hit.target.pos)<=float(hit.source.range):hurt(hit.target,hit.damage)
   else:
    var origin:=attack_origin(hit.source,false)
    projectiles.launch(origin,BODY.center(hit.target)-origin,14,hit.damage,false,1,hit.source.id)
  windups.remove_at(i)
 # Base state clears attack after 0.7 s: long actions retain their stamp until return completes.
 var stamps:Dictionary={}
 for unit in allies:
  if unit.hp>0 and unit.has("attack_origin"):stamps[unit.id]=unit.changed
 super(dt)
 for unit in allies:
  if unit.hp>0 and stamps.has(unit.id) and unit.state=="idle":unit.state="attack";unit.changed=stamps[unit.id]

 var targets:Array=[]
 for unit in enemies:
  if clock<unit.activate_at:continue
  unit.query_id=int(unit.id)*2;unit.query_enemy=true;targets.append(unit)
 for unit in allies:
  if unit.get("leader",false):continue
  unit.query_id=int(unit.id)*2+1;unit.query_enemy=false;targets.append(unit)
 projectiles.step(dt,targets,Callable(self,"hurt"))
 impact_events.append_array(projectiles.events)
 if status=="battle":
  if areas.needs_targets(dt):areas.sync(enemies,skill_world,clock)
  areas.advance(dt,Callable(self,"hurt"))
 else:areas.clear()
