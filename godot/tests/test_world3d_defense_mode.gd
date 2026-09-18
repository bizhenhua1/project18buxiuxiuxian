extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 set_meta("world3d_fork_test",3)
 var shell=load("res://scenes/defense_3d.tscn").instantiate();root.add_child(shell)
 while not shell.stage or not shell.stage.ready_stage:await process_frame
 for frame in 3:await process_frame
 var stage=shell.stage;stage.set_process(false)
 assert(stage.phase=="prepare")
 shell.kit.pressed.emit()
 var editor=shell.get_node("PartyEditor")
 assert(editor.model.player.size()==stage.units.size())
 editor.queue_free();await process_frame
 assert(stage.fork_test==0,"Fork test state leaked into continuous defense")
 var camera_at:Vector3=stage.camera.position
 stage.start_battle(true)
 for frame in 140:
  stage._process(.05);await process_frame
 assert(stage.sim.spawned==50)
 for enemy in stage.sim.enemies:
  if stage.sim.clock>=enemy.activate_at and enemy.state!="leaked":assert(stage.pool_ids.has(enemy.id),"Live enemy lacks a model slot")
 assert(stage.sim.pulse())
 stage.stage_light_enabled=false;stage.character_fill=.4;stage.storm_enabled=false;stage._process(0)
 assert(stage.bridge.team_light().road_energy==0 and is_equal_approx(stage.bridge.team_light().ambient,.4))
 assert(not stage.projectile_view.enabled)
 stage.sim.projectiles.active.append({"pos":Vector3.ZERO,"enemy":false})
 stage._process(0);assert(stage.fallback.multimesh.visible_instance_count>0)
 stage.sim.projectiles.active.pop_back()
 stage.storm_enabled=true;stage._process(0)
 assert(stage.projectile_view.enabled and stage.fallback.multimesh.visible_instance_count==0)
 var corpse:Dictionary=stage.sim.enemies[0]
 corpse.hp=0;corpse.state="death";corpse.changed=stage.sim.clock
 stage.render_enemies(0)
 assert(stage.corpse_fog.multimesh.visible_instance_count==0)
 stage.sim.clock+=5.6;stage.render_enemies(0)
 assert(stage.corpse_fog.multimesh.visible_instance_count>0,"Corpse did not dissolve after five seconds")
 stage.reset_battle();stage._process(0)
 assert(stage.corpse_fog.entries.is_empty() and stage.corpse_fog.multimesh.visible_instance_count==0,"Restart retained corpse smoke")
 assert(stage.phase=="prepare" and stage.camera.position.distance_to(camera_at)<.001,"Restart changed the accepted battle camera")
 stage.start_battle(false)
 for frame in 6000:
  stage._process(.05);await process_frame
  for enemy in stage.sim.enemies:
   if stage.sim.clock>=enemy.activate_at and enemy.hp>0 and not enemy.resolved:
    assert(stage.pool_ids.has(enemy.id),"Normal wave enemy lacks a model")
  if stage.phase in ["victory","defeat"]:break
 assert(stage.phase in ["victory","defeat"],"Normal wave never completed")
 print("DEFENSE_NATURAL_RESULT ",stage.phase," spawned=",stage.sim.spawned," clock=",stage.sim.clock)
 for frame in 80:stage._process(.05);await process_frame
 stage.reset_battle();stage._process(0)
 assert(stage.phase=="prepare" and stage.sim.enemies.is_empty() and stage.corpse_fog.entries.is_empty())
 for frame in 3:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/world3d-defense-mode.png")
 print("DEFENSE_3D_MODE_PASS native pool, 50 enemies, pulse, independent fill, stage light, projectile toggle, stationary restart")
 quit()
