extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 var shell=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(shell)
 var app=shell.stage
 while not app.ready_stage:await process_frame
 app.set_process(false);app.start_battle()
 var frames:=0
 while frames<3000 and app.phase not in ["victory","defeat"]:
  app._process(.05);frames+=1
 assert(app.phase in ["victory","defeat"],"Unmodified combat must eventually produce a real result")
 print("REAL_BATTLE_RESULT phase=",app.phase," clock=",app.sim.clock," killed=",app.sim.killed," leaked=",app.sim.leaked," dead_allies=",app.sim.allies.filter(func(unit):return unit.hp<=0).size())
 var camera_before:Transform3D=app.camera.global_transform
 app.reset_battle();app._process(0)
 assert(app.phase=="prepare" and app.sim.allies.all(func(unit):return unit.hp==unit.max_hp))
 assert(app.team.all(func(actor):return not actor.dead and actor.visible))
 assert(app.camera.global_transform.is_equal_approx(camera_before),"Result reset moves the established battle camera")
 print("WORLD3D_REAL_RESULT_RESET_PASS")
 app.start_battle();frames=0;var wounded:=false;var dead_models:Dictionary={};var corpse_checks:=0;var corpse_captured:=false
 while frames<3000 and app.phase not in ["victory","defeat"]:
  if app.phase=="battle":
   wounded=wounded or app.sim.allies.any(func(unit):return unit.hp<unit.max_hp)
   for actor in app.team:
    if not actor.dead:continue
    if not dead_models.has(actor):dead_models[actor]=actor.position
    assert(actor.visible and actor.position==dead_models[actor],"Dead ally must remain at its death position")
    corpse_checks+=1
   if not corpse_captured and corpse_checks>50 and DisplayServer.get_name()!="headless":
    await process_frame;await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://../tempassets/work/world3d-real-corpse.png");corpse_captured=true
   # Exercise real spatial damage and enemy resolution; never write status/HP.
   # This is an assisted mechanics fixture, not a balance test of default AI.
   if not dead_models.is_empty() and frames%4==0:
    app.sim.areas.sync(app.sim.enemies,app.sim.skill_world,app.sim.clock)
    for enemy in app.sim.enemies:
     if enemy.hp>0 and app.sim.clock>=enemy.activate_at:
      app.sim.areas.burst(app.world_point(enemy.pos),1.0,1.0,45,Callable(app.sim,"hurt"))
  app._process(.05);frames+=1
 assert(app.phase=="victory" and app.sim.killed+app.sim.leaked==50 and app.sim.killed>0,"Real damage should resolve all 50 enemies and win")
 assert(wounded,"Victory recovery fixture must first suffer actual damage")
 assert(corpse_checks>1,"Exercise a model death and persistent corpse before victory")
 assert(app.sim.allies.all(func(unit):return unit.hp==unit.max_hp and unit.state=="idle"))
 assert(app.team.all(func(actor):return not actor.dead))
 assert(app.encounters.resolved)
 if DisplayServer.get_name()!="headless":
  app._process(.05);await process_frame;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://../tempassets/work/world3d-real-victory.png")
 app.start_travel();assert(app.phase=="travel")
 print("WORLD3D_REAL_VICTORY_PASS real damage, wounded party recovery, resolved event and departure")
 quit()
