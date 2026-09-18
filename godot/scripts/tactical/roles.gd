extends RefCounted
var owner_ref:WeakRef
var sim:
 get:return owner_ref.get_ref()
var pending:Array=[]
var zones:Array=[]
var cues:Array=[]
var serial:=0
func _init(owner_sim):owner_ref=weakref(owner_sim)
func reset():pending.clear();zones.clear();cues.clear();serial=0
func cancel_source(id:int):
 for i in range(pending.size()-1,-1,-1):
  if pending[i].source==id:pending.remove_at(i)
func configure(a:Dictionary,r:Dictionary):
 a.class_label=r.class_label;a.role=r.key;a.display_name=r.name;a.profession=r.profession;a.max_hp=r.hp;a.hp=r.hp;a.attack=r.attack;a.cooldown=r.cooldown;a.block=r.block;a.base_block=r.block;a.range=r.range;a.skill=r.skill;a.projectile_mode=r.projectile_mode
 a.melee=r.key in ["gate","maid","spear","push"];a.taunt=r.key=="gate";a.strikes=0;a.shield=0.0;a.shield_until=0.0;a.reduce=0.0
func duration(a:Dictionary)->float:
 var clips:Array=a.get("attack_durations",[])
 return maxf(.4,float(clips[int(a.get("animation_index",0))%clips.size()])) if not clips.is_empty() else .65
func animate(a:Dictionary):
 a.attack_duration=duration(a);a.animation_index=int(a.get("animation_index",0))+1;a.state="attack";a.changed=sim.clock;a.next=maxf(a.next,sim.clock+maxf(a.cooldown,a.attack_duration))
func cue(origin:Vector3,spec:Dictionary,color:String,seconds:float):
 if cues.size()>=32:
  if seconds<.7:return
  var replace:=0
  for i in cues.size():
   if cues[i].until<cues[replace].until:replace=i
  cues.remove_at(replace)
 cues.append({"id":serial,"origin":origin,"spec":spec,"color":color,"until":sim.clock+seconds});serial+=1
func slow(e:Dictionary,amount:float,seconds:float):
 if e.get("slow_until",0)<=sim.clock:e.slow_amount=0.0
 e.slow_amount=maxf(float(e.get("slow_amount",0)),amount);e.slow_until=maxf(float(e.get("slow_until",0)),sim.clock+seconds)
func push(e:Dictionary,distance:float):
 if e.hp<=0 or e.boss:return
 var amount:float=distance*(.5 if e.body_scale>1.2 else 1.0)
 e.push_left=maxf(float(e.get("push_left",0)),amount);e.blocked_by=-1;e.taunted_by=-1
func heal(a:Dictionary,amount:float):
 if not sim.alive(a):return
 a.hp=minf(a.max_hp,a.hp+amount)
 cue(a.pos,{"shape":"circle","radius":1.2},"9aefc2",.45)
func deal(target:Dictionary,amount:float,source:Dictionary={},direct:bool=true):
 var before:float=target.hp;sim.hurt(target,amount)
 if target.hp<before:
  cue(target.pos,{"shape":"circle","radius":.8},"edcaa0",.18)
  if target.get("role","")=="gate" and direct and source.has("resolved") and source.get("blocked_by",-1)==target.id:
   sim.hurt(source,target.attack*.2)
func enemies_in(origin:Vector3,spec:Dictionary)->Array:
 var result:Array=[]
 for e in sim.enemies:
  if e.hp>0 and not e.resolved and sim.clock>=e.activate_at and sim.RULES.contains(origin,e.pos,spec):result.append(e)
 return result
func candidates(a:Dictionary)->Array:
 var result:Array=[]
 for e in sim.enemies:
  if e.hp>0 and not e.resolved and sim.clock>=e.activate_at and a.pos.distance_to(e.pos)<=a.range:result.append(e)
 if a.get("role","")=="needle":
  result.sort_custom(func(x,y):
   var xb:bool=x.get("blocked_by",-1)>=0;var yb:bool=y.get("blocked_by",-1)>=0
   if xb!=yb:return not xb
   return x.id<y.id if is_equal_approx(x.pos.z,y.pos.z) else x.pos.z>y.pos.z)
 else:result.sort_custom(func(x,y):return a.pos.distance_squared_to(x.pos)<a.pos.distance_squared_to(y.pos))
 return result
func choose(a:Dictionary)->Dictionary:
 if a.get("role","")!="heal":
  var list:=candidates(a);return {} if list.is_empty() else list[0]
 var result:Dictionary={};var ratio:=1.0
 for friend in sim.allies:
  if sim.alive(friend) and a.pos.distance_to(friend.pos)<=a.range and friend.hp/friend.max_hp<ratio:result=friend;ratio=friend.hp/friend.max_hp
 return result
func attack(a:Dictionary,target:Dictionary):
 animate(a);a.strikes+=1;a.aim_id=target.id if a.role!="heal" else -1
 if a.role=="heal":a.aim_point=target.pos;a.aim_until=sim.clock+a.attack_duration
 else:a.erase("aim_point")
 var damage:float=a.attack
 if a.role=="maid" and a.strikes%4==0:damage*=1.4
 if a.role=="needle" and target.get("blocked_by",-1)<0:damage*=1.2
 pending.append({"kind":"attack","source":a.id,"target":target,"damage":damage,"due":sim.clock+a.attack_duration*.42,"stamp":a.changed,"strike":a.strikes})
 if a.melee:
  a.attack_origin=a.pos;a.attack_tip=sim.limit_forward(a.pos+(target.pos-a.pos).normalized()*minf(.7,maxf(0,a.pos.distance_to(target.pos)-.9)),a.pos)
 sim.add_energy(a,"attack")
func cast(a:Dictionary,spec:Dictionary):
 animate(a);a.aim_id=-1;a.aim_point=a.pos+Vector3(0,0,-20);a.aim_until=sim.clock+a.attack_duration
 var effect:String=spec.effect
 if effect=="gate":
  a.fortify_until=sim.clock+8;a.block=a.base_block+2;a.reduce=.35
  var count:=cues.size();cue(a.pos,{"shape":"circle","radius":2.0},"e6c374",8)
  if cues.size()>count:cues.back().follow=a.id
  return
 var origin:Vector3=a.pos
 pending.append({"kind":"skill","source":a.id,"spec":spec.duplicate(true),"origin":origin,"due":sim.clock+a.attack_duration*.42,"stamp":a.changed})
 if a.melee:a.attack_origin=a.pos;a.attack_tip=sim.limit_forward(a.pos+Vector3(0,0,-.7),a.pos)
func add_zone(origin:Vector3,radius:float,source:Dictionary,kind:String,seconds:float,damage:float):
 zones.append({"origin":origin,"radius":radius,"source":source.id,"kind":kind,"until":sim.clock+seconds,"next":floorf(sim.clock)+1,"damage":damage})
 cue(origin,{"shape":"circle","radius":radius},"efa36a" if kind=="fire" else "9aefc2" if kind=="heal" else "b29ad6",seconds)
func resolve_skill(a:Dictionary,spec:Dictionary,origin:Vector3):
 var effect:String=spec.effect
 if effect=="fire":
  var destination:Vector3=sim.RULES.center(origin,spec)
  sim.projectiles.launch_ground(sim.attack_origin(a,false),destination+Vector3.UP*.2,12,a.attack*3,a.id,{"effect":"fire","radius":spec.radius,"color":"ff954fff"})
  cue(destination,{"shape":"circle","radius":spec.radius},"efba85",2);return
 if effect=="needle":
  for i in 7:pending.append({"kind":"needle","source":a.id,"due":sim.clock+i*(4.0/6.0),"index":i})
  return
 if effect=="heal":
  for friend in sim.allies:
   if sim.alive(friend) and sim.RULES.contains(origin,friend.pos,spec):friend.shield=maxf(float(friend.get("shield",0)),80);friend.shield_until=sim.clock+6
  add_zone(origin,spec.radius,a,"heal",6,a.attack*.7);return
 if effect=="slow":add_zone(sim.RULES.center(origin,spec),spec.radius,a,"slow",6,a.attack*.4);return
 cue(origin,spec,"e5d69d",.7)
 for e in enemies_in(origin,spec):
  deal(e,a.attack*(2.8 if effect=="maid" else 2.2 if effect=="spear" else 1.8),a)
  if effect=="push":push(e,4)
 if effect=="spear":
  for friend in sim.allies:
   if sim.alive(friend) and abs(preload("res://scripts/tactical/engagements.gd").column(sim,friend.pos.x)-preload("res://scripts/tactical/engagements.gd").column(sim,a.pos.x))==1:friend.energy=minf(sim.energy_limit(friend),friend.energy+4)
func projectile_hit(shot:Dictionary,target:Dictionary):
 var source:Dictionary=sim.allies[shot.source_id] if not shot.enemy and shot.source_id>=0 else sim.enemies[shot.source_id] if shot.enemy and shot.source_id>=0 else {}
 deal(target,shot.damage,source)
 var effect:String=shot.get("payload",{}).get("effect","")
 if effect=="fire_splash":
  for e in enemies_in(target.pos,{"shape":"circle","radius":2.0}):
   if e.id!=target.id:deal(e,shot.damage*.5,source,false)
 elif effect=="slow":slow(target,.25,1.2)
func ground_hit(shot:Dictionary):
 var a:Dictionary=sim.allies[shot.source_id];var point:Vector3=shot.destination;point.y=0
 for e in enemies_in(point,{"shape":"circle","radius":shot.payload.radius}):deal(e,shot.damage,a,false)
 add_zone(point,shot.payload.radius,a,"fire",4,a.attack*.25)
func step():
 for i in range(cues.size()-1,-1,-1):
  if cues[i].has("follow"):
   var owner:Dictionary=sim.allies[cues[i].follow]
   cues[i].origin=owner.pos
   if not sim.alive(owner):cues[i].until=sim.clock
  if cues[i].until<=sim.clock:cues.remove_at(i)
 for a in sim.allies:
  if a.get("fortify_until",INF)<=sim.clock:a.block=a.get("base_block",a.block)+(1 if a.get("guard_until",0)>sim.clock else 0);a.reduce=0;a.erase("fortify_until")
  if a.get("shield_until",INF)<=sim.clock:a.shield=0
 for i in range(pending.size()-1,-1,-1):
  var job:Dictionary=pending[i]
  if job.due>sim.clock:continue
  pending.remove_at(i)
  var a:Dictionary=sim.allies[job.source]
  if not sim.alive(a):continue
  if job.kind=="needle":
   var list:=candidates(a)
   if list.is_empty():continue
   var target:Dictionary=list[int(job.index)%mini(3,list.size())]
   a.aim_id=target.id
   sim.projectiles.launch_at(sim.attack_origin(a,false),target,18,a.attack*1.2,false,a.id,"homing")
   sim.projectiles.active.back().payload={"color":"e2dbffff"};continue
  if a.order=="move" or a.changed!=job.stamp:continue
  if job.kind=="skill":resolve_skill(a,job.spec,job.origin);continue
  var target:Dictionary=job.target
  if target.hp<=0 or target.get("resolved",false):continue
  if a.role=="heal":
   if a.pos.distance_to(target.pos)<=a.range:heal(target,job.damage*(1.2 if target.hp/target.max_hp<.35 else 1.0))
  elif a.melee:
   if a.pos.distance_to(target.pos)>a.range+1:continue
   deal(target,job.damage,a)
   if a.role=="push" and job.strike%3==0:push(target,1.5)
   if a.role=="spear" and a.get("charge_ready",false):slow(target,.3,2);a.charge_ready=false
  else:
   sim.projectiles.launch_at(sim.attack_origin(a,false),target,14,job.damage,false,a.id,a.projectile_mode)
   sim.projectiles.active.back().payload={"effect":"fire_splash" if a.role=="fire" else "slow" if a.role=="slow" else "","color":"ff954fff" if a.role=="fire" else "b596ffff" if a.role=="slow" else "e2dbffff"}
 # Overlapping identical zones use the strongest damage per target per tick.
 var damage_by_kind:Dictionary={}
 for z in zones:
  if z.until<sim.clock:continue
  var source:Dictionary=sim.allies[z.source]
  if z.kind=="heal" and not sim.alive(source):continue
  if z.kind=="slow":
   for e in enemies_in(z.origin,{"shape":"circle","radius":z.radius}):slow(e,.45,.15)
  if z.next>sim.clock:continue
  z.next+=1
  if z.kind=="heal":
   for friend in sim.allies:
    if sim.alive(friend) and friend.pos.distance_to(z.origin)<=z.radius:heal(friend,z.damage)
  else:
   for e in enemies_in(z.origin,{"shape":"circle","radius":z.radius}):
    var key:String=z.kind+str(e.id);var previous:Dictionary=damage_by_kind.get(key,{})
    if previous.is_empty() or z.damage>previous.damage:damage_by_kind[key]={"target":e,"damage":z.damage}
 for value in damage_by_kind.values():deal(value.target,value.damage,{},false)
 for i in range(zones.size()-1,-1,-1):
  if zones[i].until<=sim.clock:zones.remove_at(i)
