extends SceneTree
func _initialize():call_deferred("run")
func run():
 var shell=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(shell)
 while not shell.stage or not shell.stage.ready_stage:await process_frame
 var stage=shell.stage;stage.set_process(false);stage.start_battle()
 var enemy:Dictionary=stage.sim.enemies[0]
 enemy.activate_at=0;enemy.previous_pos=Vector3(0,0,-5);enemy.pos=Vector3(.15,0,-4.8)
 var crawling:bool="--crawl" in OS.get_cmdline_user_args()
 if crawling:
  enemy.entry="crawl";enemy.entry_phase="advance"
  stage.render_enemies(.01)
 stage.sim.hurt(enemy,enemy.max_hp)
 stage.step_clock=0;stage.render_enemies(.01)
 var actor=stage.pool_ids[enemy.id].actor
 var anchor:Vector3=actor.position
 assert(anchor.distance_to(stage.world_point(enemy.pos))<.0001,"Corpse must use the actual death location")
 for t in [.01,.02,.035,.049]:
  stage.step_clock=t;stage.render_enemies(.01)
  assert(actor.position==anchor,"Interpolation must not keep moving a dead enemy")
 assert(actor.dead and actor.clip==("prone_death" if crawling else "death") and actor.visible)
 stage.sim.clock+=float(actor.library.clips.death.frames-1)/actor.library.clips.death.fps+1;stage.render_enemies(.01)
 assert(actor.death_pose_finished)
 assert(actor.visible and actor.position==anchor,"Completed death must remain in place")
 print("WORLD3D_ENEMY_DEATH_ANCHOR_PASS death point fixed through render interpolation and completed animation")
 quit()
