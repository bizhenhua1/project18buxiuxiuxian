extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 var app=load("res://scenes/endless_forest.tscn").instantiate();root.add_child(app)
 await process_frame
 app.set_process(false)
 var data:Array=[]
 for frame in range(150):
  app.speed=4
  app._process(1.0/60)
  await process_frame
  await RenderingServer.frame_post_draw
  var r=app.arena.scenery.renderer
  data.append([frame,app.phase,app.distance,app.camera.x,app.camera.y,app.heading,r.horizon_y(),r.camera_height(),r.focal(),app.arena.seer.travel_speed(),r.forest_batch.material.get_shader_parameter("camera_world").y,r.forest_batch.material.get_shader_parameter("horizon")])
  if app.phase=="defeat" or app.route_complete:break
 FileAccess.open("res://../tempassets/work/camera-render-trace.json",FileAccess.WRITE).store_string(JSON.stringify(data))
 print("TRACE_DONE ",data.size());quit()
