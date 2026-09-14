extends SceneTree
func _initialize():call_deferred("run")
func capture(stage,actor,label:String):
 if "--capture-states" not in OS.get_cmdline_user_args():return
 actor.position=stage.world_point(Vector3(0,0,-1));actor.scale=Vector3.ONE*.73;actor.show()
 actor.portrait_presenter.set_enabled(true);actor.portrait_presenter.configure_enemy(stage.camera,stage.bridge.focal());actor.portrait_presenter.sync()
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/world3d-crawler-"+label+".png")
func run():
 var shell=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(shell)
 while not shell.stage or not shell.stage.ready_stage:await process_frame
 var stage=shell.stage;stage.set_process(false);stage._process(0);stage.start_battle()
 var actor=stage.enemy_pool[0].actor
 var unit:Dictionary=stage.sim.enemies[0].duplicate(true)
 unit.hp=unit.max_hp;unit.entry="road";unit.entry_phase="advance";unit.running=true;unit.state="idle"
 actor.animate_unit(unit,1,.05,Vector3.ZERO)
 assert(actor.clip=="idle","Stopped runner must not retain the running pose")
 unit.entry="crawl";unit.state="walk"
 actor.animate_unit(unit,1.1,.05,Vector3(0,0,1))
 var posture:Transform3D=actor.body.transform
 unit.state="attack";unit.changed=1.2
 actor.animate_unit(unit,1.2,.05,Vector3.ZERO)
 assert(actor.clip=="attack","Crawl entry must not override attack state")
 assert(actor.body.transform==posture,"Crawling attack must not abruptly stand upright")
 await capture(stage,actor,"attack")
 unit.hp=0;unit.changed=1.3
 actor.animate_unit(unit,1.3,.05,Vector3.ZERO)
 assert(actor.clip=="death" and actor.body.transform==posture,"Death must preserve crawl orientation")
 actor.animate_unit(unit,1.8,.05,Vector3.ZERO)
 await capture(stage,actor,"death")
 unit.hp=unit.max_hp;unit.entry="road";unit.state="walk";unit.running=false
 actor.animate_unit(unit,2,.05,Vector3(0,0,1))
 assert(actor.clip=="walk" and actor.body.rotation.x==0 and actor.body.position.y==0)
 print("WORLD3D_ENEMY_ANIMATION_STATES_PASS stationary runner, crawling attack/death and road reuse")
 quit()
