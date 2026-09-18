extends "res://scripts/world3d/combat_sim.gd"
const RULES=preload("res://scripts/tactical/range.gd")
var settings:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/tactical_mode.json"))
var grid=preload("res://scripts/world3d/spatial_index.gd").new()
var slots:Array[Vector3]=[]
var flashes:Array=[]
var columns:Array[float]=[]
var roles=preload("res://scripts/tactical/roles.gd").new(self)
func _init():
 projectiles=preload("res://scripts/tactical/projectiles.gd").new();projectiles.hit_handler=roles.projectile_hit;projectiles.ground_handler=roles.ground_hit
func reset(load_test:=false):
 super(load_test);roles.reset()
func energy_limit(a:Dictionary)->float:return float(settings.skills[a.skill].get("cost",settings.energy_max))
func gain(a:Dictionary,kind:String)->float:return float(settings.skills[a.skill].get("gain",settings[kind+"_energy"]))
func configure_tactics(ids:Array):
 slots.clear()
 for a in allies:
  slots.append(a.pos)
  a.leader=false;a.tactical_active=a.id in ids;a.home=a.pos;a.initial=a.pos;a.slot=a.id
  a.taunt=false;a.taunting=[];a.aim_id=-1;a.projectile_mode="homing"
  a.energy=0.0;a.skill=0 if a.id==ids[0] else 2;a.block=2 if a.id==ids[0] else 1;a.blocked=[]
  a.order="hold";a.death_phase="";a.profession="剑士" if a.id==ids[0] else "术士"
  a.melee=a.id==ids[0];a.range=3.2 if a.melee else 20.0
  a.max_hp=maxf(300.0,a.max_hp);a.hp=a.max_hp;a.attack=maxf(35.0,a.attack)
 while slots.size()<8:slots.append(Vector3(lerpf(-6,6,float(slots.size())/7),0,5))
 columns.clear()
 for slot in slots:
  if not columns.any(func(x):return absf(x-slot.x)<.05):columns.append(slot.x)
 columns.sort()
func alive(a:Dictionary)->bool:return a.get("tactical_active",false) and a.hp>0 and a.get("death_phase","")==""
func add_energy(a:Dictionary,kind:String):
 if alive(a) and settings.skills[a.skill].recharge==kind:a.energy=minf(energy_limit(a),a.energy+gain(a,kind))
func hurt(unit:Dictionary,damage:float):
 var before:float=unit.hp
 if unit.get("tactical_active",false):
  damage*=1.0-float(unit.get("reduce",0))
  var shield:float=minf(float(unit.get("shield",0)),damage);damage-=shield;unit.shield=float(unit.get("shield",0))-shield
 super(unit,damage)
 if unit.get("tactical_active",false) and before>unit.hp:
  add_energy(unit,"hurt")
  if unit.hp<=0:
   unit.shield=0;unit.reduce=0;unit.block=unit.get("base_block",unit.block);unit.erase("fortify_until");unit.erase("guard_until");unit.death_phase="fallen";unit.death_at=clock;unit.death_pos=unit.pos;unit.order="hold";release(unit.id)
   unit.erase("attack_origin");unit.erase("attack_tip")
   for i in range(shots.size()-1,-1,-1):
    if shots[i].get("source",-1)==unit.id:shots.remove_at(i)
func release(id:int):
 for e in enemies:
  if e.get("blocked_by",-1)==id:e.blocked_by=-1
  if e.get("taunted_by",-1)==id:e.taunted_by=-1
 if id>=0 and id<allies.size():allies[id].blocked.clear();allies[id].taunting.clear()
func limit_forward(point:Vector3,origin:Vector3)->Vector3:
 point.z=maxf(point.z,minf(origin.z,float(settings.advance_limit_z)));return point
func move_to(a:Dictionary,destination:Vector3,order:String):
 if order=="advance":destination=limit_forward(destination,a.pos)
 release(a.id);roles.cancel_source(a.id);a.charge_ready=order=="advance";a.aim_id=-1;a.order=order;a.destination=destination;a.state="returning";a.changed=clock
 for key in ["attack_origin","attack_tip"]:a.erase(key)
 for i in range(shots.size()-1,-1,-1):
  if shots[i].get("source",-1)==a.id:shots.remove_at(i)
func swap(id:int,slot:int)->bool:
 if id<0 or id>=allies.size() or slot<0 or slot>=slots.size():return false
 var a:Dictionary=allies[id]
 if not alive(a) or a.slot==slot:return false
 var other:Dictionary={}
 for unit in allies:
  if unit.get("tactical_active",false) and unit.slot==slot:other=unit;break
 if not other.is_empty() and not alive(other):return false
 var old:int=a.slot
 if not other.is_empty():other.slot=old;other.home=slots[old];move_to(other,other.home,"move")
 a.slot=slot;a.home=slots[slot];move_to(a,a.home,"move");return true
func command(id:int,order:String)->bool:
 if id<0 or id>=allies.size() or not alive(allies[id]):return false
 var a:Dictionary=allies[id]
 if order=="retreat":move_to(a,a.home,"move")
 elif order=="advance":
  if a.profession=="守卫":a.guard_until=clock+8;a.guard_base=a.get("base_block",a.get("guard_base",a.block));a.block=maxi(a.block,a.guard_base+1)
  else:
   if a.pos.z<=float(settings.advance_limit_z)+.01:return false
   move_to(a,a.pos+Vector3(0,0,-6 if a.profession=="术士" else -40 if a.profession=="先锋" else -30),"advance")
 else:return false
 return true
func cast(id:int)->bool:
 if id<0 or id>=allies.size():return false
 var a:Dictionary=allies[id]
 if not alive(a) or a.energy<energy_limit(a):return false
 var spec:Dictionary=settings.skills[a.skill];a.energy=0.0
 if spec.has("effect"):
  roles.cast(a,spec);return true
 a.aim_id=-1;a.aim_point=a.pos+Vector3(0,0,-20);a.aim_until=clock+.65
 flashes.append({"origin":a.pos,"spec":spec,"until":clock+.65})
 for e in enemies:
  if not e.resolved and clock>=e.activate_at and RULES.contains(a.pos,e.pos,spec):hurt(e,float(spec.damage))
 a.state="attack";a.changed=clock;a.attack_duration=.65;a.next=maxf(a.next,clock+.65)
 return true
func fire(source:Dictionary,target:Dictionary,enemy:bool):
 if not enemy and source.has("role"):
  roles.attack(source,target);return
 source.erase("aim_point");source.aim_id=target.id
 source.state="attack";source.changed=clock;source.attack_duration=.65
 var damage:float=float(config.enemies[source.type].attack) if enemy else float(source.attack)
 var ranged:bool=config.enemies[source.type].behavior=="ranged" if enemy else not source.melee
 if ranged:
  var origin:=attack_origin(source,enemy)
  var mode:String=config.enemies[source.type].get("projectile_mode","ballistic") if enemy else source.projectile_mode
  projectiles.launch_at(origin,target,14,damage,enemy,source.id,mode)
 else:
  shots.append({"source":source.id if not enemy else -1,"target":target,"damage":damage,"attacker":source,"due":clock+.28})
  if not enemy:
   source.attack_origin=source.pos
   source.attack_tip=limit_forward(source.pos+(target.pos-source.pos).normalized()*minf(.7,maxf(0,source.pos.distance_to(target.pos)-.9)),source.pos)
 if not enemy:add_energy(source,"attack")
func step(dt:float):
 if status!="battle":return
 clock+=dt;effects.clear();impact_events.clear()
 for i in range(flashes.size()-1,-1,-1):
  if flashes[i].until<clock:flashes.remove_at(i)
 if spawned<int(config.total) and clock>=next_spawn and active_count()<int(config.cap):spawn_enemy();next_spawn=clock+rng.randf_range(.6,1.25)
 for i in range(shots.size()-1,-1,-1):
  if shots[i].due<=clock:
   var hit:Dictionary=shots[i];shots.remove_at(i)
   if hit.get("attacker",{}).get("hp",1)>0:roles.deal(hit.target,hit.damage,hit.get("attacker",{}))
 var live:Array=[]
 for e in enemies:
  e.previous_pos=e.pos;e.actual_speed=0.0
  if e.hp>0 and not e.resolved and clock>=e.activate_at:live.append(e)
 roles.step()
 live=live.filter(func(e):return e.hp>0 and not e.resolved)
 grid.rebuild(live)
 for a in allies:
  a.previous_pos=a.pos
  if a.has("guard_until") and clock>=a.guard_until:a.block=a.guard_base+(2 if a.get("fortify_until",0)>clock else 0);a.erase("guard_until")
  if not a.get("tactical_active",false):continue
  if a.hp<=0:
   var age:float=clock-a.death_at
   var hold:float=a.get("death_hold",settings.death_hold_seconds)
   if age>=hold+settings.return_seconds:
    a.death_phase="respawn";a.pos=a.home
    if age>=hold+settings.return_seconds+settings.respawn_seconds:
     a.hp=a.max_hp;a.animation_index=0;a.strikes=0;a.death_phase="";a.state="rising";a.changed=clock;a.next=clock+float(a.get("revive_duration",1.8))
   elif age>=hold:a.death_phase="light";a.pos=a.death_pos.lerp(a.home,(age-hold)/settings.return_seconds)
   continue
  if settings.skills[a.skill].recharge=="auto":a.energy=minf(energy_limit(a),a.energy+gain(a,"auto")*dt)
  a.blocked.clear()
  if a.has("attack_origin"):
   var t:float=clampf((clock-a.changed)/float(a.get("attack_duration",.65)),0,1)
   a.pos=a.attack_origin.lerp(a.attack_tip,smoothstep(0,.42,t) if t<.42 else 1-smoothstep(.5,1,t))
   if t>=1:a.erase("attack_origin");a.erase("attack_tip")
   else:continue
  if a.state=="rising":
   if clock<a.next:continue
   a.state="idle"
  if a.order in ["move","advance"]:
   var nearby:Array=grid.nearest(a.pos,2.4)
   if a.order=="move" or nearby.is_empty():
    a.pos=a.pos.move_toward(a.destination,(3.0 if a.profession=="剑士" else 2.2)*dt);a.state="returning"
    if a.pos.distance_to(a.destination)<.01:a.order="hold";a.state="idle"
    continue
   a.state="idle"
  if a.state=="attack" and clock-a.changed>float(a.get("attack_duration",.65)):a.state="idle"
  if clock<a.next:continue
  if a.has("role"):
   var target:Dictionary=roles.choose(a)
   if not target.is_empty():fire(a,target,false)
  else:
   var candidates:Array=grid.nearest(a.pos,a.range)
   if not candidates.is_empty():fire(a,enemies[candidates[0]],false);a.next=clock+a.cooldown
 preload("res://scripts/tactical/engagements.gd").update(self,live)
 for e in live:
  if e.resolved:continue
  if e.entry_phase in ["fall","landing","rise"]:
   var age:float=clock-e.phase_started
   if e.entry_phase=="fall":
    e.pos.y=maxf(0,8-8*pow(age/.9,2))
    if age>=.9:e.pos.y=0;e.entry_phase="landing";e.phase_started=clock
   elif e.entry_phase=="landing" and age>=.48:e.entry_phase="rise";e.phase_started=clock
   elif e.entry_phase=="rise" and age>=1.85:e.entry_phase="advance"
   continue
  if e.get("push_left",0)>0:
   var shift:float=minf(e.push_left,8*dt);e.pos.z-=shift;e.push_left-=shift;e.state="idle";e.aim_id=-1;continue
  var blocker:int=e.get("blocked_by",-1)
  e.blocked_by=blocker
  var target:Dictionary={};var spec:Dictionary=config.enemies[e.type]
  if blocker>=0:
   if not e.id in allies[blocker].blocked:allies[blocker].blocked.append(e.id)
   target=allies[blocker]
  elif e.get("taunted_by",-1)>=0:
   var lure:Dictionary=allies[e.taunted_by]
   if spec.behavior=="ranged" and e.pos.distance_to(lure.pos)<=float(spec.range):target=lure
  elif spec.behavior=="ranged":
   var best:float=spec.range
   for a in allies:
    if alive(a) and a.pos.distance_to(e.pos)<best:best=a.pos.distance_to(e.pos);target=a
  if not target.is_empty():
   e.aim_id=target.id
   if clock>=e.next:fire(e,target,true);e.next=clock+float(spec.cooldown)
   elif clock-e.changed>.65:e.state="idle"
   continue
  e.aim_id=-1
  var target_x:float=e.road_x
  var direction:=Vector3(clampf((target_x-e.pos.x)*.65,-.8,.8),0,1)
  var taunter:int=e.get("taunted_by",-1)
  if taunter>=0:direction=(allies[taunter].pos-e.pos).normalized();direction.y=0
  for id in grid.circle(e.pos,1.1):
   if id==e.id:continue
   var gap:Vector3=e.pos-enemies[id].pos;gap.y=0
   if gap.length_squared()>.001:direction+=gap.normalized()*maxf(0,1-gap.length())*.6
  if taunter<0:direction.z=maxf(.3,direction.z)
  var pace:float=spec.speed*e.speed_factor*(float(config.crawl_speed_multiplier) if e.entry=="crawl" else 1)
  if e.get("slow_until",0)>clock:pace*=1.0-float(e.get("slow_amount",0))
  e.pos+=direction.normalized()*pace*dt;e.state="walk"
  var movement:Vector3=e.pos-e.previous_pos;e.heading=lerp_angle(e.heading,atan2(movement.x,movement.z),1-exp(-6*dt));e.actual_speed=movement.length()/dt;e.travelled+=movement.length()
  if e.actual_speed/e.body_scale>2.05:e.running=true
  elif e.actual_speed/e.body_scale<1.85:e.running=false
  if e.pos.z>=float(config.line_z):e.resolved=true;e.state="leaked";e.changed=clock;life=maxi(0,life-1);leaked+=1
 var targets:Array=[]
 for e in live:e.query_id=e.id*2;e.query_enemy=true;targets.append(e)
 for a in allies:
  if alive(a):a.query_id=a.id*2+1;a.query_enemy=false;targets.append(a)
 projectiles.step(dt,targets,Callable(self,"hurt"));impact_events.append_array(projectiles.events)
 if life<=0:status="defeat"
 elif spawned>=int(config.total) and active_count()==0:status="victory"
