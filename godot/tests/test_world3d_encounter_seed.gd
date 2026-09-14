extends SceneTree
const SIM=preload("res://scripts/world3d/combat_sim.gd")
func wave(seed_value:int,branch:int,station:float,event_index:int)->Array:
 var sim=SIM.new();sim.reset(false);sim.seed_encounter(seed_value,1,branch,station,event_index)
 var result:Array=[]
 for i in 16:
  sim.spawn_enemy()
  var unit:Dictionary=sim.enemies.back()
  result.append([unit.type,unit.pos,unit.speed_factor,unit.activate_at,unit.entry])
 return result
func _initialize():
 var original:=wave(1842,-1,700,2)
 assert(original==wave(1842,-1,700,2),"Retry must reproduce the same arrivals")
 for changed in [wave(1843,-1,700,2),wave(1842,1,700,2),wave(1842,-1,900,2),wave(1842,-1,700,3)]:
  assert(changed!=original,"Another adventure/branch/event must not replay the fixed spawn geometry")
  for i in original.size():assert(changed[i][0]==original[i][0],"Spawn variation must preserve the capacity-validated type plan")
 var pressure=SIM.new();pressure.reset(true);assert(pressure.rng.seed==86731)
 print("WORLD3D_ENCOUNTER_SEED_PASS reproducible retries, adventure/branch/event variation, fixed type plan and pressure seed")
 quit()
