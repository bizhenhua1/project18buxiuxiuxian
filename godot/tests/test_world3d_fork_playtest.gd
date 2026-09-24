extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 for count in [2,3]:
  set_meta("world3d_fork_test",count)
  var shell=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(shell)
  assert(not shell.container.visible,"Uninitialized camera must be hidden")
  while not shell.stage.ready_stage:
   assert(not shell.container.visible)
   await process_frame
  var app=shell.stage;app.set_process(false)
  var expected_count:int=2 if app.theme_key=="crystal" else count
  for frame in 3:await process_frame
  assert(shell.container.visible and app.camera.position!=Vector3.ZERO)
  assert(app.route_segment.exits==expected_count and app.phase=="travel")
  for tick in 90:
   app._process(.05)
   if app.phase=="fork":break
  assert(app.phase=="fork" and not app.preview.visible)
  assert(app.encounter_panel.choices.get_child_count()==expected_count)
  if "--capture" in OS.get_cmdline_user_args():
   for frame in 3:await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://../tempassets/work/world3d-fork-playtest-%d.png"%count)
  app.fork_buttons[1 if count==3 else -1].pressed.emit()
  assert(app.phase=="travel")
  app._process(.05)
  if app.theme_key=="crystal":
   assert(app.scenery.selected_route_branch==app.branch)
   assert(is_zero_approx(app.scenery.hidden_branch_fraction),"The native fork must not pop its other exits on selection")
  for tick in 29:app._process(.05)
  if app.theme_key=="crystal":
   assert(is_zero_approx(app.scenery.hidden_branch_fraction),"Both cave mouths must remain visible during the transfer")
  if "--capture" in OS.get_cmdline_user_args():
   app.set_inspection_expanded(false)
   for frame in 3:await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://../tempassets/work/world3d-fork-turn-%d.png"%count)
  for tick in 160:
   app._process(.05)
   if app.phase=="event":break
  assert(app.phase=="event" and app.sim.status!="battle" and not app.preview.visible)
  assert(app.encounter_panel.heading.text=="岔路测试 · 转弯完成")
  assert(app.encounter_panel.choices.get_child_count()==1)
  shell.queue_free();await process_frame
 remove_meta("world3d_fork_test")
 print("WORLD3D_FORK_PLAYTEST_PASS hidden preload, initialized reveal, two/three choices, traversal without combat, repeat prompt")
 quit()
