extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 var shell=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(shell)
 while not shell.stage or not shell.stage.ready_stage:await process_frame
 var stage=shell.stage;stage.set_process(false);stage.start_travel()
 var wins:=0;var forks:=0;var last_stop:=-1.0;var battles:=0
 for tick in 16000:
  stage._process(.05)
  if stage.phase=="defeat":
   push_error("Natural route ended in defeat before the branch battle; this is not a verified continuous victory route")
   quit(1);return
  if stage.phase=="event" and not stage.encounters.resolved:
   assert(stage.distance>last_stop,"The next event must advance along the route")
   last_stop=stage.distance
   assert(stage.encounters.current().kind=="battle","Right-branch fixture should contain combat encounters")
   assert(stage.preview.visible,"The already deployed monster must be present at arrival")
   var preview=stage.preview;var position:Vector3=preview.position
   stage.encounter_panel.choices.get_child(0).pressed.emit();battles+=1
   assert(stage.phase=="entering" and stage.pool_ids.values().any(func(slot):return slot.actor==preview))
   assert(preview.position==position,"Encounter handoff must not respawn the visible monster")
  elif stage.phase=="victory":
   wins+=1
   assert(stage.encounters.resolved and stage.sim.spawned==24)
   assert(stage.encounters.stones==wins*2,"Branch selection must retain accumulated rewards")
   print("NATURAL_ROUTE_WIN count=",wins," station=",stage.distance," forks=",forks)
   if forks>0:
    assert(wins==battles)
    print("WORLD3D_NATURAL_ROUTE_PASS natural battles, monotonic events, fork choice, predeployment handoff, rewards retained")
    quit();return
   stage.encounter_panel.choices.get_child(0).pressed.emit()
   assert(stage.phase=="travel")
  elif stage.phase=="fork":
   forks+=1
   assert(not stage.preview.visible,"The junction itself must not deploy a monster")
   var junction:float=stage.distance
   stage.fork_buttons[1].pressed.emit()
   assert(stage.phase=="travel" and stage.branch==1)
   assert(stage.next_event>junction and stage.preview.visible,"Chosen branch must predeploy its next encounter immediately")
   assert(stage.preview_station>stage.preview_stop_station and stage.preview_stop_station>stage.next_event)
 push_error("Natural route did not finish within the bounded scenario")
 quit(1)
