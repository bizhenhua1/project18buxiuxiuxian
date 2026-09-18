extends "res://scripts/world3d/projectiles.gd"
var hit_handler:Callable
var ground_handler:Callable
# Homing locks one query ID; ballistic shots retain their launch vector and
# collide with the first opposing body. Both use the shared swept collision.
func launch_at(origin:Vector3,target:Dictionary,speed:float,damage:float,enemy:bool,source_id:int,mode:String)->int:
 var id:=launch(origin,BODY.center(target)-origin,speed,damage,enemy,1,source_id)
 var shot:Dictionary=active.back();shot.mode=mode;shot.target_id=target.id*2+(1 if enemy else 0)
 return id
func can_hit(shot:Dictionary,unit:Dictionary)->bool:
 return shot.get("mode","")!="ground" and super(shot,unit) and (shot.get("mode","ballistic")!="homing" or unit.query_id==shot.target_id)
func deal_damage(shot:Dictionary,unit:Dictionary,callback:Callable):
 if hit_handler.is_valid():hit_handler.call(shot,unit)
 else:super(shot,unit,callback)
func launch_ground(origin:Vector3,destination:Vector3,speed:float,damage:float,source:int,payload:Dictionary):
 launch(origin,destination-origin,speed,damage,false,1,source)
 active.back().mode="ground";active.back().destination=destination;active.back().payload=payload
func step(dt:float,targets:Array,damage_callback:Callable):
 var styles:Dictionary={}
 for shot in active:
  if shot.get("payload",{}).has("color"):styles[shot.id]=shot.payload.color
 var ground_events:Array=[]
 for i in range(active.size()-1,-1,-1):
  var shot:Dictionary=active[i]
  if shot.get("mode","")=="ground" and shot.pos.distance_to(shot.destination)<=shot.velocity.length()*dt:
   if ground_handler.is_valid():ground_handler.call(shot)
   ground_events.append({"shot":shot.id,"position":shot.destination,"target":-1});active.remove_at(i)
 var lookup:Dictionary={}
 for unit in targets:
  if unit.hp>0 and not unit.get("resolved",false):lookup[unit.query_id]=unit
 for i in range(active.size()-1,-1,-1):
  var shot:Dictionary=active[i]
  if shot.get("mode","ballistic")!="homing":continue
  if not lookup.has(shot.target_id):active.remove_at(i);continue
  var direction:Vector3=BODY.center(lookup[shot.target_id])-shot.pos
  if direction.length_squared()>.000001:shot.velocity=direction.normalized()*shot.velocity.length()
 super(dt,targets,damage_callback)
 events.append_array(ground_events)
 for event in events:
  if styles.has(event.shot):event.color=styles[event.shot]
