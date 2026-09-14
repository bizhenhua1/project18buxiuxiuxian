extends SceneTree
func _initialize():call_deferred("run")
func snapshot()->Image:
 for frame in 3:await process_frame
 await RenderingServer.frame_post_draw
 return root.get_texture().get_image()
func run():
 root.size=Vector2i(960,600)
 var shell=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(shell)
 while not shell.stage.ready_stage:await process_frame
 var stage=shell.stage;stage.set_process(false);stage._process(0);stage.set_inspection_expanded(false)
 var selected:Array=[]
 for texture in stage.scenery.by_texture:
  if stage.scenery.is_low_foliage(texture):selected.append(stage.scenery.by_texture[texture])
 assert(selected.size()>1)
 for i in selected.size():selected[i].render_priority=-90+i
 var a:Image=await snapshot()
 for i in selected.size():selected[i].render_priority=-90+selected.size()-1-i
 var b:Image=await snapshot()
 var changed:=0
 for y in a.get_height():
  for x in a.get_width():
   var ca:=a.get_pixel(x,y);var cb:=b.get_pixel(x,y)
   if absf(ca.r-cb.r)+absf(ca.g-cb.g)+absf(ca.b-cb.b)>.04:changed+=1
 print("FOLIAGE_SORT_CHANGED_PIXELS ",changed)
 a.save_png("res://../tempassets/work/foliage-sort-a.png");b.save_png("res://../tempassets/work/foliage-sort-b.png")
 if "--require-stable" in OS.get_cmdline_user_args():assert(changed==0,"Grass occlusion must not depend on batch submission order")
 quit()
