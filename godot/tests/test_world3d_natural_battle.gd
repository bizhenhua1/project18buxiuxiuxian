extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 var shell=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(shell)
 while not shell.stage or not shell.stage.ready_stage:await process_frame
 var stage=shell.stage;stage.set_process(false);stage._process(0)
 stage.start_battle()
 var saw_battle:=false;var corpse_roots:Dictionary={}
 for tick in 3600:
  stage._process(.05)
  saw_battle=saw_battle or stage.phase=="battle"
  for unit in stage.sim.enemies:
   if unit.hp>0 or not stage.pool_ids.has(unit.id):continue
   var actor=stage.pool_ids[unit.id].actor
   if not corpse_roots.has(unit.id):corpse_roots[unit.id]=actor.position
   assert(actor.position.distance_to(corpse_roots[unit.id])<.001,"A natural death must not slide afterward")
   assert(actor.visible,"Corpse must remain during combat")
  if stage.phase in ["victory","defeat"]:break
 assert(saw_battle and stage.phase in ["victory","defeat"],"Natural battle must reach a result")
 assert(stage.sim.projectiles.active.is_empty() and stage.sim.windups.is_empty())
 var result:String=stage.phase;var battle_time:float=stage.sim.clock
 var killed:int=stage.sim.killed;var leaked:int=stage.sim.leaked
 if result=="defeat":
  assert(not stage.defeat_clear.entries.is_empty())
  for tick in 100:
   stage._process(.05)
   if tick==8:assert(stage.defeat_clear.multimesh.visible_instance_count>0,"Failure must actually emit mist")
   for entry in stage.defeat_clear.entries:assert(entry.node.position==entry.origin,"Removal must stay at the captured world position")
   if tick==8 and "--capture" in OS.get_cmdline_user_args():
    stage.set_inspection_expanded(false)
    for frame in 3:await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://../tempassets/work/world3d-defeat-mist.png")
    print("DEFEAT_MIST_INSTANCES ",stage.defeat_clear.multimesh.visible_instance_count," bounds=",stage.defeat_clear.get_aabb())
  for entry in stage.defeat_clear.entries:
   assert(entry.node.opacity==0 if entry.actor else entry.node.modulate.a==0)
  assert(stage.defeat_clear.multimesh.visible_instance_count==0)
 var camera:Transform3D=stage.camera.transform;var lens:Projection=stage.camera.get_camera_projection()
 var positions:Array=[]
 for actor in stage.team:positions.append(actor.position)
 stage.reset_battle();stage._process(0)
 assert(stage.phase=="prepare" and stage.sim.life==20)
 assert(stage.defeat_clear.entries.is_empty())
 assert(stage.camera.transform==camera and stage.camera.get_camera_projection()==lens)
 for i in stage.team.size():
  assert(not stage.team[i].dead and stage.team[i].position==positions[i])
  var unit:Dictionary=stage.sim.allies[stage.team_slots[i]]
  assert(unit.hp==unit.max_hp)
 # A separate synthetic boundary checks interruption, not the natural result.
 stage.team[0].trigger("death")
 stage.defeat_clear.begin(stage)
 stage.phase="defeat"
 var entry:Dictionary=stage.defeat_clear.entries.filter(func(e):return e.node==stage.team[0])[0]
 assert(entry.delay>0)
 stage.defeat_clear.advance(minf(.05,entry.delay*.5),stage.camera)
 assert(stage.team[0].opacity==entry.alpha,"Finish a newly started death before fading")
 stage.reset_battle()
 assert(stage.defeat_clear.entries.is_empty() and stage.defeat_clear.multimesh.visible_instance_count==0)
 assert(stage.team[0].opacity==1 and not stage.team[0].dead)
 print("WORLD3D_NATURAL_BATTLE_PASS result=",result," seconds=",battle_time," killed=",killed," leaked=",leaked," observed_corpses=",corpse_roots.size()," fixed-camera reset")
 quit()
