extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1600,960)
 var app=load("res://scenes/character_library.tscn").instantiate();root.add_child(app)
 await process_frame
 assert(app.pack_ids.size()==8)
 for clip in app.clips:assert(not str(clip.file).contains("amplify"))
 for index in range(1,8):
  app.pack_tabs.current_tab=index;app.categories.select(0);app.refresh_list()
  var matches:Array=app.clips.filter(func(c):return str(c.pack)==app.pack_ids[index])
  assert(app.motion_buttons.size()==matches.size() and not matches.is_empty())
  app.select_clip(matches[0])
  for frame in range(5):await process_frame
  assert(not app.retarget.data.is_empty())
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://../art/3d/seer/pack-%s.png"%app.pack_ids[index])
  app.search.text="__not_found__";app.refresh_list();assert(app.motion_buttons.is_empty())
  app.search.text=""
 app.pack_tabs.current_tab=0
 for index in range(app.categories.item_count):
  app.categories.select(index);app.refresh_list()
  assert(app.motion_buttons.size()<=app.clips.size())
 print("CURRENT_PACKS_PASS count=",app.clips.size());quit()
