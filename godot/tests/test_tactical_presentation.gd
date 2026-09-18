extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 var shell=load("res://scenes/tactical_presentation.tscn").instantiate();root.add_child(shell)
 while not shell.stage or not shell.stage.ready_stage:await process_frame
 await process_frame
 var s=shell.stage;s.set_process(false);s.begin_tactical()
 for i in 160:s._process(.05)
 var before:float=s.clock;s.tactical_ui.select(s.team_slots[0]);s.tactical_ui.preview=true
 for i in 10:s._process(.05)
 assert(absf(s.clock-before-.1)<.001,"Selection should slow only the battle clock to 20 percent")
 s.tactical_ui.close_menu();before=s.clock
 for i in 10:s._process(.05)
 assert(absf(s.clock-before-.5)<.001)
 s.tactical_ui.select(s.team_slots[0]);s.tactical_ui.preview=true;s._process(0)
 # Exercise the viewport input route, not only direct menu method calls.
 s.tactical_ui.close_menu()
 var actor=s.team[0];var foot:Vector2=s.camera.unproject_position(actor.position)
 var top:Vector2=s.camera.unproject_position(actor.position+Vector3.UP*1.8*actor.scale.y)
 var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=(foot+top)*.5
 shell.viewport.push_input(click,true)
 await process_frame
 assert(s.tactical_ui.selected==s.team_slots[0],"Clicking the ally in the viewport must open its menu")
 s.tactical_ui.preview=true;s._process(0)
 if not DisplayServer.get_name()=="headless":
  for i in 3:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://../tempassets/work/tactical-preview.png")
 print("TACTICAL_PRESENTATION_PASS shared scene/camera, menu slowdown and recovery")
 quit()
