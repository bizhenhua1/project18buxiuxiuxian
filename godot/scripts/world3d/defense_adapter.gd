extends "res://scripts/defense/defense_sim.gd"
## Preserve original defense rules exactly; these extra fields are presentation only.
var projectiles=preload("res://scripts/world3d/projectiles.gd").new()
var areas=preload("res://scripts/world3d/areas.gd").new()
var windups:Array=[]
var impact_events:Array=[]
var skill_world:Callable
var emission_origin:Callable
func reset(load_test:=false):
 super(load_test);projectiles.clear();areas.clear();windups.clear();impact_events.clear()
func seed_encounter(_seed:int,_route:int,_branch:int,_station:float,_index:int):pass
func step(dt:float):
 var previous_clock:=clock
 super(dt)
 if clock==previous_clock:return
 # These visuals follow the original fixed endpoints and due time. Never call
 # projectiles.step: swept collision would change the old mode's damage rules.
 for i in range(projectiles.active.size()-1,-1,-1):
  var shot:Dictionary=projectiles.active[i]
  shot.previous=shot.pos
  var t:float=clampf((clock-float(shot.started))/float(shot.duration),0,1)
  shot.pos=shot.origin.lerp(shot.destination,t)
  if t>=1:
   impact_events.append({"position":shot.destination,"target":shot.id});projectiles.active.remove_at(i)
 for fx in effects:
  if not fx.ranged:continue
  var id:int=projectiles.next_id;projectiles.next_id+=1
  projectiles.active.append({"id":id,"source_id":-1,"enemy":fx.enemy,"origin":fx.from,"previous":fx.from,"pos":fx.from,"destination":fx.to,"started":clock,"duration":maxf(.001,float(fx.duration))})
