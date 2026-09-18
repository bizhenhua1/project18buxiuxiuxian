extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 var scene_key:String=OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "snow_house"
 var output_prefix:String="snow-house" if scene_key=="snow_house" else scene_key
 var path:="user://endless-forest-test.json"
 var existed:=FileAccess.file_exists(path)
 var bytes:=FileAccess.get_file_as_bytes(path) if existed else PackedByteArray()
 set_meta("tour_biome",scene_key);set_meta("tour_event_placement","after");set_meta("tour_exits",2)
 var app=load("res://scenes/endless_forest.tscn").instantiate();root.add_child(app);app.set_process(false)
 var props:Array=app.world.sprites.filter(func(s):return s.texture.resource_path.contains("/furnishings/"))
 assert(props.size()>0)
 var variants:Dictionary={}
 for sprite in props:
  variants[sprite.texture.resource_path]=true
  var clearance:float=ForestRoute.road_distance(sprite.position,false)
  assert(clearance>=76+sprite.w*.5)
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/fairytales/"+scene_key+"/furnishings.json"))
 assert(variants.size()==manifest.assets.size(),"Medium furniture variants were not placed")
 for i in 75:
  app._process(1.0/60);await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/"+output_prefix+"-furnishing-v2.png")
 for i in 60:
  app._process(1.0/60);await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/"+output_prefix+"-furnishing-v2-forward.png")
 for i in 900:
  app._process(1.0/60);await process_frame
  if app.phase=="choose":break
 assert(app.phase=="choose")
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/"+output_prefix+"-branch-junction.png")
 app.choose(-1)
 for i in 120:
  app._process(1.0/60);await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/"+output_prefix+"-branch-left.png")
 print("FURNISHING ",scene_key," placed=",props.size()," road clearance passed")
 app.free();root.get_node("Journey").state=null
 if existed:
  var file:=FileAccess.open(path,FileAccess.WRITE);file.store_buffer(bytes);file.close()
 else:DirAccess.remove_absolute(path)
 quit()
