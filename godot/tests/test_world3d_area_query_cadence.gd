extends SceneTree
func _initialize():
 var reference=preload("res://scripts/world3d/areas.gd").new()
 var candidate=preload("res://scripts/world3d/areas.gd").new()
 var old_hits:Array=[];var new_hits:Array=[];var refreshes:=0;var clock:=0.0
 var units:Array=[{"id":1,"pos":Vector3.ZERO,"hp":100.0}]
 for system in [reference,candidate]:
  system.add_zone(Vector3.ZERO,2,1,3,3,.3)
  system.add_zone(Vector3(2,0,0),1,1,5,2.7,.7)
 for frame in 100:
  var dt:float=.8 if frame==11 else .05
  clock+=dt;units[0].pos.x=sin(clock)*3
  reference.sync(units,func(p):return p,clock)
  if candidate.needs_targets(dt):
   candidate.sync(units,func(p):return p,clock);refreshes+=1
  reference.advance(dt,func(unit,amount):old_hits.append([unit.id,amount]))
  candidate.advance(dt,func(unit,amount):new_hits.append([unit.id,amount]))
  assert(old_hits==new_hits and reference.zones==candidate.zones)
 assert(refreshes<30 and not old_hits.is_empty())
 print("AREA_QUERY_CADENCE PASS identical moving-target hits and expiry; refreshes=",refreshes," instead of 100")
 quit()
