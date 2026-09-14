extends SceneTree
func _initialize():call_deferred("run")
func run():
 var shell=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(shell)
 while not shell.stage or not shell.stage.ready_stage:await process_frame
 var stage=shell.stage;stage.set_process(false)
 var path:="user://world3d-formation-test.json"
 stage.live_camera.active_path=path
 var old:Dictionary=stage.composition.duplicate(true)
 var changed:Dictionary=old.duplicate(true)
 for slot in changed.battle_slots:
  for kind in ["character","prop"]:
   slot[kind].x+=2;slot[kind].height*=.9;slot[kind].clearance+=.2
 var positions:Array=stage.team.map(func(a):return a.position)
 var scales:Array=stage.team.map(func(a):return a.scale)
 FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(changed))
 stage._process(.05)
 assert(stage.composition.battle_slots==old.battle_slots)
 stage.reset_battle()
 assert(stage.composition.battle_slots==old.battle_slots,"Restart must not adopt a new formation")
 stage.phase="event";stage.encounters.sequence=[{"kind":"battle"}];stage.encounters.cursor=0;stage.encounters.resolved=false
 stage.start_battle()
 assert(stage.composition.battle_slots==stage.live_camera.data.battle_slots)
 for i in stage.team.size():
  assert(stage.team[i].position==positions[i],"Applying targets must not teleport actors")
  assert(stage.team[i].scale==scales[i],"Applying targets must not snap scale")
 for tick in 120:
  var before:Array=stage.team.map(func(a):return a.position)
  stage._process(.05)
  if stage.phase=="battle":
   # Finish only the visual scale blend without simulating an attack.
   stage.phase="prepare"
  for i in stage.team.size():assert(stage.team[i].position.distance_to(before[i])<=TravelPace.RUN/20*.05+.0001)
 for i in stage.team.size():
  assert(stage.team[i].position.distance_to(stage.slot_position(i))<.03)
  var desired:float=stage.CHARACTER_FRAME.scale_for_slot(stage.profiles[stage.team_slots[i]].height)
  assert(absf(stage.team[i].scale.x-desired)<.0001)
 for item in stage.props:
  assert(is_equal_approx(item.node.pixel_size,stage.profiles[item.slot].height/20/item.node.texture.get_height()))
 DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 print("WORLD3D_LIVE_FORMATION_PASS deferred new encounter, no teleport, bounded entry, model and prop sizing")
 quit()
