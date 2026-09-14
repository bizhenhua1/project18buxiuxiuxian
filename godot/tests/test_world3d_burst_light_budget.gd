extends SceneTree
func _initialize():
 var lights=preload("res://scripts/world3d/projectile_lights.gd").new()
 lights.shared_flights=true;lights.settings.missile_burst_enabled=true
 for i in 1000:lights.impact(Vector3(float(i%5)*.01,0,0))
 assert(lights.bursts.size()==1,"Nearby simultaneous hits share illumination")
 lights.advance(.03,[])
 lights.impact(Vector3(.1,0,0))
 assert(lights.bursts.size()==1 and lights.bursts[0].age==.03)
 assert(lights.bursts[0].position==Vector3.ZERO,"Repeated hits cannot move or restart flash")
 lights.advance(.03,[]);lights.impact(Vector3.ZERO)
 assert(lights.bursts.size()==2,"Later hits retain a new flash")
 for i in 1000:lights.impact(Vector3(i*3+10,0,0))
 assert(lights.bursts.size()==lights.burst_limit,"Record processing has a hard bound")
 assert(lights.advance(.01,[]).size()<=4)
 lights.advance(10,[]);assert(lights.bursts.is_empty())
 lights.impact(Vector3.ONE);assert(lights.bursts.size()==1,"Capacity recovers")
 lights.clear();lights.settings.missile_burst_enabled=false
 lights.impact(Vector3.ZERO);assert(lights.bursts.is_empty())
 lights.settings.missile_burst_enabled=true;lights.shared_flights=false
 for i in 40:lights.impact(Vector3.ZERO)
 assert(lights.bursts.size()==40,"Full reference mode keeps independent bursts")
 print("WORLD3D_BURST_LIGHT_BUDGET_PASS merge, age, anchor, bound, recovery, disable, reference")
 quit()
