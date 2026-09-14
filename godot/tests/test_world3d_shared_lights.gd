extends SceneTree
func _initialize():
 var lights=preload("res://scripts/world3d/projectile_lights.gd").new()
 lights.shared_flights=true;lights.settings.missile_light_enabled=true
 var points:Array=[]
 for i in 100:points.append(Vector3(float(i%5)*.02,0,0))
 var merged:Array=lights.advance(.12,points)
 assert(merged.size()==1,"Dense volley must share one contribution")
 assert(merged[0].position.distance_to(Vector3(.8,0,0))<.001,"Use volley centroid")
 points.reverse()
 var reordered:Array=lights.advance(.016,points)
 assert(reordered[0].position.distance_to(merged[0].position)<.001,"Array order must not relocate an established group")
 var tail:Array=lights.advance(.06,[])
 assert(tail.size()==1 and is_equal_approx(tail[0].energy,merged[0].energy*.5))
 assert(tail[0].position==reordered[0].position,"Fade in place, no travel to replacement")
 assert(lights.advance(.07,[]).is_empty())
 for i in 20:points.append(Vector3(i*3,0,0))
 var crowded:Array=lights.advance(.12,points)
 assert(crowded.size()<=4)
 lights.impact(Vector3(0,0,5))
 var explosion:Array=lights.advance(.06,points)
 assert(explosion.size()<=4 and explosion[0].position==Vector3(0,0,-100),"Explosion keeps priority")
 var energy:=0.0
 for entry in explosion:energy+=entry.energy
 assert(energy<=1.25001)
 lights.clear();assert(lights.advance(.016,[]).is_empty(),"Restart clears fading groups too")
 lights.advance(.12,points);lights.settings.missile_light_enabled=false
 assert(lights.advance(.016,points).is_empty() and lights.flight_groups.is_empty())
 print("WORLD3D_SHARED_LIGHTS_PASS centroid, reorder, fade, slots, burst priority, energy, clear, disable")
 quit()
