extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 var app=load("res://scenes/endless_forest.tscn").instantiate();root.add_child(app)
 await process_frame
 var data:Array=[]
 var start=Time.get_ticks_msec()
 while Time.get_ticks_msec()-start<45000 and is_instance_valid(app):
  await process_frame
  await RenderingServer.frame_post_draw
  if not is_instance_valid(app):break
  var r=app.arena.scenery.renderer
  data.append([(Time.get_ticks_msec()-start)*.001,app.phase,app.distance,app.camera.x,app.camera.y,app.heading,r.horizon_y(),r.camera_height(),r.focal(),r.forest_batch.batch.instance_count])
 FileAccess.open("res://../tempassets/work/camera-realtime.json",FileAccess.WRITE).store_string(JSON.stringify(data))
 print("REALTIME_DONE ",data.size());quit()
