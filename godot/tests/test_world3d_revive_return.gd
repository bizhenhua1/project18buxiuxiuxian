extends SceneTree
func _initialize():
 var sim=preload("res://scripts/world3d/combat_sim.gd").new();sim.reset(false);sim.status="battle";sim.next_spawn=INF
 var unit:Dictionary=sim.allies[0];var home:Vector3=unit.pos
 unit.attack_origin=home;unit.attack_tip=home+Vector3(0,0,-3);unit.pos=unit.attack_tip
 unit.hp=0;unit.state="death"
 sim.step(.05);assert(unit.pos==unit.attack_tip)
 unit.hp=100
 sim.step(.05)
 assert(unit.state=="returning" and not unit.has("attack_origin"))
 assert(is_equal_approx(unit.pos.distance_to(home),2.85))
 assert(unit.next>sim.clock)
 # A second death during recovery must preserve the original home.
 unit.hp=0;unit.state="death";var stopped:Vector3=unit.pos
 sim.step(.05);assert(unit.pos==stopped)
 unit.hp=100
 for i in 30:
  var previous:Vector3=unit.pos
  sim.step(.05)
  assert(unit.pos.distance_to(previous)<=.15001)
 assert(unit.pos.is_equal_approx(home) and unit.state=="idle")
 assert(not unit.has("return_target"))
 print("WORLD3D_REVIVE_RETURN PASS fixed-speed recovery, interrupted recovery, original home retained")
 quit()
