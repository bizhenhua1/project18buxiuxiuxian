extends SceneTree
func _initialize():call_deferred("run")
func run():
 var shell=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(shell)
 while not shell.stage or not shell.stage.ready_stage:await process_frame
 var stage=shell.stage;stage.set_process(false);stage.start_battle()
 var enemy:Dictionary=stage.sim.enemies[0]
 enemy.activate_at=0;enemy.entry_phase="advance"
 var pool=stage.enemy_pool.filter(func(slot):return slot.kind==enemy.type)[0]
 for step in [Vector3(.1,0,.05),Vector3(-.1,0,.05),Vector3.ZERO]:
  stage.pool_ids.clear();pool.id=-1;pool.actor.rotation.y=2.4
  enemy.previous_pos=Vector3(0,0,-5);enemy.pos=enemy.previous_pos+step;enemy.heading=.4
  stage.step_clock=.05;stage.render_enemies(.01)
  var local:Vector3=step if step.length_squared()>0 else Vector3(sin(.4),0,cos(.4))
  var expected:Vector3=stage.world_point(enemy.pos+local)-stage.world_point(enemy.pos)
  assert(absf(angle_difference(pool.actor.rotation.y,atan2(expected.x,expected.z)))<.0001,"First visible pose must use new creature direction")
 print("WORLD3D_SPAWN_FACING_PASS left, right, stationary fallback, stale pooled yaw")
 quit()
