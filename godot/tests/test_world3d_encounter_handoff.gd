extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 var shell=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(shell)
 while not shell.stage or not shell.stage.ready_stage:await process_frame
 var stage=shell.stage;stage.set_process(false)
 stage.encounters.sequence=[{"kind":"battle"},{"kind":"battle"}]
 stage.start_travel()
 for i in 300:
  stage._process(.05)
  if stage.phase=="event":break
 assert(stage.phase=="event" and stage.preview.visible)
 var actor=stage.preview;var position:Vector3=actor.position;var pool_size:int=stage.enemy_pool.size()
 stage.start_battle()
 assert(stage.preview!=actor and not stage.preview.visible)
 var slots:Array=stage.pool_ids.values().filter(func(slot):return slot.actor==actor)
 assert(slots.size()==1 and actor.visible and actor.position==position)
 var enemy:Dictionary=stage.sim.enemies.filter(func(e):return e.id==slots[0].id)[0]
 assert(stage.world_point(enemy.pos).distance_to(position)<.0001)
 assert(stage.sim.enemies.size()==50 and stage.enemy_pool.size()==pool_size)
 for i in 200:
  stage._process(.05)
  if stage.phase=="battle":break
 assert(actor.visible and actor.position==position,"Entry must not replace or relocate preview")
 stage._process(.05)
 assert(actor.visible and actor.position.distance_to(position)<.15,"First simulation frame must move continuously")
 stage.reset_battle()
 assert(not actor.visible and stage.pool_ids.is_empty())
 var spare=stage.preview
 spare.show();spare.position=stage.camera.to_global(Vector3(0,0,-1))
 spare.portrait_presenter.configure_enemy(stage.camera,stage.bridge.focal())
 assert(spare.portrait_presenter.near_parameters.portrait_near_params.x>0)
 stage.encounters.win();stage.start_travel();stage._process(.05)
 var anchor:Vector3=stage.camera.to_local(spare.global_position)
 var expected:Dictionary=load("res://scripts/world3d/enemy_portrait_projection.gd").parameters(anchor,spare.scale.y,2.6*spare.scale.y*stage.bridge.focal()/maxf(.05,-anchor.z))
 assert(spare.portrait_presenter.near_parameters==expected,"Reused preview must discard prior near-camera projection")
 for i in 300:
  stage._process(.05)
  if stage.phase=="event":break
 assert(stage.preview==spare and spare.visible and not spare.dead)
 stage.start_battle()
 assert(stage.pool_ids.values().any(func(slot):return slot.actor==spare))
 assert(stage.enemy_pool.size()==pool_size and stage.sim.enemies.size()==50)
 print("WORLD3D_ENCOUNTER_HANDOFF_PASS same actor/world position, unchanged pool/count, continuous first step and reset")
 quit()
