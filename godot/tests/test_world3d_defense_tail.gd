extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 var shell=load("res://scenes/defense_3d.tscn").instantiate();root.add_child(shell)
 while not shell.kit:await process_frame
 var stage=shell.stage;stage.set_process(false);stage.start_battle(false)
 # Tail/lifetime fixture: keep the defense alive to observe every original
 # spawn and its original damage/leak resolution. This is not a balance test.
 stage.sim.life=1000
 for ally in stage.sim.allies:
  ally.hp=10000;ally.max_hp=10000;ally.attack=90;ally.range=24
 var seen:Dictionary={}
 for frame in 6000:
  stage._process(.05);await process_frame
  for enemy in stage.sim.enemies:
   if stage.sim.clock>=enemy.activate_at and enemy.hp>0 and not enemy.resolved:
    assert(stage.pool_ids.has(enemy.id),"Tail enemy has no model")
    var actor=stage.pool_ids[enemy.id].actor
    if stage.sim.clock-enemy.born>.1:assert(actor.visible,"Living enemy hidden after birth fade began")
    seen[enemy.id]=true
  if stage.phase in ["victory","defeat"]:break
 assert(stage.phase=="victory" and stage.sim.spawned==90)
 assert(seen.has(89),"Last boss was not rendered alive")
 assert(stage.sim.killed+stage.sim.leaked==90)
 for frame in 160:stage._process(.05);await process_frame
 for slot in stage.enemy_pool:assert(not slot.actor.visible,"Resolved enemy remains after smoke")
 assert(stage.sim.shots.is_empty() and stage.sim.projectiles.active.is_empty())
 stage.reset_battle();stage._process(0)
 assert(stage.phase=="prepare" and stage.sim.enemies.is_empty())
 print("DEFENSE_TAIL_PASS controlled survival fixture, all 90 resolved, boss visible, victory, smoke cleanup, restart")
 quit()
