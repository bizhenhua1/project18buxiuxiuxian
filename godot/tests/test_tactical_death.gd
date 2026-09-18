extends SceneTree
func _initialize():call_deferred("run")
func run():
 var shell=load("res://scenes/tactical_presentation.tscn").instantiate();root.add_child(shell)
 while not shell.stage or not shell.stage.ready_stage:await process_frame
 await process_frame
 var s=shell.stage;s.set_process(false);s.begin_tactical();s.sim.next_spawn=INF
 var id:int=s.team_slots[0];var a:Dictionary=s.sim.allies[id];var actor=s.team[0];var life:int=s.sim.life
 assert(s.sim.command(id,"advance"))
 for i in 35:s._process(.05)
 assert(a.pos.distance_to(a.home)>1)
 s.sim.hurt(a,99999)
 s._process(.05);var at:Vector3=actor.position
 for i in 10:s._process(.05)
 assert(actor.dead and actor.position.distance_to(at)<.001 and s.sim.life==life)
 while a.death_phase=="fallen":s._process(.05)
 assert(a.death_phase=="light" and s.souls[0].visible and actor.opacity==0)
 while a.death_phase=="light":s._process(.05)
 assert(a.death_phase=="respawn" and actor.dead)
 var target:Vector3=s.world_point(a.home)+Vector3.UP*float(s.profiles[id].clearance)/20
 assert(actor.position.distance_to(target)<.001)
 while a.hp<=0:s._process(.05)
 assert(not actor.dead and a.hp==a.max_hp and s.sim.life==life)
 print("TACTICAL_DEATH_PASS forward, in-place death, colored return, home corpse, respawn; defense life unchanged")
 quit()
