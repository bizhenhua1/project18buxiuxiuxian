extends SceneTree
func _initialize():call_deferred("run")
func run():
 var shell=load("res://scenes/tactical_presentation.tscn").instantiate();root.add_child(shell)
 while not shell.stage or not shell.stage.ready_stage:await process_frame
 var s=shell.stage;s.set_process(false);s.begin_tactical();s.sim.next_spawn=INF
 for i in 2:
  s.sim.spawn_enemy();var e:Dictionary=s.sim.enemies.back();e.activate_at=0;e.born=-1;e.entry="road";e.entry_phase="advance";e.pos=Vector3(i*2,0,-1);e.previous_pos=e.pos
 s.sim.enemies[1].revives_remaining=1
 for e in s.sim.enemies:s.sim.hurt(e,100000)
 s.sim.clock=4.99;s.render_enemies(0)
 var actor=s.pool_ids[0].actor
 assert(actor.visible and is_equal_approx(actor.opacity,1))
 s.sim.clock=5.55;s.render_enemies(0)
 assert(actor.opacity>0 and actor.opacity<1 and s.corpse_smoke.multimesh.visible_instance_count>0)
 assert(s.pool_ids[1].actor.opacity==1,"Rebirth talent must retain the corpse")
 s.sim.clock=6.5;s.render_enemies(0)
 assert(s.sim.enemies[0].visual_removed and not s.pool_ids.has(0) and not actor.visible)
 s.render_enemies(0);assert(not s.pool_ids.has(0),"A dissolved corpse must never be rebound")
 s.sim.enemies[1].revives_remaining=0;s.render_enemies(0)
 assert(not s.pool_ids.has(1),"Exhausted revival eligibility permits cleanup")
 s.sim.spawn_enemy();var fresh:Dictionary=s.sim.enemies.back();fresh.type=0;fresh.activate_at=0;fresh.born=-1;fresh.entry_phase="advance"
 s.render_enemies(0)
 assert(s.pool_ids[fresh.id].actor==actor and not actor.dead and actor.visible,"Reused slot must display the new living enemy")
 s.begin_tactical();assert(s.corpse_smoke.entries.is_empty() and s.corpse_smoke.multimesh.visible_instance_count==0)
 print("TACTICAL_CORPSE_SMOKE_PASS five-second hold, smoke fade, rebirth exemption, removal, slot reuse and restart")
 quit()
