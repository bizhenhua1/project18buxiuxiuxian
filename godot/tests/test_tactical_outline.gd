extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1280,800)
 var shell=load("res://scenes/tactical_presentation.tscn").instantiate();root.add_child(shell)
 while not shell.stage or not shell.stage.ready_stage:await process_frame
 await process_frame
 var s=shell.stage;s.set_process(false);s.tactical_ui.select(s.team_slots[0]);s._process(0)
 var outline=s.tactical_ui.selection_outline
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 var mask:Image=outline.viewport.get_texture().get_image()
 var filled:=0;var empty:=0
 for y in range(0,mask.get_height(),3):
  for x in range(0,mask.get_width(),3):
   if mask.get_pixel(x,y).a>.95:filled+=1
   else:empty+=1
 assert(filled>100 and empty>filled,"Mask must contain the selected silhouette with transparent background")
 assert((s.camera.cull_mask & outline.MASK_LAYER)==0)
 for actor in outline.groups:
  for entry in outline.groups[actor]:
   assert(entry.mesh.mesh==entry.source.mesh and entry.mesh.skin==entry.source.skin,"Selection must reuse geometry and skin")
 outline.sync([])
 assert(not outline.overlay.visible and outline.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED)
 print("TACTICAL_OUTLINE_PASS unified silhouette mask, shared skin, isolated render layer, disabled when unused")
 quit()
