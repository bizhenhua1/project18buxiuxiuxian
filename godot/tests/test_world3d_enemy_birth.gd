extends SceneTree
func _initialize():call_deferred("run")
func run():
 var shell=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(shell)
 while not shell.stage or not shell.stage.ready_stage:await process_frame
 var stage=shell.stage;stage.set_process(false);stage.start_battle()
 var enemy:Dictionary=stage.sim.enemies[0]
 enemy.activate_at=0;enemy.born=0;enemy.entry_phase="advance"
 var previous:=-1.0
 for time in [0.0,.175,.35,.525,.7,2.0]:
  stage.sim.clock=time;stage.render_enemies(.01)
  var actor=stage.pool_ids[enemy.id].actor
  assert(actor.opacity>=previous and is_equal_approx(actor.opacity,smoothstep(0,.7,time)))
  assert(actor.visible==(actor.opacity>.001))
  previous=actor.opacity
 var actor=stage.pool_ids[enemy.id].actor
 enemy.born=1.9;enemy.hp=0;enemy.changed=2.0
 stage.render_enemies(.01)
 assert(actor.dead and actor.visible and actor.opacity==1.0,"Death during birth must leave a visible corpse")
 enemy.hp=10;enemy.born=-1;stage.sim.clock=0;stage.render_enemies(.01)
 assert(actor.opacity==1.0,"Predeployed encounter adoption must not fade a second time")
 print("WORLD3D_ENEMY_BIRTH_PASS smooth reveal, full opacity, death, adopted encounter")
 quit()
