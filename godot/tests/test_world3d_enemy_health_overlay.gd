extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 var shell=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(shell)
 while not shell.stage or not shell.stage.ready_stage:await process_frame
 var stage=shell.stage;stage.set_process(false);stage.start_battle();stage.phase="battle"
 var enemy:Dictionary=stage.sim.enemies[0]
 enemy.activate_at=0;enemy.born=-1;enemy.pos=Vector3(0,0,-5);enemy.previous_pos=enemy.pos
 stage._process(0)
 var overlay=stage.enemy_health_overlay
 assert(overlay.bars.is_empty(),"Unhurt creatures must not have health bars")
 stage.sim.hurt(enemy,0);overlay.sync(stage);assert(overlay.bars.is_empty())
 stage.sim.hurt(enemy,enemy.max_hp*.25);overlay.sync(stage)
 assert(overlay.bars.size()==1 and overlay.bars[0].id==enemy.id)
 assert(is_equal_approx(overlay.bars[0].fraction,.75))
 if "--capture" in OS.get_cmdline_user_args():
  stage.set_inspection_expanded(false)
  for i in 3:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://../tempassets/work/world3d-injured-health.png")
 stage.phase="travel";overlay.sync(stage);assert(overlay.bars.is_empty())
 stage.phase="battle";stage.sim.hurt(enemy,enemy.max_hp);overlay.sync(stage);assert(overlay.bars.is_empty())
 var config=load("res://scripts/battle/health_transformation.gd")
 var saved:Dictionary=config.cached;var saved_poll:int=config.next_poll
 config.cached={"display":"ui"};config.next_poll=Time.get_ticks_msec()+60000
 var ally:Dictionary=stage.sim.allies[stage.team_slots[0]]
 ally.hp=ally.max_hp*.5
 stage.sync_party_health(0);overlay.sync(stage)
 assert(overlay.bars.size()==1 and overlay.bars[0].ally and overlay.bars[0].fraction==.5,"UI mode must show injured party model")
 if "--capture" in OS.get_cmdline_user_args():
  for i in 3:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://../tempassets/work/world3d-party-health.png")
 config.cached={"display":"transform","mode":0}
 stage.sync_party_health(0);overlay.sync(stage)
 assert(overlay.bars.is_empty(),"Transformation replaces the party model bar")
 config.cached={"display":"transform","mode":99}
 stage.sync_party_health(0);overlay.sync(stage)
 assert(overlay.bars.size()==1,"Unsupported transformation must retain health information")
 ally.hp=ally.max_hp;overlay.sync(stage);assert(overlay.bars.is_empty())
 ally.hp=0;overlay.sync(stage);assert(overlay.bars.is_empty())
 config.cached={"display":"transform","mode":0};stage.sync_party_health(0)
 var prop=stage.props[0];var prop_unit:Dictionary=stage.sim.allies[prop.slot]
 stage.sim.hurt(prop_unit,prop_unit.max_hp*.25);overlay.sync(stage)
 assert(overlay.bars.size()==1 and overlay.bars[0].get("prop",false))
 assert(overlay.bars[0].fraction==.75,"Prop health remains visible when models use transformation")
 var projected:Vector2=stage.camera.unproject_position(prop.node.global_position)+Vector2(0,10)
 assert(overlay.bars[0].position.distance_to(projected)<.001)
 if "--capture" in OS.get_cmdline_user_args():
  for frame in 3:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://../tempassets/work/world3d-prop-health.png")
 stage.phase="travel";overlay.sync(stage);assert(overlay.bars.is_empty())
 stage.phase="battle";prop_unit.hp=prop_unit.max_hp;overlay.sync(stage);assert(overlay.bars.is_empty())
 config.cached=saved;config.next_poll=saved_poll
 print("WORLD3D_HEALTH_OVERLAY_PASS enemy injury, party UI, transform suppression, fallback, full health, death")
 quit()
