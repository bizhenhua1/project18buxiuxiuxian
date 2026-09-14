extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 var shell=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(shell)
 while not shell.stage or not shell.stage.ready_stage:await process_frame
 var stage=shell.stage;stage.set_process(false);stage._process(0)
 var panel=stage.comparison_panel;var time:float=stage.clock
 panel.open();stage._process(.05)
 assert(panel.visible and stage.playback_paused and stage.clock==time)
 for index in 2:
  panel.picker.select(index);panel.picker.item_selected.emit(index)
  for picture in panel.pictures:assert(picture.texture!=null,"Local comparison fixture must be present")
 for mode in [1,2,0]:
  panel.view_picker.select(mode);panel.view_picker.item_selected.emit(mode)
  for side in 2:assert(panel.columns[side].visible==(mode==0 or mode==side+1))
  stage._process(.05);assert(stage.clock==time,"Comparison layout must not resume the simulation")
 for frame in 3:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/world3d-comparison-panel.png")
 panel.dismiss();assert(not panel.visible and not stage.playback_paused)
 stage.set_playback_paused(true);panel.open();panel.dismiss()
 assert(stage.playback_paused,"Closing comparison must preserve a preexisting pause")
 print("WORLD3D_COMPARISON_PANEL_PASS both pairs, pause and restore, no simulation advance")
 quit()
