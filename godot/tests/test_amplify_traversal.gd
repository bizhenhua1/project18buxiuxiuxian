extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1500,900)
 var app=load("res://scenes/character_library.tscn").instantiate();root.add_child(app)
 app.set_process(false)
 for i in 5:await process_frame
 app._process(0)
 var imported:Array=app.clips.filter(func(c):return c.get("pack","")=="3")
 assert(imported.size()==32)
 for clip in imported:
  assert(clip.category=="攀爬与上下通行")
  app.select_clip(clip)
  for t in [0.0,.5,1.0]:
   app.retarget.apply((clip.frames-1)/clip.fps*t)
   for i in app.rig.get_bone_count():assert(app.rig.get_bone_pose(i).is_finite())
 for key in ["Ladder_Ascend_Loop","Obstacle_Climb_Loop","Obstacle_Climb_onTop"]:
  var clip=imported.filter(func(c):return c.name==key)[0]
  app.select_clip(clip);app.retarget.apply((clip.frames-1)/clip.fps*.5)
  for i in 4:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://../tempassets/work/amplify-traversal/"+key+".png")
 print("AMPLIFY_TRAVERSAL_PASS clips=32 finite retarget poses")
 quit()
