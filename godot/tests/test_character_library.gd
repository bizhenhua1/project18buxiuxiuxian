extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.size=Vector2i(1600,960)
 var app=load("res://scenes/character_library.tscn").instantiate();root.add_child(app)
 await process_frame
 for i in range(7):
  app.select_model(i);app.playing=false;app.elapsed=.4
  for f in range(4):await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://../art/3d/seer/library-%d.png"%i)
  assert(app.rig!=null)
 for name in ["EM_Walk","EM_Attack01","EM_Run"]:
  var clip:Dictionary=app.clips.filter(func(c):return c.name==name)[0]
  for i in range(7):
   app.select_model(i);app.select_clip(clip);app.playing=false
   app.elapsed=(clip.frames-1)/clip.fps*.5
   for f in range(7):await process_frame
   assert(not app.retarget.data.is_empty())
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://../art/3d/seer/library-%s-%d.png"%[name,i])
 app.search.text="EM_Walk";app.refresh_list();assert(app.motion_buttons.size()>0)
 app.categories.select(0);app.pack_tabs.current_tab=app.pack_ids.find("9");app.search.text="";app.refresh_list();assert(app.motion_buttons.size()==9)
 print("CHARACTER_LIBRARY_PASS clips=",app.clips.size());quit()
