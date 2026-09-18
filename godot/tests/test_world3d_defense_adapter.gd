extends SceneTree
func _initialize():
 var original=preload("res://scripts/defense/defense_sim.gd").new()
 var native=preload("res://scripts/world3d/defense_adapter.gd").new()
 for stress in [false,true]:
  original.reset(stress);native.reset(stress);original.begin();native.begin()
  for tick in 5000:
   if tick==50:assert(original.pulse()==native.pulse())
   original.step(.05);native.step(.05)
   assert(JSON.stringify(original.enemies)==JSON.stringify(native.enemies),"Enemy movement or health changed")
   assert(JSON.stringify(original.allies)==JSON.stringify(native.allies),"Ally rules changed")
   assert(JSON.stringify(original.shots)==JSON.stringify(native.shots),"Damage timing changed")
   assert(original.life==native.life and original.status==native.status and original.killed==native.killed)
   if native.status!="battle":break
  assert(native.status in ["victory","defeat"])
 print("DEFENSE_ADAPTER_PASS normal and 50-enemy waves, pulse, movement, targeting, damage, life and result unchanged")
 quit()
