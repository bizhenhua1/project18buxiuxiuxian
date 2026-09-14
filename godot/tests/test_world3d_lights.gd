extends SceneTree
func _initialize():
 var lights=preload("res://scripts/world3d/projectile_lights.gd").new()
 lights.settings.missile_light_enabled=true
 var position:=Vector3(1,2,-3)
 lights.impact(position)
 var peak:Array=lights.advance(.06,[])
 assert(peak.size()==1 and peak[0].energy>.9,"Impact should brighten after projectile removal")
 assert(peak[0].position==Vector3(20,40,60),"Light and scene must share coordinates")
 var tail:Array=lights.advance(.3,[])
 assert(tail.size()==1 and tail[0].energy<peak[0].energy and tail[0].energy>0)
 assert(lights.advance(1,[]).is_empty(),"Explosion light must expire")
 var crowded:Array=lights.advance(0,[position,position,position,position,position])
 var sum:=0.0
 for light in crowded:sum+=light.energy
 assert(crowded.size()==4 and sum<=1.25001,"Multiple lights must respect shader slots and total energy budget")
 lights.settings.missile_light_enabled=false;lights.settings.missile_burst_enabled=false
 lights.impact(position);assert(lights.advance(.03,[position]).is_empty())
 print("WORLD3D_LIGHTS_PASS coordinate mapping, explosion peak/tail, energy budget, disabled profiles")
 quit()
