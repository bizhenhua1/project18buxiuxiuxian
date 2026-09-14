extends SceneTree
func _initialize():call_deferred("run")
func capture(stage,label:String):
 if not "--capture" in OS.get_cmdline_user_args():return
 stage.set_inspection_expanded(false)
 for frame in 3:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/world3d-natural-"+label+".png")
func run():
 root.size=Vector2i(1440,900)
 var shell=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(shell)
 while not shell.stage or not shell.stage.ready_stage:await process_frame
 var stage=shell.stage;stage.set_process(false);stage.start_travel()
 for tick in 200:
  stage._process(.05)
  if stage.phase=="event":break
 assert(stage.phase=="event")
 var preview=stage.preview;var anchor:Vector3=preview.position
 var button=stage.encounter_panel.choices.get_child(0)
 assert(button.text=="准备迎战");button.pressed.emit()
 assert(not stage.sim.stress and stage.sim.spawned==1)
 assert(stage.pool_ids.values().any(func(slot):return slot.actor==preview))
 assert(preview.position==anchor)
 var peak_spawned:=1;var previous_spawned:=1
 for tick in 3600:
  stage._process(.05)
  assert(stage.sim.spawned-previous_spawned<=1,"Normal wave must arrive over time")
  previous_spawned=stage.sim.spawned;peak_spawned=maxi(peak_spawned,previous_spawned)
  for unit in stage.sim.enemies:
   if stage.sim.clock>=unit.activate_at and not unit.resolved:assert(stage.pool_ids.has(unit.id),"Every active enemy must have a model")
  if stage.phase in ["victory","defeat"]:break
 assert(stage.phase in ["victory","defeat"] and peak_spawned>1 and peak_spawned<=24)
 print("NORMAL_ENCOUNTER_RESULT ",stage.phase," seconds=",stage.sim.clock," spawned=",stage.sim.spawned," killed=",stage.sim.killed," leaked=",stage.sim.leaked)
 if stage.phase=="victory":
  assert(stage.encounters.resolved)
  for unit in stage.sim.allies:assert(unit.hp==unit.max_hp)
  var anchors:Array=[]
  for actor in stage.team:anchors.append(actor.position)
  var prop_anchors:Array=[]
  for item in stage.props:prop_anchors.append(item.node.position)
  for tick in 8:
   stage._process(.05)
   for i in range(1,stage.team.size()):assert(stage.team[i].position.is_equal_approx(anchors[i]),"Victorious companions must fade at their last position")
   for i in stage.props.size():assert(stage.props[i].node.position.is_equal_approx(prop_anchors[i]),"Victorious props must stop bobbing and fade in place")
  assert(stage.team[0].opacity==1,"Victory keeps the protagonist visible")
  for i in range(1,stage.team.size()):assert(stage.team[i].opacity==0)
  for item in stage.props:assert(item.node.modulate.a==0)
  await capture(stage,"victory")
  var previous_event:float=stage.next_event
  stage.start_travel()
  assert(stage.phase=="travel" and stage.next_event>previous_event)
  for tick in 6:stage._process(.05)
  await capture(stage,"departure")
  for tick in 200:
   stage._process(.05)
   if stage.phase=="event":break
  assert(stage.phase=="event","Natural victory must continue to the next encounter")
 stage.reset_battle();stage.action_buttons["50 来敌"].pressed.emit()
 assert(stage.sim.stress and stage.sim.spawned==50 and int(stage.sim.config.total)==90,"Pressure entry must restore its original configuration")
 print("WORLD3D_NORMAL_ENCOUNTER_PASS UI wave selection, same preview, gradual arrivals, model coverage, natural result, pressure isolation")
 quit()
