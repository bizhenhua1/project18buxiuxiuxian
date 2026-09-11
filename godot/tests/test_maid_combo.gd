extends SceneTree
func _initialize():call_deferred("run")
func run():
 var actor=load("res://scripts/battle/maid_swordswoman.gd").new();actor.model_scene=load("res://assets/characters3d/isabella.glb");actor.ally=true;root.add_child(actor)
 var unit={"uid":9,"hp":100,"cd":1500}
 actor.bind_unit(unit)
 assert(actor.sword!=null and unit.atkType=="melee")
 for i in 8:
  actor.trigger("shot")
  assert(unit.combo_stage==i%4+1)
  assert(actor.clips.attack.id.ends_with("Combo"+str(i%4+1)))
  actor.trigger("damage");assert(actor.state=="attack")
  actor.advance(.2,"battle",false,1,true)
  actor.advance(1.5,"battle",false,1,true)
  assert(actor.state=="idle")
 actor.trigger("death");assert(actor.dead)
 actor.trigger("revive");actor.trigger("shot");assert(unit.combo_stage==1)
 print("MAID_COMBO_PASS 12341234, sword, hit protection, death/revive")
 quit()
