extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 var shell=load("res://scenes/tactical_presentation.tscn").instantiate();root.add_child(shell)
 while not shell.stage or not shell.stage.ready_stage:await process_frame
 await process_frame
 var s=shell.stage;s.set_process(false);s.tactical_ui.select(s.team_slots[0]);s._process(0)
 var outline=s.tactical_ui.selection_outline;outline.set_process(false);outline.material.set_shader_parameter("effect_time",1.5)
 var hashes:Array=[]
 for style in 4:
  outline.set_style(style,false)
  for i in 3:await process_frame
  await RenderingServer.frame_post_draw
  var shot:Image=root.get_texture().get_image();shot.save_png("res://../tempassets/work/tactical-outline-%d.png"%style);hashes.append(hash(shot.get_data()))
 assert(hashes[0]!=hashes[1] and hashes[1]!=hashes[2] and hashes[2]!=hashes[3])
 var mask:Image=outline.viewport.get_texture().get_image();var coverage:=0
 for y in mask.get_height():
  for x in mask.get_width():
   var a:float=mask.get_pixel(x,y).a
   if a>.02 and a<.98:coverage+=1
 assert(coverage>20,"MSAA mask must include fractional edge coverage")
 assert(outline.viewport.size==Vector2i(s.get_viewport().get_visible_rect().size))
 print("OUTLINE_STYLES_PASS four distinct renders, full resolution, fractional coverage pixels=",coverage)
 quit()

