extends SceneTree
const SIM=preload("res://scripts/world3d/combat_sim.gd")
func _initialize():call_deferred("run")
func fixture():
 var sim=SIM.new();sim.reset(true);sim.status="battle";sim.spawned=49
 sim.config.enemies[0].speed=0;sim.config.enemies[0].behavior="runner"
 sim.spawn_enemy();var enemy=sim.enemies[0];enemy.type=0;enemy.pos=Vector3.ZERO;enemy.previous_pos=enemy.pos;enemy.activate_at=0;enemy.entry_phase="advance";enemy.hp=1000
 var ally={"id":0,"leader":true,"pos":Vector3(0,0,2.5),"hp":100.0,"range":3.0,"attack":25.0,"cooldown":1.0,"next":100.0,"state":"idle","changed":0.0,"type":0,"melee":true}
 sim.allies=[ally];sim.fire(ally,enemy,false)
 return sim
func run():
 var sim=fixture();var start:Vector3=sim.allies[0].pos
 for i in 7:sim.step(.05)
 assert(sim.enemies[0].hp==1000,"Melee cannot damage before the strike marker")
 for i in 14:
  sim.step(.05)
  assert(sim.allies[0].pos.distance_to(start)<=3.001,"Excursion exceeds 1.2 world metres")
 assert(sim.enemies[0].hp==975,"One strike must deal damage exactly once")
 assert(sim.allies[0].pos.distance_to(start)<.001,"Living attacker returns to its real formation position")
 sim=fixture()
 for i in 4:sim.step(.05)
 sim.hurt(sim.allies[0],1000);var died_at:Vector3=sim.allies[0].pos
 for i in 25:sim.step(.05)
 assert(sim.allies[0].pos==died_at,"Death must freeze attack displacement")
 assert(sim.enemies[0].hp==1000,"Death during windup must cancel damage")
 print("WORLD3D_MELEE_PASS bounded excursion, timed single hit, return, death freeze and cancel")
 quit()
